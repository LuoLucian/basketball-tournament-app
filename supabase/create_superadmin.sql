-- ============================================================
-- 创建超级管理员账号
-- 在 Supabase SQL Editor 中执行
-- 管理员邮箱: admin@detai.com
-- 管理员密码: Dt@2026Admin
-- ============================================================

-- 先获取 instance_id（每个 Supabase 项目固定）
DO $$
DECLARE
  v_instance_id UUID;
  v_user_id UUID;
  v_username TEXT;
BEGIN
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
    'admin@detai.com',
    crypt('Dt@2026Admin', gen_salt('bf')),
    NOW(),
    '{"display_name": "超级管理员"}',
    NOW(),
    NOW(),
    'authenticated',
    'authenticated',
    '{"provider": "email", "providers": ["email"]}'
  ) RETURNING id INTO v_user_id;

  -- 创建 profile 记录（super_admin 角色）
  v_username := 'admin_' || substr(md5(random()::text), 1, 6);
  INSERT INTO profiles (id, username, display_name, role, is_active)
  VALUES (v_user_id, v_username, '超级管理员', 'super_admin', TRUE);

  RAISE NOTICE '超级管理员创建成功！用户ID: %, 用户名: %', v_user_id, v_username;
END $$;
