-- ============================================================
-- 修复 add_player 函数重载冲突
-- 删除旧版本，创建统一的新版本
-- ============================================================

-- 1. 删除所有旧版本的 add_player 函数（包括带 jersey_no/phone 的）
DROP FUNCTION IF EXISTS add_player(TEXT, VARCHAR, SMALLINT, SMALLINT, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS add_player(TEXT, VARCHAR, SMALLINT, SMALLINT, VARCHAR, TEXT, TEXT);
DROP FUNCTION IF EXISTS add_player(TEXT, VARCHAR, SMALLINT, SMALLINT, VARCHAR, VARCHAR, TEXT, TEXT);

-- 2. 创建统一的 add_player 函数（支持 avatar_url，去掉 jersey_no 和 phone）
CREATE OR REPLACE FUNCTION add_player(
  p_name TEXT,
  p_position VARCHAR(100) DEFAULT NULL,   -- 逗号分隔多位置
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

-- 3. 确认函数已更新
SELECT 
  proname as function_name,
  pg_get_function_arguments(oid) as arguments
FROM pg_proc 
WHERE proname = 'add_player';
