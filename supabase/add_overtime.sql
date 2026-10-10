-- ============================================================
-- 加时赛（Overtime）+ 暂停次数 综合脚本
-- 规则（FIBA 正式制）：
--   · 常规 4 节结束若比分相同 → 进入加时，每个加时 5 分钟
--   · 加时仍平 → 继续下一个加时（每加时 5 分钟），直到分出胜负
--   · 每个加时可请求 1 次暂停（进入新加时时清零）
--   · 常规时间暂停：上半场(Q1-Q2) 2 次 / 下半场(Q3-Q4) 3 次，不结转
-- 说明：本脚本已包含上一版暂停字段，重复执行安全（IF NOT EXISTS / CREATE OR REPLACE）
-- 使用：在 Supabase SQL Editor 中完整执行本文件
-- ============================================================

-- ── 1. games 字段 ──
-- 常规时间暂停（按半场）
ALTER TABLE games ADD COLUMN IF NOT EXISTS home_timeouts_h1 SMALLINT NOT NULL DEFAULT 0;
ALTER TABLE games ADD COLUMN IF NOT EXISTS home_timeouts_h2 SMALLINT NOT NULL DEFAULT 0;
ALTER TABLE games ADD COLUMN IF NOT EXISTS away_timeouts_h1 SMALLINT NOT NULL DEFAULT 0;
ALTER TABLE games ADD COLUMN IF NOT EXISTS away_timeouts_h2 SMALLINT NOT NULL DEFAULT 0;
-- 加时暂停（每个加时独立，进入新加时时清零）
ALTER TABLE games ADD COLUMN IF NOT EXISTS home_timeouts_ot SMALLINT NOT NULL DEFAULT 0;
ALTER TABLE games ADD COLUMN IF NOT EXISTS away_timeouts_ot SMALLINT NOT NULL DEFAULT 0;
-- 加时时长（秒），默认 5 分钟
ALTER TABLE games ADD COLUMN IF NOT EXISTS overtime_seconds SMALLINT NOT NULL DEFAULT 300;

-- ── 2. 记录暂停 RPC（含加时：每加时 1 次）──
CREATE OR REPLACE FUNCTION public.record_timeout(
  p_game_id UUID,
  p_team_id UUID,
  p_delta   SMALLINT DEFAULT 1
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  g         RECORD;
  v_regular SMALLINT;
  v_half    SMALLINT;
  v_max     SMALLINT;
  v_used    SMALLINT;
BEGIN
  SELECT * INTO g FROM games WHERE id = p_game_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION '比赛不存在';
  END IF;

  IF NOT (
    is_game_recorder(p_game_id)
    OR (
      auth.uid() IS NOT NULL
      AND (
        EXISTS (SELECT 1 FROM teams WHERE id = g.home_team_id AND owner_id = auth.uid())
        OR EXISTS (SELECT 1 FROM teams WHERE id = g.away_team_id AND owner_id = auth.uid())
      )
    )
  ) THEN
    RAISE EXCEPTION '无权记录暂停';
  END IF;

  IF p_team_id <> g.home_team_id AND p_team_id <> g.away_team_id THEN
    RAISE EXCEPTION '队伍不属于本场比赛';
  END IF;

  v_regular := COALESCE(g.quarters, 4);

  -- 加时：每个加时 1 次暂停
  IF COALESCE(g.current_quarter, 1) > v_regular THEN
    v_max  := 1;
    v_used := CASE WHEN p_team_id = g.home_team_id
                   THEN COALESCE(g.home_timeouts_ot, 0)
                   ELSE COALESCE(g.away_timeouts_ot, 0) END;
    v_used := GREATEST(0, LEAST(v_max, v_used + COALESCE(p_delta, 1)));
    IF p_team_id = g.home_team_id THEN
      UPDATE games SET home_timeouts_ot = v_used WHERE id = p_game_id;
    ELSE
      UPDATE games SET away_timeouts_ot = v_used WHERE id = p_game_id;
    END IF;
    RETURN jsonb_build_object('overtime', true, 'used', v_used, 'max', v_max);
  END IF;

  -- 常规时间：按半场（上半场 2 次 / 下半场 3 次）
  v_half := CASE WHEN COALESCE(g.current_quarter, 1) <= CEIL(v_regular / 2.0) THEN 1 ELSE 2 END;
  v_max  := CASE WHEN v_half = 1 THEN 2 ELSE 3 END;

  IF p_team_id = g.home_team_id THEN
    v_used := CASE WHEN v_half = 1 THEN COALESCE(g.home_timeouts_h1, 0)
                                    ELSE COALESCE(g.home_timeouts_h2, 0) END;
    v_used := GREATEST(0, LEAST(v_max, v_used + COALESCE(p_delta, 1)));
    UPDATE games SET
      home_timeouts_h1 = CASE WHEN v_half = 1 THEN v_used ELSE home_timeouts_h1 END,
      home_timeouts_h2 = CASE WHEN v_half = 2 THEN v_used ELSE home_timeouts_h2 END
    WHERE id = p_game_id;
  ELSE
    v_used := CASE WHEN v_half = 1 THEN COALESCE(g.away_timeouts_h1, 0)
                                    ELSE COALESCE(g.away_timeouts_h2, 0) END;
    v_used := GREATEST(0, LEAST(v_max, v_used + COALESCE(p_delta, 1)));
    UPDATE games SET
      away_timeouts_h1 = CASE WHEN v_half = 1 THEN v_used ELSE away_timeouts_h1 END,
      away_timeouts_h2 = CASE WHEN v_half = 2 THEN v_used ELSE away_timeouts_h2 END
    WHERE id = p_game_id;
  END IF;

  RETURN jsonb_build_object('half', v_half, 'used', v_used, 'max', v_max);
END;
$$;

GRANT EXECUTE ON FUNCTION public.record_timeout(UUID, UUID, SMALLINT) TO authenticated;

-- ── 3. end_quarter RPC（常规结束平局 → 加时 5 分钟）──
CREATE OR REPLACE FUNCTION public.end_quarter(
  p_game_id      UUID,
  p_from_quarter SMALLINT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  g         RECORD;
  v_next    SMALLINT;
  v_regular SMALLINT;
  v_ot_secs SMALLINT;
BEGIN
  SELECT * INTO g FROM games WHERE id = p_game_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '比赛不存在'; END IF;
  IF g.game_type <> 'official' THEN RAISE EXCEPTION '仅正式制支持节切换'; END IF;

  IF COALESCE(g.current_quarter, 1) <> p_from_quarter THEN
    RETURN jsonb_build_object('quarter', g.current_quarter, 'finished', g.status = 'finished', 'stale', true);
  END IF;

  v_regular := COALESCE(g.quarters, 4);
  v_next    := COALESCE(g.current_quarter, 1) + 1;
  v_ot_secs := COALESCE(g.overtime_seconds, 300);

  IF v_next > v_regular THEN
    -- 常规时间（或前一个加时）结束：平局 → 进入加时；否则结束比赛
    IF COALESCE(g.home_score, 0) = COALESCE(g.away_score, 0) THEN
      UPDATE games SET
        current_quarter  = v_next,
        quarter_clock    = v_ot_secs,
        is_paused        = TRUE,
        paused_at        = NOW(),
        clock_updated_at = NOW(),
        home_timeouts_ot = 0,
        away_timeouts_ot = 0
      WHERE id = p_game_id;
      RETURN jsonb_build_object('quarter', v_next, 'finished', false, 'overtime', true);
    END IF;

    UPDATE games SET
      status           = 'finished',
      finished_at      = NOW(),
      is_paused        = FALSE,
      quarter_clock    = 0,
      clock_updated_at = NOW(),
      total_paused_ms  = COALESCE(total_paused_ms, 0)
                         + FLOOR(EXTRACT(EPOCH FROM (NOW() - COALESCE(paused_at, NOW()))) * 1000),
      paused_at        = NULL
    WHERE id = p_game_id;
    PERFORM announce_game_result(p_game_id);
    RETURN jsonb_build_object('quarter', v_regular, 'finished', true);
  ELSE
    UPDATE games SET
      current_quarter  = v_next,
      quarter_clock    = COALESCE(g.quarter_seconds, 600),
      is_paused        = TRUE,
      paused_at        = NOW(),
      clock_updated_at = NOW()
    WHERE id = p_game_id;
    RETURN jsonb_build_object('quarter', v_next, 'finished', false);
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.end_quarter(UUID, SMALLINT) TO anon, authenticated;

-- ── 4. 验证（三项都应返回 1）──
SELECT 'games.overtime_seconds 已添加' AS item, COUNT(*) AS ok
FROM information_schema.columns WHERE table_name = 'games' AND column_name = 'overtime_seconds'
UNION ALL
SELECT 'games.home_timeouts_ot 已添加', COUNT(*)
FROM information_schema.columns WHERE table_name = 'games' AND column_name = 'home_timeouts_ot'
UNION ALL
SELECT 'record_timeout 已创建', COUNT(*) FROM pg_proc WHERE proname = 'record_timeout';