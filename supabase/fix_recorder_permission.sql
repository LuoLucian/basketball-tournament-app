-- ============================================================
-- 更新 is_game_recorder() 函数：扩大记录权限范围
-- 权限规则：超管/管理员 / 所有记录员 / 双方球队owner / 本场指派记录员
-- 在 Supabase SQL Editor 中执行
-- ============================================================

CREATE OR REPLACE FUNCTION is_game_recorder(game_uuid UUID)
RETURNS BOOLEAN AS $$
  SELECT
    -- 1. 本场指派的记录员
    EXISTS (SELECT 1 FROM game_recorders WHERE game_id = game_uuid AND user_id = auth.uid())
    -- 2. 超管或管理员
    OR is_admin_or_above()
    -- 3. 所有记录员角色
    OR (SELECT role FROM profiles WHERE id = auth.uid()) = 'recorder'
    -- 4. 主队或客队的 owner（球队管理员）
    OR EXISTS (
      SELECT 1 FROM games g
      JOIN teams t ON t.id IN (g.home_team_id, g.away_team_id)
      WHERE g.id = game_uuid AND t.owner_id = auth.uid()
    )
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

-- 验证
SELECT proname, pg_get_functiondef(oid) FROM pg_proc WHERE proname = 'is_game_recorder';
