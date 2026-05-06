-- ============================================================
-- 修复 team_players 表缺少 updated_at 字段的问题
-- 在 Supabase SQL Editor 中执行
-- ============================================================

-- 1. 添加 updated_at 字段（如不存在）
ALTER TABLE team_players ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 2. 为已有数据补充 updated_at（设为 joined_at 或当前时间）
UPDATE team_players
   SET updated_at = COALESCE(joined_at, NOW())
 WHERE updated_at IS NULL;

-- 3. 确保 update_team_player_position RPC 正确（覆盖）
CREATE OR REPLACE FUNCTION update_team_player_position(
  p_team_id    UUID,
  p_player_id  UUID,
  p_position   VARCHAR(20)
) RETURNS JSONB AS $$
BEGIN
  IF p_team_id IS NULL OR p_player_id IS NULL THEN
    RAISE EXCEPTION '参数不能为空';
  END IF;

  UPDATE team_players
  SET position   = p_position,
      updated_at = NOW()
  WHERE team_id = p_team_id
    AND player_id = p_player_id
    AND is_active = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION '未找到该球员（可能已离队）';
  END IF;

  RETURN jsonb_build_object('success', true, 'position', p_position);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 4. 验证
SELECT 'updated_at 字段已确保存在，RPC 已更新' AS status;
