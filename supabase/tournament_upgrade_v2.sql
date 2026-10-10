-- ============================================================
-- 锦标赛升级 v2：季军赛 + 循环赛模式
-- 1. 季军赛：半决赛负者自动进入季军赛，决出第三名
-- 2. 循环赛：全员单循环（复用 1 组结构），前 4 名 → 半决赛(1v4, 2v3)
--    → 季军赛 → 决赛；前 2 名 → 直接决赛
-- 在 Supabase SQL Editor 中执行
-- ============================================================

-- 1. create_tournament：允许 循环赛(1组)×前4 出线 ----------------
CREATE OR REPLACE FUNCTION create_tournament(
  p_name VARCHAR(100),
  p_venue VARCHAR(200) DEFAULT NULL,
  p_start_date DATE DEFAULT NULL,
  p_group_count SMALLINT DEFAULT 2,
  p_advance_per_group SMALLINT DEFAULT 2,
  p_quarters SMALLINT DEFAULT 4,
  p_quarter_seconds SMALLINT DEFAULT 600,
  p_team_ids UUID[] DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id UUID;
  v_count INT;
BEGIN
  IF p_name IS NULL OR p_name = '' THEN RAISE EXCEPTION '锦标赛名称不能为空'; END IF;
  IF p_team_ids IS NULL OR array_length(p_team_ids, 1) IS NULL THEN RAISE EXCEPTION '请选择参赛球队'; END IF;
  IF p_group_count NOT IN (1, 2, 4) THEN RAISE EXCEPTION '小组数量仅支持 1 / 2 / 4 组'; END IF;
  IF NOT (
    p_advance_per_group IN (1, 2)
    OR (p_group_count = 1 AND p_advance_per_group = 4)
  ) THEN
    RAISE EXCEPTION '出线名额无效：仅支持每组 1/2 名，或循环赛(1组)前 4 名';
  END IF;

  SELECT count(*) INTO v_count FROM teams WHERE id = ANY(p_team_ids) AND is_active = true;
  IF v_count < 2 THEN RAISE EXCEPTION '至少需要 2 支有效球队'; END IF;
  IF v_count < p_group_count THEN RAISE EXCEPTION '球队数量不能少于小组数量'; END IF;
  IF p_group_count = 1 AND p_advance_per_group = 4 AND v_count < 4 THEN
    RAISE EXCEPTION '循环赛前 4 名出线至少需要 4 支球队';
  END IF;

  INSERT INTO tournaments (name, venue, start_date, group_count, advance_per_group,
                           quarters, quarter_seconds, created_by)
  VALUES (p_name, p_venue, p_start_date, p_group_count, p_advance_per_group,
          p_quarters, p_quarter_seconds, auth.uid())
  RETURNING id INTO v_id;

  INSERT INTO tournament_teams (tournament_id, team_id)
  SELECT v_id, unnest(p_team_ids);

  RETURN jsonb_build_object('success', true, 'tournament_id', v_id);
END;
$$;

-- 2. create_playoffs：循环赛取名次 + 季军赛 ----------------------
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
  v_rank UUID;
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
             AND stage IN ('quarterfinal','semifinal','final','third_place')) THEN
    RAISE EXCEPTION '淘汰赛已生成';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM tournament_matches WHERE tournament_id = p_tournament_id AND stage = 'group') THEN
    RAISE EXCEPTION '请先生成循环赛/小组赛程';
  END IF;
  IF EXISTS (
    SELECT 1 FROM tournament_matches m LEFT JOIN games g ON g.id = m.game_id
    WHERE m.tournament_id = p_tournament_id AND m.stage = 'group'
      AND (m.game_id IS NULL OR g.status <> 'finished')
  ) THEN
    RAISE EXCEPTION '第一阶段比赛尚未全部结束';
  END IF;

  v_size := v_t.group_count * v_t.advance_per_group;
  IF v_size < 2 THEN RAISE EXCEPTION '出线队伍不足，无法生成淘汰赛'; END IF;
  v_stage_first := CASE v_size WHEN 2 THEN 'final' WHEN 4 THEN 'semifinal' WHEN 8 THEN 'quarterfinal' END;

  -- 场次编号接续第一阶段
  SELECT COALESCE(MAX(match_order), 0) INTO v_match_order
  FROM tournament_matches WHERE tournament_id = p_tournament_id;

  IF v_t.group_count = 1 THEN
    -- 循环赛：按积分榜名次取种子
    FOR v_i IN 1..v_size LOOP
      SELECT team_id INTO v_rank FROM v_tournament_standings
        WHERE tournament_id = p_tournament_id
        ORDER BY points DESC, diff DESC, pts_for DESC
        LIMIT 1 OFFSET (v_i - 1);
      IF v_rank IS NULL THEN RAISE EXCEPTION '积分榜名次不足，无法确定全部出线队伍'; END IF;
      v_seeds := v_seeds || v_rank;
    END LOOP;
    -- 前4出线：半决赛 1v4、2v3
    IF v_size = 4 THEN
      v_seeds := ARRAY[v_seeds[1], v_seeds[4], v_seeds[2], v_seeds[3]];
    END IF;
  ELSE
    -- 小组赛交叉：第 i 组第 1 名 对阵 第 i+1 组第 2 名
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
  END IF;

  -- 第一轮淘汰赛
  v_cur_ids := '{}';
  FOR v_i IN 1..(v_size / 2) LOOP
    v_match_order := v_match_order + 1;
    INSERT INTO tournament_matches (tournament_id, stage, round, home_team_id, away_team_id, match_order)
    VALUES (p_tournament_id, v_stage_first, 1, v_seeds[v_i * 2 - 1], v_seeds[v_i * 2], v_match_order)
    RETURNING id INTO v_m;
    v_cur_ids := v_cur_ids || v_m;
  END LOOP;

  -- 后续轮次 + 季军赛
  v_stage := v_stage_first;
  WHILE array_length(v_cur_ids, 1) > 1 LOOP
    v_next_stage := CASE v_stage WHEN 'quarterfinal' THEN 'semifinal'
                                 WHEN 'semifinal' THEN 'final' END;
    v_next_ids := '{}';
    -- 半决赛 → 决赛时，先生成季军赛（半决赛负者参加）
    IF v_stage = 'semifinal' THEN
      v_match_order := v_match_order + 1;
      INSERT INTO tournament_matches (tournament_id, stage, round, home_from, away_from, match_order)
      VALUES (p_tournament_id, 'third_place', 1, v_cur_ids[1], v_cur_ids[2], v_match_order)
      RETURNING id INTO v_m;
    END IF;
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

-- 3. sync_playoff_teams：季军赛填负者 + 全部完成才结束 -----------
CREATE OR REPLACE FUNCTION sync_playoff_teams(p_tournament_id UUID) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_rec RECORD;
  v_winner UUID;
  v_take_loser BOOLEAN;
  v_filled INT := 0;
  v_pending INT;
BEGIN
  FOR v_rec IN
    SELECT m.id, m.stage, m.home_team_id, m.away_team_id, m.home_from, m.away_from
    FROM tournament_matches m
    WHERE m.tournament_id = p_tournament_id
      AND m.stage IN ('quarterfinal','semifinal','final','third_place')
      AND (m.home_team_id IS NULL OR m.away_team_id IS NULL)
      AND (m.home_from IS NOT NULL OR m.away_from IS NOT NULL)
  LOOP
    -- 季军赛取半决赛负者，其余取胜者
    v_take_loser := (v_rec.stage = 'third_place');

    IF v_rec.home_team_id IS NULL AND v_rec.home_from IS NOT NULL THEN
      SELECT CASE
               WHEN v_take_loser AND g.home_score > g.away_score THEN f.away_team_id
               WHEN v_take_loser AND g.away_score > g.home_score THEN f.home_team_id
               WHEN NOT v_take_loser AND g.home_score > g.away_score THEN f.home_team_id
               WHEN NOT v_take_loser AND g.away_score > g.home_score THEN f.away_team_id
             END
      INTO v_winner
      FROM tournament_matches f JOIN games g ON g.id = f.game_id
      WHERE f.id = v_rec.home_from AND g.status = 'finished'
        AND f.home_team_id IS NOT NULL AND f.away_team_id IS NOT NULL;
      IF v_winner IS NOT NULL THEN
        UPDATE tournament_matches SET home_team_id = v_winner WHERE id = v_rec.id;
        v_filled := v_filled + 1;
      END IF;
    END IF;

    IF v_rec.away_team_id IS NULL AND v_rec.away_from IS NOT NULL THEN
      SELECT CASE
               WHEN v_take_loser AND g.home_score > g.away_score THEN f.away_team_id
               WHEN v_take_loser AND g.away_score > g.home_score THEN f.home_team_id
               WHEN NOT v_take_loser AND g.home_score > g.away_score THEN f.home_team_id
               WHEN NOT v_take_loser AND g.away_score > g.home_score THEN f.away_team_id
             END
      INTO v_winner
      FROM tournament_matches f JOIN games g ON g.id = f.game_id
      WHERE f.id = v_rec.away_from AND g.status = 'finished'
        AND f.home_team_id IS NOT NULL AND f.away_team_id IS NOT NULL;
      IF v_winner IS NOT NULL THEN
        UPDATE tournament_matches SET away_team_id = v_winner WHERE id = v_rec.id;
        v_filled := v_filled + 1;
      END IF;
    END IF;
  END LOOP;

  -- 淘汰赛（含季军赛）全部结束 → 锦标赛完成
  SELECT count(*) INTO v_pending
  FROM tournament_matches m LEFT JOIN games g ON g.id = m.game_id
  WHERE m.tournament_id = p_tournament_id
    AND m.stage <> 'group'
    AND (m.game_id IS NULL OR g.status <> 'finished');
  IF v_pending = 0 AND EXISTS (
    SELECT 1 FROM tournament_matches WHERE tournament_id = p_tournament_id AND stage <> 'group'
  ) THEN
    UPDATE tournaments SET status = 'finished' WHERE id = p_tournament_id;
  END IF;

  RETURN jsonb_build_object('success', true, 'filled', v_filled);
END;
$$;

-- 4. create_match_game：季军赛标题 -------------------------------
CREATE OR REPLACE FUNCTION create_match_game(p_match_id UUID) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_rec RECORD;
  v_game_id UUID;
  v_home_name TEXT;
  v_away_name TEXT;
BEGIN
  SELECT m.*, t.name AS t_name, t.quarters AS t_quarters, t.quarter_seconds AS t_qsecs,
         t.venue AS t_venue
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

  INSERT INTO games (title, game_type, home_team_id, away_team_id,
                     quarters, quarter_seconds, quarter_clock, venue, scheduled_at)
  VALUES (
    left(v_rec.t_name || ' · ' ||
      CASE v_rec.stage
        WHEN 'group' THEN CASE WHEN v_rec.group_name IS NOT NULL AND v_rec.group_name <> 'A'
                               THEN '小组赛' || v_rec.group_name || '第' || v_rec.round || '轮'
                               ELSE '循环赛第' || v_rec.round || '轮' END
        WHEN 'quarterfinal' THEN '四分之一决赛'
        WHEN 'semifinal' THEN '半决赛'
        WHEN 'third_place' THEN '季军赛'
        WHEN 'final' THEN '决赛'
      END || ' ' || v_home_name || ' vs ' || v_away_name, 200),
    'official', v_rec.home_team_id, v_rec.away_team_id,
    COALESCE(v_rec.t_quarters, 4), COALESCE(v_rec.t_qsecs, 600), COALESCE(v_rec.t_qsecs, 600),
    COALESCE(v_rec.venue, v_rec.t_venue), v_rec.scheduled_at
  )
  RETURNING id INTO v_game_id;

  UPDATE tournament_matches SET game_id = v_game_id WHERE id = p_match_id;

  IF auth.uid() IS NOT NULL THEN
    INSERT INTO game_recorders (game_id, user_id)
    VALUES (v_game_id, auth.uid())
    ON CONFLICT DO NOTHING;
  END IF;

  RETURN jsonb_build_object('success', true, 'game_id', v_game_id);
END;
$$;
