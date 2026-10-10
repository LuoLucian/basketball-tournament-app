-- ═══════════════════════════════════════════════════════════════
-- 注册系统完整诊断和修复
-- ═══════════════════════════════════════════════════════════════

-- 1. 检查 auth_credentials 表是否存在
SELECT '检查 auth_credentials 表...' as step;
SELECT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'auth_credentials'
) as auth_credentials_exists;

-- 2. 如果不存在则创建
CREATE TABLE IF NOT EXISTS public.auth_credentials (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    username text UNIQUE NOT NULL,
    password_hash text NOT NULL,
    user_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);

-- 3. 检查 profiles 表的外键约束
SELECT '检查 profiles 外键约束...' as step;
SELECT 
    tc.constraint_name,
    kcu.column_name,
    ccu.table_name AS foreign_table
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_name = 'profiles';

-- 4. 删除 profiles.id 的外键约束（如果存在）
DO $$
DECLARE
    fk_record RECORD;
BEGIN
    FOR fk_record IN 
        SELECT tc.constraint_name
        FROM information_schema.table_constraints AS tc
        JOIN information_schema.key_column_usage AS kcu
            ON tc.constraint_name = kcu.constraint_name
        WHERE tc.constraint_type = 'FOREIGN KEY'
            AND tc.table_name = 'profiles'
            AND kcu.column_name = 'id'
    LOOP
        EXECUTE format('ALTER TABLE public.profiles DROP CONSTRAINT %I', fk_record.constraint_name);
        RAISE NOTICE '已删除外键约束: %', fk_record.constraint_name;
    END LOOP;
END $$;

-- 5. 创建或替换 register_user 函数
CREATE OR REPLACE FUNCTION public.register_user(
  p_username text,
  p_password text,
  p_display_name text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid;
  v_display_name text;
BEGIN
  -- 参数校验
  IF p_username IS NULL OR trim(p_username) = '' THEN
    RAISE EXCEPTION '用户名不能为空';
  END IF;
  IF length(trim(p_username)) < 3 THEN
    RAISE EXCEPTION '用户名长度至少3位';
  END IF;
  IF p_password IS NULL OR p_password = '' THEN
    RAISE EXCEPTION '密码不能为空';
  END IF;
  IF length(p_password) < 6 THEN
    RAISE EXCEPTION '密码长度至少6位';
  END IF;

  v_display_name := COALESCE(NULLIF(trim(p_display_name), ''), trim(p_username));

  -- 检查用户名是否已存在
  IF EXISTS (SELECT 1 FROM public.profiles WHERE lower(username) = lower(trim(p_username))) THEN
    RAISE EXCEPTION '用户名已存在';
  END IF;

  -- 生成用户ID
  v_user_id := gen_random_uuid();

  -- 插入 profiles 表
  INSERT INTO public.profiles (id, username, display_name, role, is_active)
  VALUES (v_user_id, trim(p_username), v_display_name, 'user', true);

  -- 插入 auth_credentials 表
  INSERT INTO public.auth_credentials (username, password_hash, user_id)
  VALUES (trim(p_username), crypt(p_password, gen_salt('bf')), v_user_id);

  -- 返回用户信息
  RETURN jsonb_build_object(
    'id', v_user_id,
    'username', trim(p_username),
    'display_name', v_display_name,
    'role', 'user'
  );
END;
$$;

-- 6. 授予执行权限
GRANT EXECUTE ON FUNCTION public.register_user TO anon, authenticated;

-- 7. 验证函数创建成功
SELECT 'register_user 函数已创建' as status, 
       routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'public' AND routine_name = 'register_user';

SELECT '注册系统修复完成！' as result;
