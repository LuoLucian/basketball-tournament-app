-- 删除比赛及其所有关联数据（仅 super_admin 可调用）
-- SECURITY DEFINER + SET search_path 绕过 RLS
-- p_user_id 由前端传入（自定义认证体系），降级为 auth.uid()
DROP FUNCTION IF EXISTS delete_game(UUID);

CREATE OR REPLACE FUNCTION delete_game(
  p_game_id UUID,
  p_user_id UUID DEFAULT NULL  -- 前端传入当前用户 ID
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user UUID;
BEGIN
  -- 确定当前用户：优先用参数，降级为 auth.uid()
  v_user := COALESCE(p_user_id, auth.uid());

  -- 验证调用者是 super_admin
  IF v_user IS NULL OR NOT EXISTS (
    SELECT 1 FROM profiles WHERE id = v_user AND role = 'super_admin'
  ) THEN
    RAISE EXCEPTION '权限不足：仅超级管理员可删除比赛';
  END IF;

  -- 验证比赛存在
  IF NOT EXISTS (SELECT 1 FROM games WHERE id = p_game_id) THEN
    RAISE EXCEPTION '比赛不存在';
  END IF;

  -- 级联删除关联数据
  DELETE FROM action_logs WHERE game_id = p_game_id;
  DELETE FROM game_mvp WHERE game_id = p_game_id;
  DELETE FROM game_stats WHERE game_id = p_game_id;
  DELETE FROM game_lineup WHERE game_id = p_game_id;
  DELETE FROM game_recorders WHERE game_id = p_game_id;
  DELETE FROM games WHERE id = p_game_id;
END;
$$;
