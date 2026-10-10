-- 检查现有的认证相关 RPC 函数
SELECT 
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
    AND routine_name IN ('login_by_username', 'create_user', 'register_user', 'change_my_password', 'reset_user_password')
ORDER BY routine_name;

-- 检查 auth_credentials 表是否存在
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
    AND table_name = 'auth_credentials';

-- 检查 profiles 表结构
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'profiles'
ORDER BY ordinal_position;
