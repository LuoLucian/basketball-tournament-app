-- 删除旧版 update_game_status（4参数），只保留新版（5参数含 is_paused）
DROP FUNCTION IF EXISTS public.update_game_status(UUID, VARCHAR(20), TIMESTAMPTZ, TIMESTAMPTZ);

-- 验证只剩新版
SELECT proname, pg_get_function_identity_arguments(oid) as args
FROM pg_proc
WHERE proname = 'update_game_status' AND pronamespace = 'public'::regnamespace;
