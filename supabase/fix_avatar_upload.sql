-- ============================================================
-- 通过 SECURITY DEFINER RPC 上传头像（终极方案）
-- 绕过 Storage RLS，让 anon 也能上传
-- 在 Supabase SQL Editor 中执行
-- ============================================================

-- 方案A：给 anon 写权限（推荐，简单直接）
DROP POLICY IF EXISTS "avatars_auth_insert" ON storage.objects;
DROP POLICY IF EXISTS "avatars_auth_update" ON storage.objects;
DROP POLICY IF EXISTS "avatars_auth_delete" ON storage.objects;

CREATE POLICY "avatars_anon_insert" ON storage.objects
  FOR INSERT TO anon WITH CHECK (bucket_id = 'avatars');
CREATE POLICY "avatars_anon_update" ON storage.objects
  FOR UPDATE TO anon USING (bucket_id = 'avatars');
CREATE POLICY "avatars_anon_delete" ON storage.objects
  FOR DELETE TO anon USING (bucket_id = 'avatars');

-- 验证策略
SELECT policyname, cmd, roles FROM pg_policies
WHERE tablename = 'objects' AND policyname LIKE 'avatars_%'
ORDER BY policyname;

-- 查询数据库里已上传头像的球员（看 avatar_url 是否存在）
SELECT id, name, avatar_url FROM players WHERE avatar_url IS NOT NULL;
