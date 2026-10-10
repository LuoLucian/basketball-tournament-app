-- 注册用户 RPC（普通用户自助注册）
-- 使用自定义 auth_credentials 表存储密码（与 login_by_username 保持一致）
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
  v_result jsonb;
BEGIN
  -- 参数校验
  IF p_username IS NULL OR trim(p_username) = '' THEN
    RAISE EXCEPTION '用户名不能为空';
  END IF;
  IF p_password IS NULL OR p_password = '' THEN
    RAISE EXCEPTION '密码不能为空';
  END IF;
  IF length(p_password) < 6 THEN
    RAISE EXCEPTION '密码长度至少6位';
  END IF;
  IF length(p_username) < 3 THEN
    RAISE EXCEPTION '用户名长度至少3位';
  END IF;

  v_display_name := COALESCE(p_display_name, p_username);

  -- 检查用户名是否已存在
  IF EXISTS (SELECT 1 FROM public.profiles WHERE username = p_username) THEN
    RAISE EXCEPTION '用户名已存在';
  END IF;

  -- 生成 UUID
  v_user_id := gen_random_uuid();

  -- 先插入 profiles 表（id 是自生成的，不依赖 auth.users）
  INSERT INTO public.profiles (id, username, display_name, role, is_active)
  VALUES (v_user_id, p_username, v_display_name, 'user', true);

  -- 插入 auth_credentials 表（与 create_user 保持一致）
  INSERT INTO public.auth_credentials (username, password_hash, user_id)
  VALUES (p_username, crypt(p_password, gen_salt('bf')), v_user_id);

  -- 返回用户信息
  v_result := jsonb_build_object(
    'id', v_user_id,
    'username', p_username,
    'display_name', v_display_name,
    'role', 'user'
  );

  RETURN v_result;
END;
$$;
