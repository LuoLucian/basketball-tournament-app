-- ============================================================
-- 创建 RPC 函数：供超管在前端创建新用户
-- 在 Supabase SQL Editor 中执行
-- ============================================================

-- 创建用户 RPC 函数
-- 调用方必须是 super_admin 角色
CREATE OR REPLACE FUNCTION create_user(
  p_email TEXT,
  p_password TEXT,
  p_display_name TEXT,
  p_role TEXT DEFAULT 'user'
) RETURNS JSONB AS $$
DECLARE
  v_instance_id UUID;
  v_user_id UUID;
  v_username TEXT;
  v_result JSONB;
BEGIN
  -- 权限检查：只有超管才能创建用户
  IF get_my_role() != 'super_admin' THEN
    RAISE EXCEPTION '权限不足：只有超级管理员才能创建用户';
  END IF;

  -- 参数校验
  IF p_email IS NULL OR p_email = '' THEN
    RAISE EXCEPTION '邮箱不能为空';
  END IF;
  IF p_password IS NULL OR p_password = '' THEN
    RAISE EXCEPTION '密码不能为空';
  END IF;
  IF p_display_name IS NULL OR p_display_name = '' THEN
    RAISE EXCEPTION '姓名不能为空';
  END IF;
  IF p_role NOT IN ('super_admin', 'admin', 'recorder', 'user') THEN
    RAISE EXCEPTION '无效的用户角色: %', p_role;
  END IF;

  -- 检查邮箱是否已存在
  IF EXISTS (SELECT 1 FROM auth.users WHERE email = p_email) THEN
    RAISE EXCEPTION '该邮箱已被注册: %', p_email;
  END IF;

  -- 获取 instance_id
  SELECT id INTO v_instance_id FROM auth.instances LIMIT 1;

  -- 创建 Auth 用户
  INSERT INTO auth.users (
    instance_id,
    id,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_user_meta_data,
    created_at,
    updated_at,
    aud,
    role,
    raw_app_meta_data
  ) VALUES (
    v_instance_id,
    gen_random_uuid(),
    p_email,
    crypt(p_password, gen_salt('bf')),
    NOW(),
    jsonb_build_object('display_name', p_display_name),
    NOW(),
    NOW(),
    'authenticated',
    'authenticated',
    '{"provider": "email", "providers": ["email"]}'
  ) RETURNING id INTO v_user_id;

  -- 创建 profile
  v_username := split_part(p_email, '@', 1) || '_' || substr(md5(random()::text), 1, 6);
  INSERT INTO profiles (id, username, display_name, role, is_active)
  VALUES (v_user_id, v_username, p_display_name, p_role, TRUE);

  -- 返回结果
  v_result := jsonb_build_object(
    'success', true,
    'user_id', v_user_id,
    'username', v_username,
    'email', p_email,
    'display_name', p_display_name,
    'role', p_role
  );

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 重置用户密码 RPC 函数
CREATE OR REPLACE FUNCTION reset_user_password(
  p_user_id UUID,
  p_new_password TEXT
) RETURNS JSONB AS $$
BEGIN
  IF get_my_role() != 'super_admin' THEN
    RAISE EXCEPTION '权限不足';
  END IF;
  IF p_new_password IS NULL OR length(p_new_password) < 6 THEN
    RAISE EXCEPTION '密码长度不能少于6位';
  END IF;

  UPDATE auth.users
  SET encrypted_password = crypt(p_new_password, gen_salt('bf')),
      updated_at = NOW()
  WHERE id = p_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION '用户不存在';
  END IF;

  RETURN jsonb_build_object('success', true, 'user_id', p_user_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 删除用户 RPC 函数
CREATE OR REPLACE FUNCTION delete_user(
  p_user_id UUID
) RETURNS JSONB AS $$
BEGIN
  IF get_my_role() != 'super_admin' THEN
    RAISE EXCEPTION '权限不足';
  END IF;
  -- 不允许删除自己
  IF p_user_id = auth.uid() THEN
    RAISE EXCEPTION '不能删除自己的账号';
  END IF;

  DELETE FROM profiles WHERE id = p_user_id;
  DELETE FROM auth.users WHERE id = p_user_id;

  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 执行完成！
-- ============================================================
SELECT 'RPC 函数创建完成！' AS status;
