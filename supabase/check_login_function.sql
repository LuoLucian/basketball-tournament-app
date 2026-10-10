-- 查看 login_by_username 函数的定义
SELECT pg_get_functiondef(oid) 
FROM pg_proc 
WHERE proname = 'login_by_username' 
AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');
