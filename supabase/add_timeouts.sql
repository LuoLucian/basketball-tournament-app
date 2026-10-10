-- ============================================================
-- 暂停次数（FIBA 规则）+ 大屏展示支持脚本
-- 规则：4 节制 上半场(Q1-Q2) 每队 2 次、下半场(Q3-Q4) 每队 3 次，
--       上半场未用完不结转到下半场（与 FIBA 一致）
-- 存储：直接放在 games 表，按半场分列；写入后 games 已在 realtime
--       publication 中，大屏/详情页会自动同步
-- 使用：在 Supabase SQL Editor 中完整执行本文件（先于前端发布）
-- ============================================================

-- ── 1. games 增加半场暂停已用次数 ──
ALTER TABLE games ADD COLUMN IF NOT EXISTS home_timeouts_h1 SMALLINT NOT NULL DEFAULT 0;
ALTER TABLE games ADD COLUMN IF NOT EXISTS home_timeouts_h2 SMALLINT NOT NULL DEFAULT 0;
ALTER TABLE games ADD COLUMN IF NOT EXISTS away_timeouts_h1 SMALLINT NOT NULL DEFAULT 0;
ALTER TABLE games ADD COLUMN IF NOT EXISTS away_timeouts_h2 SMALLINT NOT NULL DEFAULT 0;

-- ── 2. 记录暂停 RPC（p_delta=1 记录一次，-1 撤销一次）──
-- 权限：本场记录员 / 两队队长(owner)；按当前节次归入上/下半场并夹取到规则上限
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
  v_half    SMALLINT;
  v_max     SMALLINT;
  v_used    SMALLINT;
  v_regular SMALLINT;
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

-- ── 3. 验证（两条都应返回 1）──
SELECT 'games.home_timeouts_h1 已添加' AS item, COUNT(*) AS ok
FROM information_schema.columns
WHERE table_name = 'games' AND column_name = 'home_timeouts_h1'
UNION ALL
SELECT 'record_timeout 已创建', COUNT(*)
FROM pg_proc WHERE proname = 'record_timeout';