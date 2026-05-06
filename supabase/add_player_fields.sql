-- ============================================================
-- 球员表新增字段：身高、体重、技能标签
-- 在 Supabase SQL Editor 中执行
-- ============================================================

-- 身高（cm）
ALTER TABLE players ADD COLUMN IF NOT EXISTS height SMALLINT;
-- 体重（kg）
ALTER TABLE players ADD COLUMN IF NOT EXISTS weight SMALLINT;
-- 技能标签（逗号分隔，如"三分,突破,防守"）
ALTER TABLE players ADD COLUMN IF NOT EXISTS skills TEXT;
