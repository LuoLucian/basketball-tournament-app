-- ============================================================
-- 默认场地 + 赛程时间同步
-- 在 Supabase SQL Editor 中整体执行（可重复执行，幂等）
-- 内容：
--   1. 数据修复：tournaments / games 空场地统一为「德泰科技园篮球场」
--   2. create_match_game：场地兜底 德泰科技园篮球场
--   3. update_match_schedule：时间/场地同步到已创建的比赛（games）
--      —— 抽签后一键创建比赛，仍可在锦标赛页改时间并同步生效
-- ============================================================

-- ══ 1. 数据修复：空场地统一默认值 ═════════════════════════
UPDATE tournaments SET venue = '德泰科技园篮球场' WHERE venue IS NULL OR venue = '';
UPDATE games       SET venue = '德泰科技园篮球场' WHERE venue IS NULL OR venue = '';

-- ══ 2. create_match_game：场地兜底（v3 版本 + 场地回退）════
CREATE OR REPLACE FUNCTION create_match_game(p_match_id UUID) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_rec RECORD;
  v_game_id UUID;
  v_home_name TEXT;
  v_away_name TEXT;
  v_stage_label TEXT;
BEGIN
  SELECT m.*, t.name AS t_name, t.quarters AS t_quarters, t.quarter_seconds AS t_qsecs,
         t.venue AS t_venue, t.group_count AS t_group_count
  INTO v_rec
  FROM tournament_matches m
  JOIN tournaments t ON t.id = m.tournament_id
  WHERE m.id = p_match_id;

  IF v_rec.id IS NULL THEN RAISE EXCEPTION '赛程不存在'; END IF;
  IF v_rec.game_id IS NOT NULL THEN
    RETURN jsonb_build_object('success', true, 'game_id', v_rec.game_id);
  END IF;
  IF v_rec.home_team_id IS NULL OR v_rec.away_team_id IS NULL THEN
    RAISE EXCEPTION '比赛队伍尚未确定（等待前序比赛结束）';
  END IF;

  SELECT name INTO v_home_name FROM teams WHERE id = v_rec.home_team_id;
  SELECT name INTO v_away_name FROM teams WHERE id = v_rec.away_team_id;

  v_stage_label := CASE v_rec.stage
    WHEN 'group' THEN CASE WHEN v_rec.t_group_count = 1
                           THEN '循环赛第' || v_rec.round || '轮'
                           ELSE COALESCE(v_rec.group_name, '') || '组小组赛第' || v_rec.round || '轮' END
    WHEN 'quarterfinal' THEN '四分之一决赛'
    WHEN 'semifinal' THEN '半决赛'
    WHEN 'third_place' THEN '季军赛'
    WHEN 'final' THEN '决赛'
  END;

  INSERT INTO games (title, game_type, home_team_id, away_team_id,
                     quarters, quarter_seconds, quarter_clock, venue, scheduled_at)
  VALUES (
    left(v_rec.t_name || ' · ' || v_stage_label || ' ' || v_home_name || ' vs ' || v_away_name, 200),
    'official', v_rec.home_team_id, v_rec.away_team_id,
    COALESCE(v_rec.t_quarters, 4), COALESCE(v_rec.t_qsecs, 600), COALESCE(v_rec.t_qsecs, 600),
    COALESCE(v_rec.venue, v_rec.t_venue, '德泰科技园篮球场'), v_rec.scheduled_at
  )
  RETURNING id INTO v_game_id;

  UPDATE tournament_matches SET game_id = v_game_id WHERE id = p_match_id;

  IF auth.uid() IS NOT NULL THEN
    INSERT INTO game_recorders (game_id, user_id)
    VALUES (v_game_id, auth.uid())
    ON CONFLICT DO NOTHING;
  END IF;

  PERFORM add_tournament_announcement(v_rec.tournament_id, 'match',
    '📋 第' || v_rec.match_order || '场 ' || v_stage_label || '：' || v_home_name || ' vs ' || v_away_name || '，比赛已就绪！');

  RETURN jsonb_build_object('success', true, 'game_id', v_game_id);
END;
$$;

-- ══ 3. update_match_schedule：同步已创建的比赛 ════════════
-- 修改赛程时间/场地时，若比赛已创建（game_id 非空），
-- 同步写入 games.scheduled_at / games.venue，保证两处一致
CREATE OR REPLACE FUNCTION update_match_schedule(
  p_match_id UUID,
  p_scheduled_at TIMESTAMPTZ DEFAULT NULL,
  p_venue VARCHAR(200) DEFAULT NULL
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_game_id UUID;
BEGIN
  UPDATE tournament_matches SET
    scheduled_at = COALESCE(p_scheduled_at, scheduled_at),
    venue = COALESCE(p_venue, venue)
  WHERE id = p_match_id
  RETURNING game_id INTO v_game_id;

  IF NOT FOUND THEN RAISE EXCEPTION '赛程不存在'; END IF;

  IF v_game_id IS NOT NULL THEN
    UPDATE games SET
      scheduled_at = COALESCE(p_scheduled_at, scheduled_at),
      venue = COALESCE(p_venue, venue)
    WHERE id = v_game_id;
  END IF;
END;
$$;

-- ══ 4. 授权（CREATE OR REPLACE 保留授权，此处显式保持）════
GRANT EXECUTE ON FUNCTION create_match_game(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION update_match_schedule(UUID, TIMESTAMPTZ, VARCHAR(200)) TO anon, authenticated;

-- 验证
SELECT count(*) AS games_missing_venue FROM games WHERE venue IS NULL OR venue = '';
SELECT count(*) AS tournaments_missing_venue FROM tournaments WHERE venue IS NULL OR venue = '';
