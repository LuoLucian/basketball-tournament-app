-- 删除 profiles 表的外键约束（让普通用户可以自助注册）
-- 先查找外键约束名称
DO $$
DECLARE
    fk_name text;
BEGIN
    SELECT tc.constraint_name INTO fk_name
    FROM information_schema.table_constraints AS tc
    JOIN information_schema.key_column_usage AS kcu
        ON tc.constraint_name = kcu.constraint_name
    WHERE tc.constraint_type = 'FOREIGN KEY'
        AND tc.table_name = 'profiles'
        AND kcu.column_name = 'id';
    
    IF fk_name IS NOT NULL THEN
        EXECUTE format('ALTER TABLE public.profiles DROP CONSTRAINT %I', fk_name);
        RAISE NOTICE '已删除外键约束: %', fk_name;
    ELSE
        RAISE NOTICE '未找到外键约束';
    END IF;
END $$;

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
