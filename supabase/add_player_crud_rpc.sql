-- ============================================================
-- 补充 RPC：头像写入 + 编辑球员 + 删除球员
-- 请在 Supabase SQL Editor 中执行此文件
-- ============================================================

-- ── 1. 更新球员头像 URL（上传头像后写入数据库） ──
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

-- ── 2. 编辑球员信息 ──
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

-- ── 3. 删除球员（软删除，比赛数据保留） ──
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

-- 执行确认
SELECT '新增 3 个 RPC 函数完成：update_player_avatar / update_player / delete_player' AS status;
