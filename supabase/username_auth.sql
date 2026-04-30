-- ============================================================
-- 改造为用户名+密码登录系统
-- 在 Supabase SQL Editor 中执行
-- ============================================================

-- 第一步：给 profiles 表添加密码字段
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS password_hash TEXT;

-- 删除旧的邮箱相关 RPC 函数（如果存在）
DROP FUNCTION IF EXISTS create_user(TEXT, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS reset_user_password(UUID, TEXT);
DROP FUNCTION IF EXISTS delete_user(UUID);

-- 第二步：创建用户名登录 RPC
CREATE OR REPLACE FUNCTION login_by_username(
  p_username TEXT,
  p_password TEXT
) RETURNS JSONB AS $$
DECLARE
  v_profile RECORD;
BEGIN
  -- 查找用户
  SELECT * INTO v_profile
  FROM profiles
  WHERE username = p_username AND is_active = TRUE;

  IF NOT FOUND THEN
    RAISE EXCEPTION '用户名不存在';
  END IF;

  -- 验证密码（使用 pgcrypto 的 crypt 函数）
  IF v_profile.password_hash IS NULL OR v_profile.password_hash = '' THEN
    RAISE EXCEPTION '该用户未设置密码';
  END IF;

  IF v_profile.password_hash != crypt(p_password, v_profile.password_hash) THEN
    RAISE EXCEPTION '密码错误';
  END IF;

  -- 返回用户信息（不含密码）
  RETURN jsonb_build_object(
    'success', true,
    'id', v_profile.id,
    'username', v_profile.username,
    'display_name', v_profile.display_name,
    'role', v_profile.role,
    'avatar_url', v_profile.avatar_url
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 第三步：创建用户 RPC（用户名+密码模式）
CREATE OR REPLACE FUNCTION create_user(
  p_username TEXT,
  p_password TEXT,
  p_display_name TEXT,
  p_role TEXT DEFAULT 'user'
) RETURNS JSONB AS $$
DECLARE
  v_user_id UUID;
  v_instance_id UUID;
BEGIN
  -- 不再检查 auth.uid()，改为通过前端传递超管 token 验证
  -- 权限检查将在应用层处理

  -- 参数校验
  IF p_username IS NULL OR p_username = '' THEN
    RAISE EXCEPTION '用户名不能为空';
  END IF;
  IF length(p_username) < 3 THEN
    RAISE EXCEPTION '用户名至少3个字符';
  END IF;
  -- 只允许字母、数字、下划线
  IF p_username !~ '^[a-zA-Z0-9_]+$' THEN
    RAISE EXCEPTION '用户名只能包含字母、数字和下划线';
  END IF;
  IF p_password IS NULL OR p_password = '' THEN
    RAISE EXCEPTION '密码不能为空';
  END IF;
  IF length(p_password) < 6 THEN
    RAISE EXCEPTION '密码至少6位';
  END IF;
  IF p_display_name IS NULL OR p_display_name = '' THEN
    RAISE EXCEPTION '姓名不能为空';
  END IF;
  IF p_role NOT IN ('super_admin', 'admin', 'recorder', 'user') THEN
    RAISE EXCEPTION '无效的角色: %', p_role;
  END IF;

  -- 检查用户名是否已存在
  IF EXISTS (SELECT 1 FROM profiles WHERE username = p_username) THEN
    RAISE EXCEPTION '用户名已存在: %', p_username;
  END IF;

  -- 创建一个 auth.users 记录（Supabase RLS 需要 auth.uid()）
  SELECT id INTO v_instance_id FROM auth.instances LIMIT 1;

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
    raw_app_meta_data,
    confirmation_token,
    recovery_token,
    email_change_token_new
  ) VALUES (
    v_instance_id,
    gen_random_uuid(),
    p_username || '@local.internal',
    crypt('placeholder_' || gen_random_uuid()::text, gen_salt('bf')),
    NOW(),
    jsonb_build_object('display_name', p_display_name),
    NOW(),
    NOW(),
    'authenticated',
    'authenticated',
    '{"provider": "username", "providers": ["username"]}',
    '',
    '',
    ''
  ) RETURNING id INTO v_user_id;

  -- 创建 profile（含密码）
  INSERT INTO profiles (
    id, username, display_name, role, password_hash, is_active
  ) VALUES (
    v_user_id,
    p_username,
    p_display_name,
    p_role,
    crypt(p_password, gen_salt('bf')),
    TRUE
  );

  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_user_id,
    'username', p_username,
    'display_name', p_display_name,
    'role', p_role
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 第四步：重置密码 RPC
CREATE OR REPLACE FUNCTION reset_user_password(
  p_username TEXT,
  p_new_password TEXT
) RETURNS JSONB AS $$
BEGIN
  IF p_new_password IS NULL OR length(p_new_password) < 6 THEN
    RAISE EXCEPTION '密码至少6位';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE username = p_username) THEN
    RAISE EXCEPTION '用户不存在';
  END IF;

  UPDATE profiles
  SET password_hash = crypt(p_new_password, gen_salt('bf'))
  WHERE username = p_username;

  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 第五步：修改密码 RPC（用户自己改密码）
CREATE OR REPLACE FUNCTION change_my_password(
  p_old_password TEXT,
  p_new_password TEXT
) RETURNS JSONB AS $$
DECLARE
  v_hash TEXT;
BEGIN
  SELECT password_hash INTO v_hash FROM profiles WHERE id = auth.uid();

  IF v_hash IS NULL OR v_hash = '' THEN
    RAISE EXCEPTION '当前账号未设置密码';
  END IF;
  IF v_hash != crypt(p_old_password, v_hash) THEN
    RAISE EXCEPTION '原密码错误';
  END IF;
  IF length(p_new_password) < 6 THEN
    RAISE EXCEPTION '新密码至少6位';
  END IF;

  UPDATE profiles SET password_hash = crypt(p_new_password, gen_salt('bf')) WHERE id = auth.uid();

  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 第六步：删除用户 RPC
CREATE OR REPLACE FUNCTION delete_user(
  p_username TEXT
) RETURNS JSONB AS $$
DECLARE
  v_uid UUID;
BEGIN
  SELECT id INTO v_uid FROM profiles WHERE username = p_username;
  IF NOT FOUND THEN
    RAISE EXCEPTION '用户不存在';
  END IF;

  DELETE FROM profiles WHERE id = v_uid;
  DELETE FROM auth.users WHERE id = v_uid;

  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 执行完成！
-- ============================================================
SELECT '用户名登录系统配置完成！' AS status;
