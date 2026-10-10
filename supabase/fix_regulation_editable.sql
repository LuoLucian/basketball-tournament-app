-- ============================================================
-- 赛事规程可编辑化：site_regulation 表 + save_regulation RPC
-- 在 Supabase SQL Editor 中整体执行（可重复执行，幂等）
--
-- 用途：规程页（/regulation）内容存数据库，超管可在页面直接
-- 编辑文字并保存，所有用户看到最新内容。
-- 说明：应用为自定义认证（auth.uid() 恒 NULL），前端调用时
-- 显式传 p_user_id，函数内校验 super_admin。
-- ============================================================

-- ══ 1. 规程内容表（单行，id 固定 1）══════════════════════
CREATE TABLE IF NOT EXISTS site_regulation (
  id         INTEGER PRIMARY KEY CHECK (id = 1),
  content    JSONB NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by UUID REFERENCES profiles(id) ON DELETE SET NULL
);

ALTER TABLE site_regulation ENABLE ROW LEVEL SECURITY;

-- 公开可读（观众查看规程）
DROP POLICY IF EXISTS "site_regulation_public_read" ON site_regulation;
CREATE POLICY "site_regulation_public_read" ON site_regulation
  FOR SELECT USING (true);

-- ══ 2. 保存规程 RPC（仅超管）════════════════════════════
CREATE OR REPLACE FUNCTION save_regulation(
  p_content JSONB,
  p_user_id UUID DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user UUID;
BEGIN
  v_user := COALESCE(p_user_id, auth.uid());
  IF v_user IS NULL OR NOT EXISTS (
    SELECT 1 FROM profiles WHERE id = v_user AND role = 'super_admin' AND is_active
  ) THEN
    RAISE EXCEPTION '权限不足：仅超管可编辑赛事规程';
  END IF;

  INSERT INTO site_regulation (id, content, updated_at, updated_by)
  VALUES (1, p_content, NOW(), v_user)
  ON CONFLICT (id) DO UPDATE
    SET content = EXCLUDED.content,
        updated_at = NOW(),
        updated_by = EXCLUDED.updated_by;

  RETURN jsonb_build_object('success', true, 'updated_at', NOW());
END;
$$;

GRANT EXECUTE ON FUNCTION save_regulation(JSONB, UUID) TO anon, authenticated;

-- 验证
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public' AND table_name = 'site_regulation';
