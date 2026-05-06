-- ============================================================
-- 创建超级管理员（用户名模式）
-- 在 Supabase SQL Editor 中执行
-- 用户名: lxlpow  密码: 123456
-- ============================================================

-- 先清理旧数据（防止重复创建）
DELETE FROM profiles WHERE username = 'lxlpow';
DELETE FROM auth.users WHERE email = 'lxlpow@local.internal';
-- 也清理之前的admin用户
DELETE FROM profiles WHERE username = 'admin';
DELETE FROM auth.users WHERE email LIKE 'admin%@local.internal';

-- 启用 pgcrypto 扩展（用于密码加密）
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 创建超级管理员
DO $$
DECLARE
  v_instance_id UUID;
  v_user_id UUID;
BEGIN
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
    'lxlpow@local.internal',
    crypt('placeholder_' || gen_random_uuid()::text, gen_salt('bf')),
    NOW(),
    '{"display_name": "超级管理员"}',
    NOW(),
    NOW(),
    'authenticated',
    'authenticated',
    '{"provider": "username", "providers": ["username"]}',
    '',
    '',
    ''
  ) RETURNING id INTO v_user_id;

  INSERT INTO profiles (
    id, username, display_name, role, password_hash, is_active
  ) VALUES (
    v_user_id,
    'lxlpow',
    '超级管理员',
    'super_admin',
    crypt('123456', gen_salt('bf')),
    TRUE
  );

  RAISE NOTICE '超级管理员创建成功！用户名: lxlpow, 密码: 123456';
END $$;

SELECT '超级管理员创建完成！' AS status;
