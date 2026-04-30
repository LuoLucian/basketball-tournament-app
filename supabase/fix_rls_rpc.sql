-- ============================================================
-- 修复写操作 RLS 权限 + 球员字段调整
-- 在 Supabase SQL Editor 中一次性执行
-- ============================================================

-- ── 1. 球员表字段调整 ──
-- 新增字段
ALTER TABLE players ADD COLUMN IF NOT EXISTS height SMALLINT;
ALTER TABLE players ADD COLUMN IF NOT EXISTS weight SMALLINT;
ALTER TABLE players ADD COLUMN IF NOT EXISTS skills TEXT;

-- 位置字段去掉 CHECK 约束（允许多个位置逗号分隔存储）
ALTER TABLE players DROP CONSTRAINT IF EXISTS players_position_check;
-- 扩大字段长度以容纳逗号分隔的多个位置
ALTER TABLE players ALTER COLUMN position TYPE VARCHAR(100);

-- ── 2. 创建球员头像存储桶 ──
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('avatars', 'avatars', true, 2097152,
  ARRAY['image/jpeg','image/png','image/gif','image/webp'])
ON CONFLICT (id) DO NOTHING;

-- 头像桶公开读取策略
CREATE POLICY "avatars_public_read" ON storage.objects
  FOR SELECT TO anon USING (bucket_id = 'avatars');

-- 头像桶写入策略（通过 RPC 间接写入，这里给 authenticated 写权限）
CREATE POLICY "avatars_auth_insert" ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'avatars');

CREATE POLICY "avatars_auth_update" ON storage.objects
  FOR UPDATE TO authenticated USING (bucket_id = 'avatars');

CREATE POLICY "avatars_auth_delete" ON storage.objects
  FOR DELETE TO authenticated USING (bucket_id = 'avatars');

-- ── 3. 添加球员 RPC（去掉手机号和球衣号，位置支持多选） ──
CREATE OR REPLACE FUNCTION add_player(
  p_name TEXT,
  p_position VARCHAR(100) DEFAULT NULL,   -- 逗号分隔多位置，如 'PG,SG'
  p_height SMALLINT DEFAULT NULL,
  p_weight SMALLINT DEFAULT NULL,
  p_skills TEXT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL,
  p_avatar_url TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
  v_player_id UUID;
BEGIN
  IF p_name IS NULL OR p_name = '' THEN
    RAISE EXCEPTION '球员姓名不能为空';
  END IF;
  INSERT INTO players (name, position, height, weight, skills, notes, avatar_url)
  VALUES (p_name, p_position, p_height, p_weight, p_skills, p_notes, p_avatar_url)
  RETURNING id INTO v_player_id;
  RETURN jsonb_build_object('success', true, 'player_id', v_player_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── 4. 更新球员头像 URL RPC（SECURITY DEFINER 绕过 RLS） ──
CREATE OR REPLACE FUNCTION update_player_avatar(
  p_player_id UUID,
  p_avatar_url TEXT
) RETURNS JSONB AS $$
BEGIN
  IF p_player_id IS NULL THEN
    RAISE EXCEPTION '球员ID不能为空';
  END IF;
  UPDATE players SET avatar_url = p_avatar_url WHERE id = p_player_id;
  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── 5. 更新球员信息 RPC ──
CREATE OR REPLACE FUNCTION update_player(
  p_player_id UUID,
  p_name TEXT DEFAULT NULL,
  p_position VARCHAR(100) DEFAULT NULL,
  p_height SMALLINT DEFAULT NULL,
  p_weight SMALLINT DEFAULT NULL,
  p_skills TEXT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
) RETURNS JSONB AS $$
BEGIN
  IF p_player_id IS NULL THEN
    RAISE EXCEPTION '球员ID不能为空';
  END IF;
  UPDATE players SET
    name        = COALESCE(p_name, name),
    position    = p_position,
    height      = COALESCE(p_height, height),
    weight      = COALESCE(p_weight, weight),
    skills      = p_skills,
    notes       = p_notes,
    updated_at  = NOW()
  WHERE id = p_player_id;
  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── 6. 删除球员（软删除）RPC ──
CREATE OR REPLACE FUNCTION delete_player(
  p_player_id UUID
) RETURNS JSONB AS $$
BEGIN
  IF p_player_id IS NULL THEN
    RAISE EXCEPTION '球员ID不能为空';
  END IF;
  UPDATE players SET is_active = false, updated_at = NOW() WHERE id = p_player_id;
  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── 7. 删除旧头像文件 RPC ──
CREATE OR REPLACE FUNCTION delete_avatar(
  p_path TEXT
) RETURNS JSONB AS $$
BEGIN
  IF p_path IS NOT NULL AND p_path != '' THEN
    DELETE FROM storage.objects WHERE bucket_id = 'avatars' AND name = p_path;
  END IF;
  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── 5. 创建球队 RPC ──
CREATE OR REPLACE FUNCTION add_team(
  p_name TEXT,
  p_short_name VARCHAR(20) DEFAULT NULL,
  p_color VARCHAR(7) DEFAULT '#1565c0'
) RETURNS JSONB AS $$
DECLARE
  v_team_id UUID;
BEGIN
  IF p_name IS NULL OR p_name = '' THEN
    RAISE EXCEPTION '球队名称不能为空';
  END IF;
  INSERT INTO teams (name, short_name, color)
  VALUES (p_name, p_short_name, p_color)
  RETURNING id INTO v_team_id;
  RETURN jsonb_build_object('success', true, 'team_id', v_team_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── 6. 创建赛事 RPC ──
CREATE OR REPLACE FUNCTION add_game(
  p_title TEXT,
  p_game_type VARCHAR(20) DEFAULT 'entertainment',
  p_home_team_id UUID DEFAULT NULL,
  p_away_team_id UUID DEFAULT NULL,
  p_target_score SMALLINT DEFAULT NULL,
  p_quarters SMALLINT DEFAULT NULL,
  p_quarter_seconds SMALLINT DEFAULT NULL,
  p_quarter_clock SMALLINT DEFAULT NULL,
  p_venue VARCHAR(200) DEFAULT NULL,
  p_scheduled_at TIMESTAMPTZ DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
  v_game_id UUID;
BEGIN
  IF p_title IS NULL OR p_title = '' THEN
    RAISE EXCEPTION '赛事标题不能为空';
  END IF;
  IF p_game_type NOT IN ('entertainment', 'official') THEN
    RAISE EXCEPTION '无效的赛制: %', p_game_type;
  END IF;
  INSERT INTO games (title, game_type, home_team_id, away_team_id, target_score, quarters, quarter_seconds, quarter_clock, venue, scheduled_at, notes)
  VALUES (p_title, p_game_type, p_home_team_id, p_away_team_id, p_target_score, p_quarters, p_quarter_seconds, p_quarter_clock, p_venue, p_scheduled_at, p_notes)
  RETURNING id INTO v_game_id;
  RETURN jsonb_build_object('success', true, 'game_id', v_game_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── 7. 批量指派记录员 RPC ──
CREATE OR REPLACE FUNCTION assign_recorders(
  p_game_id UUID,
  p_user_ids UUID[]
) RETURNS JSONB AS $$
BEGIN
  IF p_game_id IS NULL THEN
    RAISE EXCEPTION '赛事ID不能为空';
  END IF;
  IF p_user_ids IS NULL OR array_length(p_user_ids, 1) IS NULL THEN
    RETURN jsonb_build_object('success', true, 'assigned_count', 0);
  END IF;
  INSERT INTO game_recorders (game_id, user_id)
  SELECT p_game_id, unnest(p_user_ids)
  ON CONFLICT DO NOTHING;
  RETURN jsonb_build_object('success', true, 'assigned_count', array_length(p_user_ids, 1));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 执行完成！
-- ============================================================
SELECT 'RPC 函数 + 头像存储桶创建完成！' AS status;
