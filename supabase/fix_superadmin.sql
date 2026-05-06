-- ============================================================
-- 修复方案：删除旧用户，改用 Dashboard 创建
-- 在 SQL Editor 中执行
-- ============================================================

-- 删除之前创建的超级管理员（密码加密方式不兼容）
DELETE FROM profiles WHERE id IN (
  SELECT id FROM auth.users WHERE email = 'admin@detai.com'
);
DELETE FROM auth.users WHERE email = 'admin@detai.com';

SELECT '旧用户已删除，请通过 Dashboard 重新创建' AS status;
