-- ============================================================
-- 德泰科技园篮球赛事管理系统 · 数据库初始化 SQL
-- 复制此文件全部内容到 Supabase SQL Editor 执行
-- ============================================================

-- 启用 UUID 扩展
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- 1. 用户档案表 profiles（扩展 auth.users）
-- ============================================================
CREATE TABLE IF NOT EXISTS profiles (
  id           UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username     VARCHAR(50) UNIQUE NOT NULL,
  display_name VARCHAR(100),
  avatar_url   TEXT,
  role         VARCHAR(20) NOT NULL DEFAULT 'user'
               CHECK (role IN ('super_admin', 'admin', 'recorder', 'user')),
  phone        VARCHAR(20),
  jersey_no    SMALLINT,
  is_active    BOOLEAN NOT NULL DEFAULT TRUE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 2. 球员表 players
-- ============================================================
CREATE TABLE IF NOT EXISTS players (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name         VARCHAR(50) NOT NULL,
  jersey_no    SMALLINT,
  position     VARCHAR(20) CHECK (position IN ('PG','SG','SF','PF','C','FLEX')),
  avatar_url   TEXT,
  phone        VARCHAR(20),
  user_id      UUID REFERENCES profiles(id) ON DELETE SET NULL,
  is_active    BOOLEAN NOT NULL DEFAULT TRUE,
  notes        TEXT,
  created_by   UUID REFERENCES profiles(id),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 3. 球队表 teams
-- ============================================================
CREATE TABLE IF NOT EXISTS teams (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name         VARCHAR(100) NOT NULL,
  short_name   VARCHAR(20),
  logo_url     TEXT,
  color        VARCHAR(7) DEFAULT '#1565c0',
  description  TEXT,
  is_active    BOOLEAN NOT NULL DEFAULT TRUE,
  created_by   UUID REFERENCES profiles(id),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 4. 球队-球员关联表 team_players
-- ============================================================
CREATE TABLE IF NOT EXISTS team_players (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  team_id    UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  player_id  UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  jersey_no  SMALLINT,
  joined_at  DATE DEFAULT CURRENT_DATE,
  left_at    DATE,
  is_active  BOOLEAN NOT NULL DEFAULT TRUE,
  UNIQUE(team_id, player_id)
);

-- ============================================================
-- 5. 赛事表 games
-- ============================================================
CREATE TABLE IF NOT EXISTS games (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title           VARCHAR(200) NOT NULL,
  game_type       VARCHAR(20) NOT NULL DEFAULT 'entertainment'
                  CHECK (game_type IN ('entertainment', 'official')),
  home_team_id    UUID REFERENCES teams(id),
  away_team_id    UUID REFERENCES teams(id),
  home_score      SMALLINT NOT NULL DEFAULT 0,
  away_score      SMALLINT NOT NULL DEFAULT 0,
  status          VARCHAR(20) NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending','active','halftime','finished','cancelled')),
  target_score    SMALLINT DEFAULT 120,
  quarters        SMALLINT DEFAULT 4,
  quarter_seconds SMALLINT DEFAULT 600,
  current_quarter SMALLINT DEFAULT 1,
  quarter_clock   SMALLINT DEFAULT 600,
  venue           VARCHAR(200),
  scheduled_at    TIMESTAMPTZ,
  started_at      TIMESTAMPTZ,
  finished_at     TIMESTAMPTZ,
  notes           TEXT,
  created_by      UUID REFERENCES profiles(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 6. 赛事记录员关联表 game_recorders
-- ============================================================
CREATE TABLE IF NOT EXISTS game_recorders (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  game_id    UUID NOT NULL REFERENCES games(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  assigned_by UUID REFERENCES profiles(id),
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(game_id, user_id)
);

-- ============================================================
-- 7. 上场阵容表 game_lineup
-- ============================================================
CREATE TABLE IF NOT EXISTS game_lineup (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  game_id     UUID NOT NULL REFERENCES games(id) ON DELETE CASCADE,
  team_id     UUID NOT NULL REFERENCES teams(id),
  player_id   UUID NOT NULL REFERENCES players(id),
  slot_no     SMALLINT NOT NULL CHECK (slot_no BETWEEN 1 AND 5),
  quarter     SMALLINT NOT NULL DEFAULT 1,
  on_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  off_at      TIMESTAMPTZ,
  is_current  BOOLEAN NOT NULL DEFAULT TRUE
);

-- ============================================================
-- 8. 比赛数据统计表 game_stats
-- ============================================================
CREATE TABLE IF NOT EXISTS game_stats (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  game_id         UUID NOT NULL REFERENCES games(id) ON DELETE CASCADE,
  player_id       UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  team_id         UUID REFERENCES teams(id),
  game_type       VARCHAR(20) NOT NULL,
  pts             SMALLINT NOT NULL DEFAULT 0,
  fgm             SMALLINT NOT NULL DEFAULT 0,
  fga             SMALLINT NOT NULL DEFAULT 0,
  fg3m            SMALLINT NOT NULL DEFAULT 0,
  fg3a            SMALLINT NOT NULL DEFAULT 0,
  ftm             SMALLINT NOT NULL DEFAULT 0,
  fta             SMALLINT NOT NULL DEFAULT 0,
  reb             SMALLINT NOT NULL DEFAULT 0,
  oreb            SMALLINT NOT NULL DEFAULT 0,
  dreb            SMALLINT NOT NULL DEFAULT 0,
  ast             SMALLINT NOT NULL DEFAULT 0,
  stl             SMALLINT NOT NULL DEFAULT 0,
  blk             SMALLINT NOT NULL DEFAULT 0,
  tov             SMALLINT NOT NULL DEFAULT 0,
  pf              SMALLINT NOT NULL DEFAULT 0,
  min_played      SMALLINT DEFAULT 0,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(game_id, player_id)
);

-- ============================================================
-- 9. 操作日志表 action_logs
-- ============================================================
CREATE TABLE IF NOT EXISTS action_logs (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  game_id     UUID NOT NULL REFERENCES games(id) ON DELETE CASCADE,
  player_id   UUID NOT NULL REFERENCES players(id),
  team_id     UUID REFERENCES teams(id),
  action_type VARCHAR(30) NOT NULL,
  delta       SMALLINT NOT NULL DEFAULT 1,
  quarter     SMALLINT,
  game_clock  VARCHAR(10),
  recorded_by UUID NOT NULL REFERENCES profiles(id),
  is_voided   BOOLEAN NOT NULL DEFAULT FALSE,
  voided_by   UUID REFERENCES profiles(id),
  voided_at   TIMESTAMPTZ,
  notes       TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 10. MVP 评选表 game_mvp
-- ============================================================
CREATE TABLE IF NOT EXISTS game_mvp (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  game_id     UUID NOT NULL REFERENCES games(id) ON DELETE CASCADE,
  player_id   UUID NOT NULL REFERENCES players(id),
  mvp_score   NUMERIC(8,2) NOT NULL DEFAULT 0,
  is_winner   BOOLEAN NOT NULL DEFAULT FALSE,
  vote_count  SMALLINT DEFAULT 0,
  selected_by VARCHAR(20) DEFAULT 'auto'
              CHECK (selected_by IN ('auto','vote','admin')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(game_id, player_id)
);

-- ============================================================
-- 触发器：自动更新 updated_at
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_profiles_updated_at    BEFORE UPDATE ON profiles    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_players_updated_at     BEFORE UPDATE ON players     FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_teams_updated_at       BEFORE UPDATE ON teams       FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_games_updated_at       BEFORE UPDATE ON games       FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_game_stats_updated_at  BEFORE UPDATE ON game_stats  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- RLS 行级安全策略
-- ============================================================
ALTER TABLE profiles       ENABLE ROW LEVEL SECURITY;
ALTER TABLE players        ENABLE ROW LEVEL SECURITY;
ALTER TABLE teams          ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_players   ENABLE ROW LEVEL SECURITY;
ALTER TABLE games          ENABLE ROW LEVEL SECURITY;
ALTER TABLE game_recorders ENABLE ROW LEVEL SECURITY;
ALTER TABLE game_lineup    ENABLE ROW LEVEL SECURITY;
ALTER TABLE game_stats     ENABLE ROW LEVEL SECURITY;
ALTER TABLE action_logs    ENABLE ROW LEVEL SECURITY;
ALTER TABLE game_mvp       ENABLE ROW LEVEL SECURITY;

-- 辅助函数
CREATE OR REPLACE FUNCTION get_my_role()
RETURNS VARCHAR AS $$
  SELECT role FROM profiles WHERE id = auth.uid()
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION is_admin_or_above()
RETURNS BOOLEAN AS $$
  SELECT get_my_role() IN ('super_admin', 'admin')
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION is_super_admin()
RETURNS BOOLEAN AS $$
  SELECT get_my_role() = 'super_admin'
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION is_game_recorder(game_uuid UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM game_recorders
    WHERE game_id = game_uuid AND user_id = auth.uid()
  ) OR is_admin_or_above()
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

-- profiles RLS
CREATE POLICY "profiles_read_public"  ON profiles FOR SELECT TO anon USING (TRUE);
CREATE POLICY "profiles_read_all"     ON profiles FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "profiles_update_own"   ON profiles FOR UPDATE TO authenticated USING (id = auth.uid());
CREATE POLICY "profiles_admin_all"    ON profiles FOR ALL    TO authenticated USING (is_super_admin());

-- players RLS
CREATE POLICY "players_anon_read"     ON players FOR SELECT TO anon USING (TRUE);
CREATE POLICY "players_read_all"      ON players FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "players_admin_write"   ON players FOR ALL    TO authenticated USING (is_admin_or_above());

-- teams RLS
CREATE POLICY "teams_anon_read"       ON teams FOR SELECT TO anon USING (TRUE);
CREATE POLICY "teams_read_all"        ON teams FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "teams_admin_write"     ON teams FOR ALL    TO authenticated USING (is_admin_or_above());

-- team_players RLS
CREATE POLICY "team_players_anon"     ON team_players FOR SELECT TO anon USING (TRUE);
CREATE POLICY "team_players_read"     ON team_players FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "team_players_admin"    ON team_players FOR ALL    TO authenticated USING (is_admin_or_above());

-- games RLS
CREATE POLICY "games_anon_read"       ON games FOR SELECT TO anon USING (TRUE);
CREATE POLICY "games_read_all"        ON games FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "games_admin_write"     ON games FOR INSERT TO authenticated WITH CHECK (is_admin_or_above());
CREATE POLICY "games_admin_update"    ON games FOR UPDATE TO authenticated USING (is_admin_or_above());
CREATE POLICY "games_super_delete"    ON games FOR DELETE TO authenticated USING (is_super_admin());

-- game_recorders RLS
CREATE POLICY "game_recorders_anon"   ON game_recorders FOR SELECT TO anon USING (TRUE);
CREATE POLICY "game_recorders_read"   ON game_recorders FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "game_recorders_admin"  ON game_recorders FOR ALL    TO authenticated USING (is_admin_or_above());

-- game_lineup RLS
CREATE POLICY "lineup_anon_read"      ON game_lineup FOR SELECT TO anon USING (TRUE);
CREATE POLICY "lineup_read_all"       ON game_lineup FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "lineup_recorder_write" ON game_lineup FOR ALL   TO authenticated USING (is_game_recorder(game_id));

-- game_stats RLS
CREATE POLICY "stats_anon_read"       ON game_stats FOR SELECT TO anon USING (TRUE);
CREATE POLICY "stats_read_all"        ON game_stats FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "stats_recorder_write"  ON game_stats FOR ALL    TO authenticated USING (is_game_recorder(game_id));

-- action_logs RLS
CREATE POLICY "logs_anon_read"        ON action_logs FOR SELECT TO anon USING (TRUE);
CREATE POLICY "logs_read_admin"       ON action_logs FOR SELECT TO authenticated USING (is_admin_or_above() OR recorded_by = auth.uid());
CREATE POLICY "logs_recorder_insert"  ON action_logs FOR INSERT TO authenticated WITH CHECK (is_game_recorder(game_id));
CREATE POLICY "logs_void_admin"       ON action_logs FOR UPDATE TO authenticated USING (is_admin_or_above());

-- game_mvp RLS
CREATE POLICY "mvp_anon_read"         ON game_mvp FOR SELECT TO anon USING (TRUE);
CREATE POLICY "mvp_read_all"          ON game_mvp FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "mvp_admin_write"       ON game_mvp FOR ALL    TO authenticated USING (is_admin_or_above());

-- ============================================================
-- 索引优化
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_action_logs_game_id    ON action_logs (game_id);
CREATE INDEX IF NOT EXISTS idx_action_logs_player_id  ON action_logs (player_id);
CREATE INDEX IF NOT EXISTS idx_game_stats_game_id     ON game_stats (game_id);
CREATE INDEX IF NOT EXISTS idx_game_stats_player_id   ON game_stats (player_id);
CREATE INDEX IF NOT EXISTS idx_game_lineup_game_id    ON game_lineup (game_id, is_current);
CREATE INDEX IF NOT EXISTS idx_games_status           ON games (status);
CREATE INDEX IF NOT EXISTS idx_games_game_type        ON games (game_type);
CREATE INDEX IF NOT EXISTS idx_team_players_team_id   ON team_players (team_id);

-- ============================================================
-- Realtime 订阅开启
-- ============================================================
ALTER PUBLICATION supabase_realtime ADD TABLE games;
ALTER PUBLICATION supabase_realtime ADD TABLE game_lineup;
ALTER PUBLICATION supabase_realtime ADD TABLE game_stats;
ALTER PUBLICATION supabase_realtime ADD TABLE action_logs;

-- ============================================================
-- 初始化完成！
-- ============================================================
SELECT '数据库初始化完成！' AS status;
