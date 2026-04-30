-- ============================================================
-- 修复头像上传 RLS 权限问题
-- 自定义认证体系下 auth.uid() 为 NULL，需要给 anon 写权限
-- 在 Supabase SQL Editor 中执行
-- ============================================================

-- 删除旧的仅 authenticated 的写入策略（如果存在）
DROP POLICY IF EXISTS "avatars_auth_insert" ON storage.objects;
DROP POLICY IF EXISTS "avatars_auth_update" ON storage.objects;
DROP POLICY IF EXISTS "avatars_auth_delete" ON storage.objects;

-- 给 anon 添加头像桶的写入权限
CREATE POLICY "avatars_anon_insert" ON storage.objects
  FOR INSERT TO anon WITH CHECK (bucket_id = 'avatars');

CREATE POLICY "avatars_anon_update" ON storage.objects
  FOR UPDATE TO anon USING (bucket_id = 'avatars');

CREATE POLICY "avatars_anon_delete" ON storage.objects
  FOR DELETE TO anon USING (bucket_id = 'avatars');

-- 验证
SELECT policyname, cmd, roles FROM pg_policies
WHERE tablename = 'objects' AND policyname LIKE 'avatars_%'
ORDER BY policyname;
