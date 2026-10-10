-- ============================================================
-- 锦标赛系统 v3：公告栏播报 + 队伍自行抽签
-- 在 Supabase SQL Editor 中整体执行（可重复执行，幂等）
-- 内容：
--   1. 新表 tournament_announcements（公告栏，实时播报）
--   2. 逐队抽签 RPC draw_lottery（队伍代表自己抽，抽中组+号位）
--   3. draw_groups 重构为"管理员一键代抽剩余球队"
--   4. create_match_game / update_game_status / end_quarter /
--      sync_playoff_teams / create_playoffs 全部接入公告播报
-- ============================================================

-- ══ 1. 公告表 ════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS tournament_announcements (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
  type          VARCHAR(20) NOT NULL DEFAULT 'info',
                -- draw(抽签) / schedule(赛程) / match(开赛) / result(赛果) / playoff(晋级) / info
  content       TEXT NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tournament_ann_tid
  ON tournament_announcements(tournament_id, created_at DESC);

ALTER TABLE tournament_announcements ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "tournament_announcements_public_read" ON tournament_announcements;
CREATE POLICY "tournament_announcements_public_read" ON tournament_announcements
  FOR SELECT USING (true);

-- 实时播报（Realtime 订阅）
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE tournament_announcements';
  END IF;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 抽签时间记录
ALTER TABLE tournament_teams ADD COLUMN IF NOT EXISTS drawn_at TIMESTAMPTZ;

-- ══ 2. 清理旧函数（防重载堆积）══════════════════════════
DROP FUNCTION IF EXISTS draw_groups(UUID);
DROP FUNCTION IF EXISTS draw_lottery(UUID, UUID, TEXT);
DROP FUNCTION IF EXISTS generate_group_schedule(UUID);
DROP FUNCTION IF EXISTS create_match_game(UUID);
DROP FUNCTION IF EXISTS update_game_status(UUID, VARCHAR(20), TIMESTAMPTZ, TIMESTAMPTZ, BOOLEAN, INTEGER);
DROP FUNCTION IF EXISTS end_quarter(UUID, SMALLINT);
DROP FUNCTION IF EXISTS sync_playoff_teams(UUID);

-- ══ 3. 公告写入 helper ══════════════════════════════════
CREATE OR REPLACE FUNCTION add_tournament_announcement(
  p_tournament_id UUID,
  p_type VARCHAR(20),
  p_content TEXT
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO tournament_announcements (tournament_id, type, content)
  VALUES (p_tournament_id, p_type, p_content);
END;
$$;

-- ══ 4. 生成小组赛单循环赛程（抽签完成后自动调用）════════
CREATE OR REPLACE FUNCTION generate_group_schedule(p_tournament_id UUID) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_group_count INT;
  v_total INT;
  v_drawn INT;
  v_rec RECORD;
  v_arr UUID[];
  v_n INT;
  v_rounds INT;
  v_round INT;
  v_home UUID;
  v_away UUID;
  v_i INT;
  v_match_order INT := 0;
BEGIN
  SELECT group_count INTO v_group_count FROM tournaments WHERE id = p_tournament_id;
  IF v_group_count IS NULL THEN RAISE EXCEPTION '锦标赛不存在'; END IF;

  SELECT count(*) INTO v_total FROM tournament_teams WHERE tournament_id = p_tournament_id;
  SELECT count(*) INTO v_drawn FROM tournament_teams
    WHERE tournament_id = p_tournament_id AND group_name IS NOT NULL;
  IF v_drawn < v_total THEN RAISE EXCEPTION '尚有球队未完成抽签（%/%）', v_drawn, v_total; END IF;
  IF EXISTS (SELECT 1 FROM tournament_matches WHERE tournament_id = p_tournament_id AND stage = 'group') THEN
    RAISE EXCEPTION '小组赛程已生成';
  END IF;

  -- 每组单循环（圆桌法）
  FOR v_rec IN
    SELECT group_name, array_agg(team_id ORDER BY draw_order) AS ids
    FROM tournament_teams
    WHERE tournament_id = p_tournament_id AND group_name IS NOT NULL
    GROUP BY group_name ORDER BY group_name
  LOOP
    v_arr := v_rec.ids;
    v_n := array_length(v_arr, 1);
    IF v_n < 2 THEN CONTINUE; END IF;
    IF v_n % 2 = 1 THEN
      v_arr := v_arr || ARRAY[NULL::UUID];
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
      v_arr := ARRAY[v_arr[1]] || ARRAY[v_arr[v_n]] || v_arr[2 : v_n - 1];
    END LOOP;
  END LOOP;

  UPDATE tournaments SET status = 'group_stage' WHERE id = p_tournament_id;

  PERFORM add_tournament_announcement(p_tournament_id, 'schedule',
    CASE WHEN v_group_count = 1 THEN '📅 抽签全部完成！单循环赛程已生成，共 '
         ELSE '📅 抽签全部完成！' || v_group_count || ' 个小组单循环赛程已生成，共 ' END ||
    (SELECT count(*) FROM tournament_matches WHERE tournament_id = p_tournament_id) || ' 场比赛，祝各队好运！');

  RETURN jsonb_build_object('success', true, 'match_count', v_match_order);
END;
$$;

-- ══ 5. 逐队抽签（队伍代表自行抽，抽中 组+号位）══════════
CREATE OR REPLACE FUNCTION draw_lottery(
  p_tournament_id UUID,
  p_team_id       UUID,
  p_drawer_name   VARCHAR(100) DEFAULT NULL   -- 抽签人姓名（播报用，如"队长张三"）
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_group_count INT;
  v_total INT;
  v_drawn INT;
  v_capacity INT;
  v_team_name TEXT;
  v_group VARCHAR(4);
  v_slot_no INT;
  v_full_groups TEXT[];
BEGIN
  SELECT name, group_count INTO v_team_name, v_group_count
  FROM tournaments WHERE id = p_tournament_id;
  IF v_team_name IS NULL THEN RAISE EXCEPTION '锦标赛不存在'; END IF;

  SELECT count(*) INTO v_total FROM tournament_teams WHERE tournament_id = p_tournament_id;
  SELECT count(*) INTO v_drawn FROM tournament_teams
    WHERE tournament_id = p_tournament_id AND group_name IS NOT NULL;
  IF v_drawn >= v_total THEN RAISE EXCEPTION '全部球队已完成抽签'; END IF;
  IF EXISTS (SELECT 1 FROM tournament_matches WHERE tournament_id = p_tournament_id AND stage = 'group') THEN
    RAISE EXCEPTION '赛程已生成，无法抽签';
  END IF;

  -- 该队是否已抽
  IF EXISTS (SELECT 1 FROM tournament_teams
             WHERE tournament_id = p_tournament_id AND team_id = p_team_id AND group_name IS NOT NULL) THEN
    RAISE EXCEPTION '该球队已完成抽签';
  END IF;

  -- 每组容量 = ceil(总数/组数)，从未满的组里随机抽一个
  v_capacity := CEIL(v_total::numeric / v_group_count)::INT;
  SELECT array_agg(group_name) INTO v_full_groups
  FROM (
    SELECT group_name, count(*) AS cnt
    FROM tournament_teams
    WHERE tournament_id = p_tournament_id AND group_name IS NOT NULL
    GROUP BY group_name
    HAVING count(*) >= v_capacity
  ) x;
  IF v_full_groups IS NULL OR array_length(v_full_groups, 1) = 0 THEN
    v_full_groups := ARRAY['__none__'];
  END IF;

  SELECT g.name INTO v_group
  FROM unnest((ARRAY['A','B','C','D'])[1:LEAST(v_group_count, 4)]) AS g(name)
  WHERE g.name <> ALL(v_full_groups)
  ORDER BY random()
  LIMIT 1;
  IF v_group IS NULL THEN v_group := 'A'; END IF;

  -- 组内号位 = 该组已有数量 + 1
  SELECT count(*) + 1 INTO v_slot_no
  FROM tournament_teams
  WHERE tournament_id = p_tournament_id AND group_name = v_group;

  UPDATE tournament_teams
  SET group_name = v_group,
      draw_order = v_drawn + 1,
      drawn_at = NOW()
  WHERE tournament_id = p_tournament_id AND team_id = p_team_id;

  -- 公告播报
  PERFORM add_tournament_announcement(p_tournament_id, 'draw',
    COALESCE('🎉 ' || NULLIF(p_drawer_name, '') || ' 代表 ', '🎉 ') || v_team_name || ' 抽签：' ||
    CASE WHEN v_group_count = 1 THEN '抽中 ' || v_slot_no || ' 号签位！'
         ELSE '抽中 ' || v_group || ' 组 ' || v_slot_no || ' 号位！' END);

  -- 全部抽完 → 自动生成赛程
  IF v_drawn + 1 >= v_total THEN
    PERFORM generate_group_schedule(p_tournament_id);
  END IF;

  RETURN jsonb_build_object('success', true, 'group_name', v_group, 'slot_no', v_slot_no);
END;
$$;

-- ══ 6. 管理员一键代抽（剩余未抽的球队全部随机抽完）══════
CREATE OR REPLACE FUNCTION draw_groups(p_tournament_id UUID) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_rec RECORD;
  v_last JSONB;
BEGIN
  IF EXISTS (SELECT 1 FROM tournament_matches WHERE tournament_id = p_tournament_id AND stage = 'group') THEN
    RAISE EXCEPTION '已生成小组赛程，无法重新抽签';
  END IF;

  FOR v_rec IN
    SELECT team_id FROM tournament_teams
    WHERE tournament_id = p_tournament_id AND group_name IS NULL
    ORDER BY random()
  LOOP
    v_last := draw_lottery(p_tournament_id, v_rec.team_id, NULL);
  END LOOP;

  IF v_last IS NULL THEN
    -- 没有未抽的球队：直接补生成赛程（幂等）
    PERFORM generate_group_schedule(p_tournament_id);
  END IF;

  RETURN jsonb_build_object('success', true,
    'match_count', (SELECT count(*) FROM tournament_matches WHERE tournament_id = p_tournament_id));
END;
$$;

-- ══ 7. 为赛程创建实际比赛（含播报）══════════════════════
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
    COALESCE(v_rec.venue, v_rec.t_venue), v_rec.scheduled_at
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

-- ══ 8. 比赛结果播报 + 自动同步晋级 ══════════════════════
CREATE OR REPLACE FUNCTION announce_game_result(p_game_id UUID) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_m RECORD;
  v_g RECORD;
  v_home TEXT;
  v_away TEXT;
  v_stage_label TEXT;
  v_winner TEXT;
BEGIN
  SELECT m.* INTO v_m FROM tournament_matches m WHERE m.game_id = p_game_id LIMIT 1;
  IF v_m.id IS NULL THEN RETURN; END IF;

  SELECT home_score, away_score INTO v_g FROM games WHERE id = p_game_id;
  IF v_g.home_score IS NULL THEN RETURN; END IF;

  SELECT name INTO v_home FROM teams WHERE id = v_m.home_team_id;
  SELECT name INTO v_away FROM teams WHERE id = v_m.away_team_id;

  v_stage_label := CASE v_m.stage
    WHEN 'group' THEN COALESCE(v_m.group_name, '') || '组小组赛'
    WHEN 'quarterfinal' THEN '四分之一决赛'
    WHEN 'semifinal' THEN '半决赛'
    WHEN 'third_place' THEN '季军赛'
    WHEN 'final' THEN '决赛'
    ELSE v_m.stage
  END;

  v_winner := CASE
    WHEN v_g.home_score > v_g.away_score THEN v_home
    WHEN v_g.away_score > v_g.home_score THEN v_away
  END;

  PERFORM add_tournament_announcement(v_m.tournament_id, 'result',
    '🏁 第' || v_m.match_order || '场 ' || v_stage_label || '结束：' ||
    v_home || ' ' || v_g.home_score || ' : ' || v_g.away_score || ' ' || v_away ||
    COALESCE('，' || v_winner || ' 获胜！', ''));

  IF v_m.stage IN ('quarterfinal','semifinal','final','third_place') THEN
    PERFORM sync_playoff_teams(v_m.tournament_id);
  END IF;
END;
$$;

-- ══ 9. 同步淘汰赛对阵（含晋级播报）══════════════════════
CREATE OR REPLACE FUNCTION sync_playoff_teams(p_tournament_id UUID) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_rec RECORD;
  v_winner UUID;
  v_winner_name TEXT;
  v_target_label TEXT;
  v_take_loser BOOLEAN;
  v_filled INT := 0;
  v_pending INT;
BEGIN
  FOR v_rec IN
    SELECT m.id, m.stage, m.home_team_id, m.away_team_id, m.home_from, m.away_from, m.match_order
    FROM tournament_matches m
    WHERE m.tournament_id = p_tournament_id
      AND m.stage IN ('quarterfinal','semifinal','final','third_place')
      AND (m.home_team_id IS NULL OR m.away_team_id IS NULL)
      AND (m.home_from IS NOT NULL OR m.away_from IS NOT NULL)
  LOOP
    v_take_loser := (v_rec.stage = 'third_place');
    v_target_label := CASE v_rec.stage
      WHEN 'quarterfinal' THEN '四分之一决赛'
      WHEN 'semifinal' THEN '半决赛'
      WHEN 'final' THEN '决赛！'
      WHEN 'third_place' THEN '季军赛'
    END;

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
        SELECT name INTO v_winner_name FROM teams WHERE id = v_winner;
        PERFORM add_tournament_announcement(p_tournament_id, 'playoff',
          '🔥 ' || v_winner_name ||
          CASE WHEN v_rec.stage = 'third_place' THEN ' 进入季军赛，向铜牌发起冲击！'
               WHEN v_rec.stage = 'final' THEN ' 挺进决赛！🏆'
               ELSE ' 晋级' || v_target_label || '！' END);
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
        SELECT name INTO v_winner_name FROM teams WHERE id = v_winner;
        PERFORM add_tournament_announcement(p_tournament_id, 'playoff',
          '🔥 ' || v_winner_name ||
          CASE WHEN v_rec.stage = 'third_place' THEN ' 进入季军赛，向铜牌发起冲击！'
               WHEN v_rec.stage = 'final' THEN ' 挺进决赛！🏆'
               ELSE ' 晋级' || v_target_label || '！' END);
        v_filled := v_filled + 1;
      END IF;
    END IF;
  END LOOP;

  SELECT count(*) INTO v_pending
  FROM tournament_matches m LEFT JOIN games g ON g.id = m.game_id
  WHERE m.tournament_id = p_tournament_id
    AND m.stage <> 'group'
    AND (m.game_id IS NULL OR g.status <> 'finished');
  IF v_pending = 0 AND EXISTS (
    SELECT 1 FROM tournament_matches WHERE tournament_id = p_tournament_id AND stage <> 'group'
  ) THEN
    UPDATE tournaments SET status = 'finished' WHERE id = p_tournament_id;
    -- 冠军播报
    DECLARE
      v_f RECORD;
      v_champ TEXT;
    BEGIN
      SELECT g.home_score, g.away_score, m.home_team_id, m.away_team_id
      INTO v_f
      FROM tournament_matches m JOIN games g ON g.id = m.game_id
      WHERE m.tournament_id = p_tournament_id AND m.stage = 'final' AND g.status = 'finished';
      IF v_f.home_team_id IS NOT NULL THEN
        SELECT name INTO v_champ FROM teams
        WHERE id = CASE WHEN v_f.home_score > v_f.away_score THEN v_f.home_team_id ELSE v_f.away_team_id END;
        PERFORM add_tournament_announcement(p_tournament_id, 'info',
          '🏆 本届锦标赛圆满落幕！冠军：' || v_champ || '！感谢所有队伍的精彩表现！');
      END IF;
    END;
  END IF;

  RETURN jsonb_build_object('success', true, 'filled', v_filled);
END;
$$;

-- ══ 10. update_game_status（完整版：时钟 + finished_at 兜底 + 赛果播报）═══
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

    -- 锦标赛比赛结束 → 播报赛果 + 自动同步晋级
    IF p_status = 'finished' THEN
      PERFORM announce_game_result(p_game_id);
    END IF;
  END IF;
END;
$$;

-- ══ 11. end_quarter（自动结束同样播报）═══════════════════
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
    PERFORM announce_game_result(p_game_id);
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

-- ══ 12. create_playoffs（生成时播报）═════════════════════
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

  SELECT COALESCE(MAX(match_order), 0) INTO v_match_order
  FROM tournament_matches WHERE tournament_id = p_tournament_id;

  IF v_t.group_count = 1 THEN
    FOR v_i IN 1..v_size LOOP
      SELECT team_id INTO v_rank FROM v_tournament_standings
        WHERE tournament_id = p_tournament_id
        ORDER BY points DESC, diff DESC, pts_for DESC
        LIMIT 1 OFFSET (v_i - 1);
      IF v_rank IS NULL THEN RAISE EXCEPTION '积分榜名次不足，无法确定全部出线队伍'; END IF;
      v_seeds := v_seeds || v_rank;
    END LOOP;
    IF v_size = 4 THEN
      v_seeds := ARRAY[v_seeds[1], v_seeds[4], v_seeds[2], v_seeds[3]];
    END IF;
  ELSE
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

  v_cur_ids := '{}';
  FOR v_i IN 1..(v_size / 2) LOOP
    v_match_order := v_match_order + 1;
    INSERT INTO tournament_matches (tournament_id, stage, round, home_team_id, away_team_id, match_order)
    VALUES (p_tournament_id, v_stage_first, 1, v_seeds[v_i * 2 - 1], v_seeds[v_i * 2], v_match_order)
    RETURNING id INTO v_m;
    v_cur_ids := v_cur_ids || v_m;
  END LOOP;

  v_stage := v_stage_first;
  WHILE array_length(v_cur_ids, 1) > 1 LOOP
    v_next_stage := CASE v_stage WHEN 'quarterfinal' THEN 'semifinal'
                                 WHEN 'semifinal' THEN 'final' END;
    v_next_ids := '{}';
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

  PERFORM add_tournament_announcement(p_tournament_id, 'schedule',
    '⚔️ 淘汰赛对阵已生成！小组赛积分榜前 ' || v_size || ' 名捉对厮杀，向冠军发起最后冲刺！');

  RETURN jsonb_build_object('success', true);
END;
$$;

-- ══ 13. 授权 ════════════════════════════════════════════
GRANT EXECUTE ON FUNCTION add_tournament_announcement TO anon, authenticated;
GRANT EXECUTE ON FUNCTION generate_group_schedule TO anon, authenticated;
GRANT EXECUTE ON FUNCTION draw_lottery TO anon, authenticated;
GRANT EXECUTE ON FUNCTION draw_groups TO anon, authenticated;
GRANT EXECUTE ON FUNCTION create_match_game TO anon, authenticated;
GRANT EXECUTE ON FUNCTION announce_game_result TO anon, authenticated;
GRANT EXECUTE ON FUNCTION sync_playoff_teams TO anon, authenticated;
GRANT EXECUTE ON FUNCTION update_game_status(UUID, VARCHAR(20), TIMESTAMPTZ, TIMESTAMPTZ, BOOLEAN, INTEGER) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION end_quarter(UUID, SMALLINT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION create_playoffs TO anon, authenticated;

-- 验证
SELECT proname, pg_get_function_identity_arguments(oid) AS args
FROM pg_proc
WHERE pronamespace = 'public'::regnamespace
  AND proname IN ('draw_lottery','draw_groups','generate_group_schedule','create_match_game',
                  'announce_game_result','sync_playoff_teams','update_game_status','end_quarter','create_playoffs');
