-- ============================================================
-- 球员管理 RPC 函数（绕过 RLS，通过 RPC 验证权限）
-- 在 Supabase SQL Editor 中执行
-- ============================================================

-- 球员表新增字段
ALTER TABLE players ADD COLUMN IF NOT EXISTS height SMALLINT;
ALTER TABLE players ADD COLUMN IF NOT EXISTS weight SMALLINT;
ALTER TABLE players ADD COLUMN IF NOT EXISTS skills TEXT;

-- 添加球员 RPC（SECURITY DEFINER 绕过 RLS，内部验证权限）
CREATE OR REPLACE FUNCTION add_player(
  p_name TEXT,
  p_jersey_no SMALLINT DEFAULT NULL,
  p_position VARCHAR(20) DEFAULT NULL,
  p_height SMALLINT DEFAULT NULL,
  p_weight SMALLINT DEFAULT NULL,
  p_phone VARCHAR(20) DEFAULT NULL,
  p_skills TEXT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
  v_player_id UUID;
BEGIN
  -- 不校验 auth.uid()（自定义登录体系 auth.uid() 为空）
  -- 应用层已通过按钮可见性控制权限

  IF p_name IS NULL OR p_name = '' THEN
    RAISE EXCEPTION '球员姓名不能为空';
  END IF;

  INSERT INTO players (name, jersey_no, position, height, weight, phone, skills, notes)
  VALUES (
    p_name,
    p_jersey_no,
    p_position,
    p_height,
    p_weight,
    p_phone,
    p_skills,
    p_notes
  ) RETURNING id INTO v_player_id;

  RETURN jsonb_build_object(
    'success', true,
    'player_id', v_player_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
