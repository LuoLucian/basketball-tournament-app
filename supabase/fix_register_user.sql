-- 修复 register_user：密码存储在 profiles.password_hash 字段
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

  -- 插入 profiles 表，密码存储在 password_hash 字段
  INSERT INTO public.profiles (id, username, display_name, role, is_active, password_hash)
  VALUES (v_user_id, trim(p_username), v_display_name, 'user', true, crypt(p_password, gen_salt('bf')));

  -- 返回用户信息
  RETURN jsonb_build_object(
    'id', v_user_id,
    'username', trim(p_username),
    'display_name', v_display_name,
    'role', 'user'
  );
END;
$$;

-- 授予执行权限
GRANT EXECUTE ON FUNCTION public.register_user TO anon, authenticated;

SELECT 'register_user 已修复！密码现在存储在 profiles.password_hash' as result;
