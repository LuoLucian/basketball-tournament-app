-- 创建 auth_credentials 表（如果不存在）
CREATE TABLE IF NOT EXISTS public.auth_credentials (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    username text UNIQUE NOT NULL,
    password_hash text NOT NULL,
    user_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

-- 添加索引
CREATE INDEX IF NOT EXISTS idx_auth_credentials_username ON public.auth_credentials(username);
CREATE INDEX IF NOT EXISTS idx_auth_credentials_user_id ON public.auth_credentials(user_id);

-- 启用 RLS
ALTER TABLE public.auth_credentials ENABLE ROW LEVEL SECURITY;

-- 创建 RLS 策略（只允许管理员查看）
DROP POLICY IF EXISTS "Allow admin full access" ON public.auth_credentials;
CREATE POLICY "Allow admin full access"
    ON public.auth_credentials
    FOR ALL
    TO authenticated
    USING (EXISTS (
        SELECT 1 FROM public.profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role IN ('super_admin', 'admin')
    ));

-- 重新创建 register_user 函数
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

  IF EXISTS (SELECT 1 FROM public.profiles WHERE username = p_username) THEN
    RAISE EXCEPTION '用户名已存在';
  END IF;

  v_user_id := gen_random_uuid();

  INSERT INTO public.profiles (id, username, display_name, role, is_active)
  VALUES (v_user_id, p_username, v_display_name, 'user', true);

  INSERT INTO public.auth_credentials (username, password_hash, user_id)
  VALUES (p_username, crypt(p_password, gen_salt('bf')), v_user_id);

  v_result := jsonb_build_object(
    'id', v_user_id,
    'username', p_username,
    'display_name', v_display_name,
    'role', 'user'
  );

  RETURN v_result;
END;
$$;
