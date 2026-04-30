-- 删除带 jersey_no 的旧版 add_player (OID: 17881)
DROP FUNCTION IF EXISTS add_player(p_name text, p_jersey_no smallint, p_position character varying, p_height smallint, p_weight smallint, p_phone character varying, p_skills text, p_notes text);

-- 确认只剩一个
SELECT 
  proname as function_name,
  pg_get_function_arguments(oid) as arguments
FROM pg_proc 
WHERE proname = 'add_player';
