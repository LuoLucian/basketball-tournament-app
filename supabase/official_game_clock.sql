-- ============================================================
-- 正式赛计时器与节切换支持
-- 解决：quarter_clock 不倒计时、节无法切换、中途打开设备无法推算剩余时间
-- 依赖：add_pause_tracking.sql（paused_at / total_paused_ms / 5参数 update_game_status）
-- ============================================================

-- 1. games 表新增 clock_updated_at：quarter_clock 最后一次写库的时刻
--    设备用它推算"基准值之后又流逝了多少秒"（暂停期间不流逝）
ALTER TABLE games ADD COLUMN IF NOT EXISTS clock_updated_at TIMESTAMPTZ;

-- 2. 重建 update_game_status（新增可选参数 p_clock_remaining）
--    - 暂停时可顺带固化当前节剩余秒数（正式制）
--    - 恢复时正式制重置 clock_updated_at（从暂停点继续起算）
--    - 开始比赛（status -> active）时正式制从满值起算
DROP FUNCTION IF EXISTS public.update_game_status(UUID, VARCHAR(20), TIMESTAMPTZ, TIMESTAMPTZ, BOOLEAN);
DROP FUNCTION IF EXISTS public.update_game_status(UUID, VARCHAR(20), TIMESTAMPTZ, TIMESTAMPTZ, BOOLEAN, INTEGER);

CREATE OR REPLACE FUNCTION public.update_game_status(
  p_game_id        UUID,
  p_status         VARCHAR(20) DEFAULT NULL,
  p_started_at     TIMESTAMPTZ DEFAULT NULL,
  p_finished_at    TIMESTAMPTZ DEFAULT NULL,
  p_is_paused      BOOLEAN DEFAULT NULL,
  p_clock_remaining INTEGER DEFAULT NULL
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_game_type VARCHAR(20);
BEGIN
  SELECT game_type INTO v_game_type FROM games WHERE id = p_game_id;

  IF p_is_paused IS NOT NULL AND p_is_paused = TRUE THEN
    UPDATE games SET
      status           = COALESCE(p_status, status),
      started_at       = COALESCE(p_started_at, started_at),
      finished_at      = COALESCE(p_finished_at, finished_at),
      is_paused        = TRUE,
      paused_at        = NOW(),
      quarter_clock    = COALESCE(p_clock_remaining, quarter_clock),
      clock_updated_at = CASE WHEN p_clock_remaining IS NOT NULL THEN NOW() ELSE clock_updated_at END
    WHERE id = p_game_id;

  ELSIF p_is_paused IS NOT NULL AND p_is_paused = FALSE THEN
    UPDATE games SET
      status           = COALESCE(p_status, status),
      started_at       = COALESCE(p_started_at, started_at),
      finished_at      = COALESCE(p_finished_at, finished_at),
      is_paused        = FALSE,
      total_paused_ms  = COALESCE(total_paused_ms, 0)
                         + FLOOR(EXTRACT(EPOCH FROM (NOW() - COALESCE(paused_at, NOW()))) * 1000),
      paused_at        = NULL,
      clock_updated_at = CASE WHEN v_game_type = 'official' THEN NOW() ELSE clock_updated_at END
    WHERE id = p_game_id;

  ELSE
    UPDATE games SET
      status           = COALESCE(p_status, status),
      started_at       = COALESCE(p_started_at, started_at),
      finished_at      = COALESCE(p_finished_at, finished_at),
      is_paused        = COALESCE(p_is_paused, is_paused),
      clock_updated_at = CASE
                           WHEN v_game_type = 'official' AND p_status = 'active' AND status <> 'active'
                           THEN NOW() ELSE clock_updated_at END
    WHERE id = p_game_id;
  END IF;
END;
$$;

-- 3. 节切换 RPC（乐观锁：仅当当前节 = 调用方所见节号时生效，多设备防重复切节）
--    - 未到最后一节：进入下一节并节间休息（is_paused=TRUE，quarter_clock 重置为满值）
--    - 最后一节：全场结束（status=finished）
CREATE OR REPLACE FUNCTION public.end_quarter(
  p_game_id      UUID,
  p_from_quarter SMALLINT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  g RECORD;
  v_next SMALLINT;
BEGIN
  SELECT * INTO g FROM games WHERE id = p_game_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '比赛不存在'; END IF;
  IF g.game_type <> 'official' THEN RAISE EXCEPTION '仅正式制支持节切换'; END IF;

  IF COALESCE(g.current_quarter, 1) <> p_from_quarter THEN
    RETURN jsonb_build_object('quarter', g.current_quarter, 'finished', g.status = 'finished', 'stale', true);
  END IF;

  v_next := COALESCE(g.current_quarter, 1) + 1;
  IF v_next > COALESCE(g.quarters, 4) THEN
    UPDATE games SET
      status          = 'finished',
      finished_at     = NOW(),
      is_paused       = FALSE,
      quarter_clock   = 0,
      clock_updated_at = NOW(),
      total_paused_ms = COALESCE(total_paused_ms, 0)
                        + FLOOR(EXTRACT(EPOCH FROM (NOW() - COALESCE(paused_at, NOW()))) * 1000),
      paused_at       = NULL
    WHERE id = p_game_id;
    RETURN jsonb_build_object('quarter', COALESCE(g.quarters, 4), 'finished', true);
  ELSE
    UPDATE games SET
      current_quarter = v_next,
      quarter_clock   = COALESCE(g.quarter_seconds, 600),
      is_paused       = TRUE,
      paused_at       = NOW(),
      clock_updated_at = NOW()
    WHERE id = p_game_id;
    RETURN jsonb_build_object('quarter', v_next, 'finished', false);
  END IF;
END;
$$;

-- 4. 手动设置当前节剩余秒数（存量数据初始化 / 特殊校正）
CREATE OR REPLACE FUNCTION public.set_quarter_clock(
  p_game_id UUID,
  p_seconds SMALLINT
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE games SET quarter_clock = GREATEST(0, p_seconds), clock_updated_at = NOW()
  WHERE id = p_game_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_game_status(UUID, VARCHAR(20), TIMESTAMPTZ, TIMESTAMPTZ, BOOLEAN, INTEGER) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.end_quarter(UUID, SMALLINT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.set_quarter_clock(UUID, SMALLINT) TO anon, authenticated;

-- 5. 存量正式赛初始化时钟基准（从执行时刻起以当前 quarter_clock 值开始走秒）
UPDATE games
SET clock_updated_at = NOW()
WHERE game_type = 'official' AND status IN ('active', 'pending') AND clock_updated_at IS NULL;

-- 验证
SELECT proname, pg_get_function_identity_arguments(oid) AS args
FROM pg_proc
WHERE pronamespace = 'public'::regnamespace
  AND proname IN ('update_game_status', 'end_quarter', 'set_quarter_clock');
