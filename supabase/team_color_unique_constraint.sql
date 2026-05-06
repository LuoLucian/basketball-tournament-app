-- 球队颜色唯一约束
-- 在 Supabase SQL Editor 中手动执行
-- 执行前请先确认没有重复颜色（见下方查询）

-- 1. 检查是否有重复颜色（执行后如无结果则可直接添加约束）
-- SELECT color, COUNT(*) FROM teams GROUP BY color HAVING COUNT(*) > 1;

-- 2. 如无重复颜色，执行以下语句添加唯一约束
ALTER TABLE teams
  ADD CONSTRAINT unique_team_color UNIQUE (color);

-- 如需删除约束（回滚用）：
-- ALTER TABLE teams DROP CONSTRAINT unique_team_color;
