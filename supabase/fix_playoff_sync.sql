-- ============================================================
-- 修复锦标赛两个 BUG（实测发现）
-- 1. sync_playoff_teams：FOR 循环 SELECT 缺 home_team_id/away_team_id 字段
--    导致晋级同步一执行就报 42703
-- 2. create_playoffs：match_order 从 0 重新计数，与小组赛编号重叠
--    （小组赛 #1-#4，淘汰赛又是 #1-#3，"第X场胜者"无法区分）
-- 在 Supabase SQL Editor 中执行
-- ============================================================

CREATE OR REPLACE FUNCTION sync_playoff_teams(p_tournament_id UUID) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_rec RECORD;
  v_winner UUID;
  v_filled INT := 0;
  v_final_done INT;
BEGIN
  FOR v_rec IN
    SELECT m.id, m.home_team_id, m.away_team_id, m.home_from, m.away_from
    FROM tournament_matches m
    WHERE m.tournament_id = p_tournament_id
      AND m.stage IN ('quarterfinal','semifinal','final')
      AND (m.home_team_id IS NULL OR m.away_team_id IS NULL)
      AND (m.home_from IS NOT NULL OR m.away_from IS NOT NULL)
  LOOP
    IF v_rec.home_team_id IS NULL AND v_rec.home_from IS NOT NULL THEN
      SELECT CASE WHEN g.home_score > g.away_score THEN f.home_team_id
                  WHEN g.away_score > g.home_score THEN f.away_team_id END
      INTO v_winner
      FROM tournament_matches f JOIN games g ON g.id = f.game_id
      WHERE f.id = v_rec.home_from AND g.status = 'finished';
      IF v_winner IS NOT NULL THEN
        UPDATE tournament_matches SET home_team_id = v_winner WHERE id = v_rec.id;
        v_filled := v_filled + 1;
      END IF;
    END IF;
    IF v_rec.away_team_id IS NULL AND v_rec.away_from IS NOT NULL THEN
      SELECT CASE WHEN g.home_score > g.away_score THEN f.home_team_id
                  WHEN g.away_score > g.home_score THEN f.away_team_id END
      INTO v_winner
      FROM tournament_matches f JOIN games g ON g.id = f.game_id
      WHERE f.id = v_rec.away_from AND g.status = 'finished';
      IF v_winner IS NOT NULL THEN
        UPDATE tournament_matches SET away_team_id = v_winner WHERE id = v_rec.id;
        v_filled := v_filled + 1;
      END IF;
    END IF;
  END LOOP;

  -- 决赛结束 → 锦标赛完成
  SELECT count(*) INTO v_final_done
  FROM tournament_matches m JOIN games g ON g.id = m.game_id
  WHERE m.tournament_id = p_tournament_id AND m.stage = 'final' AND g.status = 'finished';
  IF v_final_done > 0 THEN
    UPDATE tournaments SET status = 'finished' WHERE id = p_tournament_id;
  END IF;

  RETURN jsonb_build_object('success', true, 'filled', v_filled);
END;
$$;

CREATE OR REPLACE FUNCTION create_playoffs(p_tournament_id UUID) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_t RECORD;
  v_size INT;
  v_stage_first TEXT;
  v_group_names TEXT[] := ARRAY['A','B','C','D'];
  v_seeds UUID[] := '{}';
  v_i INT;
  v_home UUID;
  v_away UUID;
  v_match_order INT;
  v_m UUID;
  v_cur_ids UUID[];
  v_next_ids UUID[];
  v_stage TEXT;
  v_next_stage TEXT;
BEGIN
  SELECT * INTO v_t FROM tournaments WHERE id = p_tournament_id;
  IF v_t.id IS NULL THEN RAISE EXCEPTION '锦标赛不存在'; END IF;

  IF EXISTS (SELECT 1 FROM tournament_matches WHERE tournament_id = p_tournament_id
             AND stage IN ('quarterfinal','semifinal','final')) THEN
    RAISE EXCEPTION '淘汰赛已生成';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM tournament_matches WHERE tournament_id = p_tournament_id AND stage = 'group') THEN
    RAISE EXCEPTION '请先抽签生成小组赛程';
  END IF;
  IF EXISTS (
    SELECT 1 FROM tournament_matches m LEFT JOIN games g ON g.id = m.game_id
    WHERE m.tournament_id = p_tournament_id AND m.stage = 'group'
      AND (m.game_id IS NULL OR g.status <> 'finished')
  ) THEN
    RAISE EXCEPTION '小组赛尚未全部结束';
  END IF;

  v_size := v_t.group_count * v_t.advance_per_group;
  IF v_size < 2 THEN RAISE EXCEPTION '出线队伍不足，无法生成淘汰赛'; END IF;
  v_stage_first := CASE v_size WHEN 2 THEN 'final' WHEN 4 THEN 'semifinal' WHEN 8 THEN 'quarterfinal' END;

  -- 场次编号接续小组赛，避免与小组赛编号重叠
  SELECT COALESCE(MAX(match_order), 0) INTO v_match_order
  FROM tournament_matches WHERE tournament_id = p_tournament_id;

  -- 交叉种子：第 i 组第 1 名 对阵 第 i+1 组第 2 名
  FOR v_i IN 1..v_t.group_count LOOP
    SELECT team_id INTO v_home FROM v_tournament_standings
      WHERE tournament_id = p_tournament_id AND group_name = v_group_names[v_i]
      ORDER BY points DESC, diff DESC, pts_for DESC LIMIT 1;
    SELECT team_id INTO v_away FROM v_tournament_standings
      WHERE tournament_id = p_tournament_id AND group_name = v_group_names[(v_i % v_t.group_count) + 1]
      ORDER BY points DESC, diff DESC, pts_for DESC LIMIT 1 OFFSET 1;
    IF v_home IS NULL OR v_away IS NULL THEN
      RAISE EXCEPTION '小组积分不足，无法确定全部出线队伍';
    END IF;
    v_seeds := v_seeds || ARRAY[v_home, v_away];
  END LOOP;

  -- 第一轮淘汰赛
  v_cur_ids := '{}';
  FOR v_i IN 1..(v_size / 2) LOOP
    v_match_order := v_match_order + 1;
    INSERT INTO tournament_matches (tournament_id, stage, round, home_team_id, away_team_id, match_order)
    VALUES (p_tournament_id, v_stage_first, 1, v_seeds[v_i * 2 - 1], v_seeds[v_i * 2], v_match_order)
    RETURNING id INTO v_m;
    v_cur_ids := v_cur_ids || v_m;
  END LOOP;

  -- 后续轮次：队伍待定，记录晋级来源
  v_stage := v_stage_first;
  WHILE array_length(v_cur_ids, 1) > 1 LOOP
    v_next_stage := CASE v_stage WHEN 'quarterfinal' THEN 'semifinal'
                                 WHEN 'semifinal' THEN 'final' END;
    v_next_ids := '{}';
    FOR v_i IN 1..(array_length(v_cur_ids, 1) / 2) LOOP
      v_match_order := v_match_order + 1;
      INSERT INTO tournament_matches (tournament_id, stage, round, home_from, away_from, match_order)
      VALUES (p_tournament_id, v_next_stage, 1, v_cur_ids[v_i * 2 - 1], v_cur_ids[v_i * 2], v_match_order)
      RETURNING id INTO v_m;
      v_next_ids := v_next_ids || v_m;
    END LOOP;
    v_cur_ids := v_next_ids;
    v_stage := v_next_stage;
  END LOOP;

  UPDATE tournaments SET status = 'playoffs' WHERE id = p_tournament_id;

  RETURN jsonb_build_object('success', true);
END;
$$;
