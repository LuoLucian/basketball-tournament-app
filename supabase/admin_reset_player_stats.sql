-- ============================================================
-- 超管重置球员所有比赛数据
--
-- 删除该球员的全部 game_stats 和 action_logs 记录，
-- 并重新计算受影响比赛的比分（基于剩余 action_logs）。
-- 仅 super_admin 可调用。
-- ============================================================

CREATE OR REPLACE FUNCTION admin_reset_player_stats(
  p_player_id UUID,
  p_user_id   UUID
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_role VARCHAR(20);
  v_affected   UUID[];
  v_del_stats  INTEGER := 0;
  v_del_logs  INTEGER := 0;
  v_game_id   UUID;
BEGIN
  -- 1. 权限校验：仅 super_admin
  SELECT role INTO v_caller_role
  FROM profiles WHERE id = p_user_id;

  IF v_caller_role IS DISTINCT FROM 'super_admin' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', '权限不足：仅超管可重置球员数据'
    );
  END IF;

  -- 2. 找出该球员涉及的所有比赛
  SELECT ARRAY_AGG(DISTINCT game_id) INTO v_affected
  FROM game_stats
  WHERE player_id = p_player_id;

  IF v_affected IS NULL THEN
    RETURN jsonb_build_object(
      'success', true,
      'deleted_stats', 0,
      'deleted_logs', 0,
      'affected_games', '{}'::JSONB
    );
  END IF;

  -- 3. 删除 game_stats 记录
  WITH d AS (
    DELETE FROM game_stats
    WHERE player_id = p_player_id
    RETURNING game_id
  )
  SELECT COUNT(*) INTO v_del_stats FROM d;

  -- 4. 删除 action_logs 记录
  WITH d AS (
    DELETE FROM action_logs
    WHERE player_id = p_player_id
    RETURNING game_id
  )
  SELECT COUNT(*) INTO v_del_logs FROM d;

  -- 5. 重新计算受影响比赛的比分
  FOREACH v_game_id IN ARRAY v_affected
  LOOP
    -- 重算主队比分
    UPDATE games g
    SET home_score = COALESCE((
      SELECT SUM(
        CASE a.action_type
          WHEN 'pts_1' THEN 1
          WHEN 'pts_2' THEN 2
          WHEN 'pts_3' THEN 3
          ELSE 0
        END * a.delta
      )
      FROM action_logs a
      WHERE a.game_id = g.id
        AND a.team_id = g.home_team_id
        AND a.action_type IN ('pts_1', 'pts_2', 'pts_3')
    ), 0)
    WHERE g.id = v_game_id;

    -- 重算客队比分
    UPDATE games g
    SET away_score = COALESCE((
      SELECT SUM(
        CASE a.action_type
          WHEN 'pts_1' THEN 1
          WHEN 'pts_2' THEN 2
          WHEN 'pts_3' THEN 3
          ELSE 0
        END * a.delta
      )
      FROM action_logs a
      WHERE a.game_id = g.id
        AND a.team_id = g.away_team_id
        AND a.action_type IN ('pts_1', 'pts_2', 'pts_3')
    ), 0)
    WHERE g.id = v_game_id;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'deleted_stats', v_del_stats,
    'deleted_logs', v_del_logs,
    'affected_games', to_jsonb(v_affected)
  );
END;
$$;
