-- ══════════════════════════════════════════════════════════
-- 修复 v2：
-- 1. game_lineup 增加 paused_ms_at_off 字段
--    （球员下场时刻的累计暂停毫秒数，与 paused_ms_at_on 对应）
-- 2. swap_player add 模式：先关闭旧 is_current 记录再插入新记录
--    ——解决 remove 失败入队/乱序时"重新上场无效"（add 误命中旧记录）
--    ——确保每次上场都有独立 lineup 记录，教练页可正确新建上场阶段
-- 3. remove 模式：下场时记录 paused_ms_at_off 快照
--    前端用 paused_ms_at_off - paused_ms_at_on 精确扣除暂停
-- 在 Supabase SQL Editor 中执行
-- ══════════════════════════════════════════════════════════

-- 第1步：game_lineup 表加字段
ALTER TABLE game_lineup
  ADD COLUMN IF NOT EXISTS paused_ms_at_off BIGINT DEFAULT NULL;

-- 第2步：删除现有 swap_player（清除所有重载）
DO $$ DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT proname, oid
    FROM pg_proc
    WHERE proname = 'swap_player' AND pronamespace = 'public'::regnamespace
  LOOP
    EXECUTE 'DROP FUNCTION IF EXISTS public.' || quote_ident(r.proname)
      || '(' || pg_get_function_identity_arguments(r.oid) || ')';
  END LOOP;
END $$;

-- 第3步：重建 swap_player
--   add 模式：先关闭该球员所有 is_current=true 的旧记录（off_at=现在，
--             paused_ms_at_off=当前累计暂停），再插入新的上场记录。
--            即使 remove 未先执行（网络失败入队、操作乱序），
--            重新上场也一定产生新的 lineup 记录，教练页能正确开始计时。
--   remove 模式：下场时记录 paused_ms_at_off（新增）
CREATE OR REPLACE FUNCTION public.swap_player(
  p_game_id   UUID,
  p_team_id   UUID,
  p_player_id UUID,
  p_slot_no   INTEGER DEFAULT NULL,
  p_mode      TEXT    DEFAULT 'add'
) RETURNS JSON AS $$
DECLARE
  v_lineup_id  UUID;
  v_paused_ms  BIGINT;
  v_quarter    SMALLINT;
  v_now        TIMESTAMPTZ := NOW();
BEGIN
  SET search_path = public;

  IF p_mode = 'add' THEN
    -- 当前累计暂停毫秒数（含正在进行的暂停已过时间）
    SELECT COALESCE(total_paused_ms, 0) INTO v_paused_ms
    FROM games WHERE id = p_game_id;

    SELECT v_paused_ms
         + COALESCE(FLOOR(EXTRACT(EPOCH FROM (v_now - paused_at)) * 1000), 0)
    INTO v_paused_ms
    FROM games
    WHERE id = p_game_id
      AND is_paused = TRUE
      AND paused_at IS NOT NULL;

    SELECT COALESCE(current_quarter, 1) INTO v_quarter
    FROM games WHERE id = p_game_id;

    -- 关闭旧上场记录（若存在）：
    -- 保证"重新上场"总是产生新记录；remove 未先执行也能正确关场
    UPDATE game_lineup
       SET is_current       = FALSE,
           off_at           = v_now,
           paused_ms_at_off = COALESCE(v_paused_ms, 0)
     WHERE game_id   = p_game_id
       AND player_id = p_player_id
       AND is_current = TRUE;

    -- 插入新的上场记录
    INSERT INTO game_lineup (
      game_id, team_id, player_id, slot_no,
      is_current, on_at, quarter, paused_ms_at_on
    )
    VALUES (
      p_game_id, p_team_id, p_player_id, p_slot_no,
      TRUE, v_now, v_quarter, COALESCE(v_paused_ms, 0)
    )
    RETURNING id INTO v_lineup_id;

    RETURN json_build_object('lineup_id', v_lineup_id);

  ELSIF p_mode = 'remove' THEN
    -- 下场时刻的累计暂停毫秒数（含正在进行的暂停）
    SELECT COALESCE(total_paused_ms, 0) INTO v_paused_ms
    FROM games WHERE id = p_game_id;

    SELECT v_paused_ms
         + COALESCE(FLOOR(EXTRACT(EPOCH FROM (v_now - paused_at)) * 1000), 0)
    INTO v_paused_ms
    FROM games
    WHERE id = p_game_id
      AND is_paused = TRUE
      AND paused_at IS NOT NULL;

    UPDATE game_lineup
       SET is_current       = FALSE,
           off_at           = v_now,
           paused_ms_at_off = COALESCE(v_paused_ms, 0)
     WHERE game_id   = p_game_id
       AND player_id = p_player_id
       AND is_current = TRUE;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ══════════════════════════════════════════════════════════
-- 第3.5步：update_game_status 兜底——直接设 finished 时自动写 finished_at
-- （前端正常流程已传 p_finished_at；此修复防止其他调用路径漏传，
--   导致已结束比赛重开教练页时在场球员时间虚增）
-- ══════════════════════════════════════════════════════════
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
      finished_at      = COALESCE(
                           p_finished_at,
                           CASE WHEN p_status = 'finished' THEN NOW() ELSE finished_at END
                         ),
      is_paused        = COALESCE(p_is_paused, is_paused),
      clock_updated_at = CASE
                           WHEN v_game_type = 'official' AND p_status = 'active' AND status <> 'active'
                           THEN NOW() ELSE clock_updated_at END
    WHERE id = p_game_id;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_game_status(UUID, VARCHAR(20), TIMESTAMPTZ, TIMESTAMPTZ, BOOLEAN, INTEGER) TO anon, authenticated;

-- 第4步：验证
SELECT
  proname,
  pg_get_function_identity_arguments(oid) AS args
FROM pg_proc
WHERE pronamespace = 'public'::regnamespace
  AND proname IN ('swap_player', 'update_game_status');
