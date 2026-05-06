-- ============================================================
-- 一次性修复：删除旧约束 + 确保所有 RPC 函数存在
-- 在 Supabase SQL Editor 中执行
-- ============================================================

-- ── 1. 删除 position 字段上的 CHECK 约束（不猜约束名，自动查找） ──
DO $$
DECLARE
  c_name TEXT;
  v_attnum SMALLINT;
BEGIN
  SELECT attnum INTO v_attnum
  FROM pg_attribute
  WHERE attrelid = 'players'::regclass AND attname = 'position';
  
  SELECT conname INTO c_name
  FROM pg_constraint
  WHERE conrelid = 'players'::regclass
    AND contype = 'c'
    AND v_attnum = ANY(conkey);
  
  IF c_name IS NOT NULL THEN
    EXECUTE format('ALTER TABLE players DROP CONSTRAINT %I', c_name);
    RAISE NOTICE '已删除约束: %', c_name;
  ELSE
    RAISE NOTICE '未找到 position 字段的 CHECK 约束（可能已删除）';
  END IF;
END $$;

-- 确保 position 字段足够长
ALTER TABLE players ALTER COLUMN position TYPE VARCHAR(100);

-- ── 2. 头像存储桶（如果不存在则创建） ──
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('avatars', 'avatars', true, 2097152,
  ARRAY['image/jpeg','image/png','image/gif','image/webp'])
ON CONFLICT (id) DO NOTHING;

-- ── 3. RPC 函数（全部 CREATE OR REPLACE，幂等安全） ──

-- 添加球员
CREATE OR REPLACE FUNCTION add_player(
  p_name TEXT,
  p_position VARCHAR(100) DEFAULT NULL,
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

-- 更新球员头像 URL
CREATE OR REPLACE FUNCTION update_player_avatar(
  p_player_id UUID,
  p_avatar_url TEXT
) RETURNS JSONB AS $$
BEGIN
  IF p_player_id IS NULL THEN
    RAISE EXCEPTION '球员ID不能为空';
  END IF;
  UPDATE players SET avatar_url = p_avatar_url, updated_at = NOW() WHERE id = p_player_id;
  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 编辑球员信息
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

-- 删除球员（软删除）
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

-- 删除头像文件
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

-- ── 4. 验证结果 ──
SELECT 'ALL DONE' AS status;
SELECT proname, pg_get_function_arguments(oid) AS args
FROM pg_proc WHERE proname IN ('add_player','update_player','update_player_avatar','delete_player','delete_avatar')
ORDER BY proname;
