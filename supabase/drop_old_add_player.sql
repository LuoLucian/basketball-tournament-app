-- ============================================================
-- 精确删除带 jersey_no 的旧版 add_player
-- ============================================================

-- 删除带 jersey_no 参数的旧版本（参数顺序：name, jersey_no, position...）
DROP FUNCTION IF EXISTS add_player(p_name TEXT, p_jersey_no SMALLINT, p_position VARCHAR, p_height SMALLINT, p_weight SMALLINT, p_phone VARCHAR, p_skills TEXT, p_notes TEXT);

-- 如果上面的不匹配，尝试另一种可能的参数组合
DROP FUNCTION IF EXISTS add_player(TEXT, SMALLINT, VARCHAR, SMALLINT, SMALLINT, VARCHAR, TEXT, TEXT);

-- 再尝试只有 jersey_no 没有 phone 的版本
DROP FUNCTION IF EXISTS add_player(TEXT, VARCHAR, SMALLINT, SMALLINT, VARCHAR, TEXT, TEXT);

-- 列出剩余函数确认
SELECT 
  proname as function_name,
  pg_get_function_arguments(oid) as arguments
FROM pg_proc 
WHERE proname = 'add_player';
