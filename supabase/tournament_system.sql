-- ============================================================
-- 锦标赛系统：小组赛（抽签分组+单循环）→ 半决赛/决赛
-- 在 Supabase SQL Editor 中整体执行
-- ============================================================

-- 1. 锦标赛主表 ------------------------------------------------
CREATE TABLE IF NOT EXISTS tournaments (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          VARCHAR(100) NOT NULL,
  venue         VARCHAR(200),
  start_date    DATE,
  status        VARCHAR(20) NOT NULL DEFAULT 'draft',
                -- draft(待抽签) / group_stage(小组赛中) / playoffs(淘汰赛) / finished(已结束)
  group_count   SMALLINT NOT NULL DEFAULT 2,
  advance_per_group SMALLINT NOT NULL DEFAULT 2,
  quarters      SMALLINT DEFAULT 4,
  quarter_seconds SMALLINT DEFAULT 600,
  created_by    UUID REFERENCES profiles(id),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. 参赛球队（含抽签分组结果）----------------------------------
CREATE TABLE IF NOT EXISTS tournament_teams (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tournament_id  UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
  team_id        UUID NOT NULL REFERENCES teams(id),
  group_name     VARCHAR(4),          -- A / B / C / D
  draw_order     SMALLINT,            -- 抽签序号
  UNIQUE (tournament_id, team_id)
);

-- 3. 赛程表 ----------------------------------------------------
CREATE TABLE IF NOT EXISTS tournament_matches (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tournament_id  UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
  stage          VARCHAR(20) NOT NULL, -- group / quarterfinal / semifinal / final
  group_name     VARCHAR(4),
  round          SMALLINT DEFAULT 1,
  home_team_id   UUID REFERENCES teams(id),
  away_team_id   UUID REFERENCES teams(id),
  home_from      UUID REFERENCES tournament_matches(id), -- 晋级来源（淘汰赛）
  away_from      UUID REFERENCES tournament_matches(id),
  game_id        UUID REFERENCES games(id),
  scheduled_at   TIMESTAMPTZ,
  venue          VARCHAR(200),
  match_order    SMALLINT DEFAULT 0,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tournament_teams_tid  ON tournament_teams(tournament_id);
CREATE INDEX IF NOT EXISTS idx_tournament_matches_tid ON tournament_matches(tournament_id);

-- RLS：公开读，写仅通过 SECURITY DEFINER RPC
ALTER TABLE tournaments       ENABLE ROW LEVEL SECURITY;
ALTER TABLE tournament_teams  ENABLE ROW LEVEL SECURITY;
ALTER TABLE tournament_matches ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "tournaments_public_read" ON tournaments;
DROP POLICY IF EXISTS "tournament_teams_public_read" ON tournament_teams;
DROP POLICY IF EXISTS "tournament_matches_public_read" ON tournament_matches;
CREATE POLICY "tournaments_public_read" ON tournaments FOR SELECT USING (true);
CREATE POLICY "tournament_teams_public_read" ON tournament_teams FOR SELECT USING (true);
CREATE POLICY "tournament_matches_public_read" ON tournament_matches FOR SELECT USING (true);

-- 4. 小组积分榜视图（胜2分 负1分）------------------------------
CREATE OR REPLACE VIEW v_tournament_standings AS
WITH results AS (
  SELECT m.tournament_id, m.group_name, m.home_team_id AS team_id,
         g.home_score AS pts_for, g.away_score AS pts_against,
         (g.home_score > g.away_score) AS win
  FROM tournament_matches m
  JOIN games g ON g.id = m.game_id
  WHERE m.stage = 'group' AND g.status = 'finished' AND m.home_team_id IS NOT NULL
  UNION ALL
  SELECT m.tournament_id, m.group_name, m.away_team_id,
         g.away_score, g.home_score,
         (g.away_score > g.home_score)
  FROM tournament_matches m
  JOIN games g ON g.id = m.game_id
  WHERE m.stage = 'group' AND g.status = 'finished' AND m.away_team_id IS NOT NULL
)
SELECT r.tournament_id, r.group_name, r.team_id,
       t.name AS team_name, t.color AS team_color,
       COUNT(*) AS played,
       COUNT(*) FILTER (WHERE r.win) AS wins,
       COUNT(*) FILTER (WHERE NOT r.win) AS losses,
       COALESCE(SUM(r.pts_for), 0)     AS pts_for,
       COALESCE(SUM(r.pts_against), 0) AS pts_against,
       COALESCE(SUM(r.pts_for), 0) - COALESCE(SUM(r.pts_against), 0) AS diff,
       COUNT(*) + COUNT(*) FILTER (WHERE r.win) AS points
FROM results r
JOIN teams t ON t.id = r.team_id
GROUP BY r.tournament_id, r.group_name, r.team_id, t.name, t.color;

-- 5. 创建锦标赛 RPC --------------------------------------------
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

-- 6. 抽签：随机分组 + 生成小组赛单循环赛程 ----------------------
CREATE OR REPLACE FUNCTION draw_groups(p_tournament_id UUID) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_group_count INT;
  v_shuffled UUID[];
  v_group_names TEXT[] := ARRAY['A','B','C','D'];
  v_i INT;
  v_team_count INT;
  v_rec RECORD;
  v_arr UUID[];
  v_n INT;
  v_rounds INT;
  v_round INT;
  v_home UUID;
  v_away UUID;
  v_match_order INT := 0;
BEGIN
  SELECT group_count INTO v_group_count FROM tournaments WHERE id = p_tournament_id;
  IF v_group_count IS NULL THEN RAISE EXCEPTION '锦标赛不存在'; END IF;

  IF EXISTS (SELECT 1 FROM tournament_matches WHERE tournament_id = p_tournament_id AND stage = 'group') THEN
    RAISE EXCEPTION '已生成小组赛程，无法重新抽签';
  END IF;

  SELECT array_agg(team_id ORDER BY random()) INTO v_shuffled
  FROM tournament_teams WHERE tournament_id = p_tournament_id;
  v_team_count := COALESCE(array_length(v_shuffled, 1), 0);
  IF v_team_count < 2 THEN RAISE EXCEPTION '参赛球队不足'; END IF;

  -- 依次填入各组
  FOR v_i IN 1..v_team_count LOOP
    UPDATE tournament_teams
    SET group_name = v_group_names[((v_i - 1) % v_group_count) + 1],
        draw_order = v_i
    WHERE tournament_id = p_tournament_id AND team_id = v_shuffled[v_i];
  END LOOP;

  -- 每组单循环（圆桌法）
  FOR v_rec IN
    SELECT group_name, array_agg(team_id ORDER BY draw_order) AS ids
    FROM tournament_teams
    WHERE tournament_id = p_tournament_id AND group_name IS NOT NULL
    GROUP BY group_name
    ORDER BY group_name
  LOOP
    v_arr := v_rec.ids;
    v_n := array_length(v_arr, 1);
    IF v_n < 2 THEN CONTINUE; END IF;
    IF v_n % 2 = 1 THEN
      v_arr := v_arr || ARRAY[NULL::UUID];  -- 奇数队补轮空
      v_n := v_n + 1;
    END IF;
    v_rounds := v_n - 1;
    FOR v_round IN 1..v_rounds LOOP
      FOR v_i IN 1..(v_n / 2) LOOP
        v_home := v_arr[v_i];
        v_away := v_arr[v_n + 1 - v_i];
        IF v_home IS NOT NULL AND v_away IS NOT NULL THEN
          v_match_order := v_match_order + 1;
          INSERT INTO tournament_matches (tournament_id, stage, group_name, round, home_team_id, away_team_id, match_order)
          VALUES (p_tournament_id, 'group', v_rec.group_name, v_round, v_home, v_away, v_match_order);
        END IF;
      END LOOP;
      -- 轮转：固定第 1 位，其余右移
      v_arr := ARRAY[v_arr[1]] || ARRAY[v_arr[v_n]] || v_arr[2 : v_n - 1];
    END LOOP;
  END LOOP;

  UPDATE tournaments SET status = 'group_stage' WHERE id = p_tournament_id;

  RETURN jsonb_build_object('success', true,
    'match_count', (SELECT count(*) FROM tournament_matches WHERE tournament_id = p_tournament_id));
END;
$$;

-- 7. 更新比赛时间 / 场地 ---------------------------------------
CREATE OR REPLACE FUNCTION update_match_schedule(
  p_match_id UUID,
  p_scheduled_at TIMESTAMPTZ DEFAULT NULL,
  p_venue VARCHAR(200) DEFAULT NULL
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  UPDATE tournament_matches SET
    scheduled_at = COALESCE(p_scheduled_at, scheduled_at),
    venue = COALESCE(p_venue, venue)
  WHERE id = p_match_id;
  IF NOT FOUND THEN RAISE EXCEPTION '赛程不存在'; END IF;
END;
$$;

-- 8. 为赛程创建实际比赛（自动指派创建者为记录员）----------------
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
        WHEN 'group' THEN '小组赛' || v_rec.group_name || '第' || v_rec.round || '轮'
        WHEN 'quarterfinal' THEN '四分之一决赛'
        WHEN 'semifinal' THEN '半决赛'
        WHEN 'final' THEN '决赛'
      END || ' ' || v_home_name || ' vs ' || v_away_name, 200),
    'official', v_rec.home_team_id, v_rec.away_team_id,
    COALESCE(v_rec.t_quarters, 4), COALESCE(v_rec.t_qsecs, 600), COALESCE(v_rec.t_qsecs, 600),
    COALESCE(v_rec.venue, v_rec.t_venue), v_rec.scheduled_at
  )
  RETURNING id INTO v_game_id;

  UPDATE tournament_matches SET game_id = v_game_id WHERE id = p_match_id;

  -- 创建者自动成为记录员
  IF auth.uid() IS NOT NULL THEN
    INSERT INTO game_recorders (game_id, user_id)
    VALUES (v_game_id, auth.uid())
    ON CONFLICT DO NOTHING;
  END IF;

  RETURN jsonb_build_object('success', true, 'game_id', v_game_id);
END;
$$;

-- 9. 生成淘汰赛（循环赛按名次 / 小组赛交叉 + 季军赛）--------------
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

-- 10. 同步淘汰赛对阵（胜者晋级 / 季军赛填负者）-------------------
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

-- 11. 删除锦标赛（级联删除赛程分组，实际比赛不动）----------------
CREATE OR REPLACE FUNCTION delete_tournament(
  p_tournament_id UUID,
  p_user_id UUID DEFAULT NULL
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user UUID;
BEGIN
  v_user := COALESCE(p_user_id, auth.uid());
  IF v_user IS NULL OR NOT EXISTS (
    SELECT 1 FROM profiles WHERE id = v_user AND role IN ('super_admin','admin')
  ) THEN
    RAISE EXCEPTION '权限不足：仅管理员可删除锦标赛';
  END IF;
  DELETE FROM tournaments WHERE id = p_tournament_id;
  IF NOT FOUND THEN RAISE EXCEPTION '锦标赛不存在'; END IF;
END;
$$;

-- 12. 授权 -----------------------------------------------------
GRANT EXECUTE ON FUNCTION create_tournament TO anon, authenticated;
GRANT EXECUTE ON FUNCTION draw_groups TO anon, authenticated;
GRANT EXECUTE ON FUNCTION update_match_schedule TO anon, authenticated;
GRANT EXECUTE ON FUNCTION create_match_game TO anon, authenticated;
GRANT EXECUTE ON FUNCTION create_playoffs TO anon, authenticated;
GRANT EXECUTE ON FUNCTION sync_playoff_teams TO anon, authenticated;
GRANT EXECUTE ON FUNCTION delete_tournament TO anon, authenticated;
