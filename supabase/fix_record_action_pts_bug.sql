-- ============================================================
-- 修复 record_action RPC 中得分更新 Bug
--
-- 问题1：pts_2/pts_3 时 pts 字段只加了 p_delta(=1)，
--        而不是实际分值 2/3，导致球员得分统计不准
-- 问题2：命中动作时没有同时更新出手数（fga/fg3a/fta），
--        导致命中率计算不准
--
-- 修复：
--   1. pts 字段用实际分值更新（1/2/3），而不是 p_delta
--   2. 命中时同时更新出手数
-- ============================================================

CREATE OR REPLACE FUNCTION record_action(
  p_game_id     UUID,
  p_player_id   UUID,
  p_team_id     UUID,
  p_action_type VARCHAR(30),
  p_delta       SMALLINT DEFAULT 1,
  p_quarter     SMALLINT DEFAULT 1,
  p_recorded_by UUID DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_log_id    UUID;
  v_pts       SMALLINT;
  v_is_home   BOOLEAN;
  v_field     TEXT;
  v_stat_id   UUID;
  v_recorder  UUID;
  v_snap_name VARCHAR(50);
  v_snap_jersey SMALLINT;
  v_snap_pos  VARCHAR(20);
  v_snap_avatar TEXT;
  v_snap_team_name VARCHAR(100);
  v_snap_team_color VARCHAR(7);
  v_pts_delta SMALLINT;  -- 实际得分增量
BEGIN
  v_recorder := COALESCE(p_recorded_by, auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid);

  -- 1. 写入 action_logs
  INSERT INTO action_logs (game_id, player_id, team_id, action_type, delta, quarter, recorded_by)
  VALUES (p_game_id, p_player_id, p_team_id, p_action_type, p_delta, p_quarter, v_recorder)
  RETURNING id INTO v_log_id;

  -- 2. 计算实际得分增量（pts_1→1, pts_2→2, pts_3→3, 其他→0）
  v_pts_delta := CASE p_action_type
    WHEN 'pts_1' THEN 1
    WHEN 'pts_2' THEN 2
    WHEN 'pts_3' THEN 3
    ELSE 0
  END * p_delta;

  -- 3. 映射 action_type → game_stats 字段
  v_field := CASE p_action_type
    WHEN 'pts_1'     THEN 'pts'
    WHEN 'pts_2'     THEN 'pts'
    WHEN 'pts_3'     THEN 'pts'
    WHEN 'fga_miss'  THEN 'fga'
    WHEN 'fg3a_miss' THEN 'fg3a'
    WHEN 'fta_miss'  THEN 'fta'
    WHEN 'reb'       THEN 'reb'
    WHEN 'oreb'      THEN 'oreb'
    WHEN 'dreb'      THEN 'dreb'
    WHEN 'ast'       THEN 'ast'
    WHEN 'stl'       THEN 'stl'
    WHEN 'blk'       THEN 'blk'
    WHEN 'tov'       THEN 'tov'
    WHEN 'pf'        THEN 'pf'
    ELSE NULL
  END;

  -- 4. 更新 game_stats（动态字段）
  IF v_field IS NOT NULL THEN
    SELECT id INTO v_stat_id
    FROM game_stats
    WHERE game_id = p_game_id AND player_id = p_player_id;

    IF v_stat_id IS NOT NULL THEN
      -- 对于 pts 字段，使用实际分值而不是 p_delta
      IF v_field = 'pts' THEN
        UPDATE game_stats SET pts = GREATEST(0, COALESCE(pts, 0) + v_pts_delta), updated_at = NOW()
        WHERE id = v_stat_id;
      ELSE
        EXECUTE format(
          'UPDATE game_stats SET %I = GREATEST(0, COALESCE(%I, 0) + $1), updated_at = NOW() WHERE id = $2',
          v_field, v_field
        ) USING p_delta, v_stat_id;
      END IF;
    ELSE
      -- 新建记录时，获取球员快照信息
      SELECT p.name, p.avatar_url INTO v_snap_name, v_snap_avatar
      FROM players p WHERE p.id = p_player_id;

      SELECT tp.jersey_no, tp.position INTO v_snap_jersey, v_snap_pos
      FROM team_players tp
      WHERE tp.player_id = p_player_id AND tp.team_id = p_team_id AND tp.is_active = true
      LIMIT 1;

      SELECT t.name, t.color INTO v_snap_team_name, v_snap_team_color
      FROM teams t WHERE t.id = p_team_id;

      -- 对于 pts 字段，使用实际分值
      IF v_field = 'pts' THEN
        INSERT INTO game_stats (game_id, player_id, team_id, game_type, pts, player_name, jersey_no, player_position, player_avatar_url, team_name, team_color)
        VALUES (p_game_id, p_player_id, p_team_id, (SELECT game_type FROM games WHERE id = p_game_id), GREATEST(0, v_pts_delta),
                v_snap_name, v_snap_jersey, v_snap_pos, v_snap_avatar, v_snap_team_name, v_snap_team_color);
      ELSE
        EXECUTE format(
          'INSERT INTO game_stats (game_id, player_id, team_id, game_type, %I, player_name, jersey_no, player_position, player_avatar_url, team_name, team_color)
           VALUES ($1, $2, $3, (SELECT game_type FROM games WHERE id = $1), GREATEST(0, $4), $5, $6, $7, $8, $9, $10)',
          v_field
        ) USING p_game_id, p_player_id, p_team_id, p_delta,
                v_snap_name, v_snap_jersey, v_snap_pos, v_snap_avatar, v_snap_team_name, v_snap_team_color;
      END IF;
    END IF;

    -- 命中时同时更新命中数和出手数
    IF p_action_type = 'pts_1' THEN
      PERFORM update_stat_field(p_game_id, p_player_id, p_team_id, 'ftm', p_delta);
      PERFORM update_stat_field(p_game_id, p_player_id, p_team_id, 'fta', p_delta);  -- 罚球出手+1
    ELSIF p_action_type = 'pts_2' THEN
      PERFORM update_stat_field(p_game_id, p_player_id, p_team_id, 'fgm', p_delta);
      PERFORM update_stat_field(p_game_id, p_player_id, p_team_id, 'fga', p_delta);  -- 两分出手+1
    ELSIF p_action_type = 'pts_3' THEN
      PERFORM update_stat_field(p_game_id, p_player_id, p_team_id, 'fg3m', p_delta);
      PERFORM update_stat_field(p_game_id, p_player_id, p_team_id, 'fg3a', p_delta); -- 三分出手+1
    END IF;
  END IF;

  -- 5. 如果是得分动作，更新比分
  v_pts := CASE p_action_type
    WHEN 'pts_1' THEN 1
    WHEN 'pts_2' THEN 2
    WHEN 'pts_3' THEN 3
    ELSE 0
  END;

  IF v_pts > 0 THEN
    v_is_home := (p_team_id = (SELECT home_team_id FROM games WHERE id = p_game_id));
    IF v_is_home THEN
      UPDATE games
      SET home_score = GREATEST(0, COALESCE(home_score, 0) + v_pts * p_delta)
      WHERE id = p_game_id;
    ELSE
      UPDATE games
      SET away_score = GREATEST(0, COALESCE(away_score, 0) + v_pts * p_delta)
      WHERE id = p_game_id;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'log_id', v_log_id,
    'action_type', p_action_type,
    'delta', p_delta
  );
END;
$$;

-- ============================================================
-- 同时修复已存在的错误数据
-- 根据 action_logs 重新计算每个球员的 pts
-- ============================================================

-- 重新计算 game_stats.pts：基于 action_logs 中实际的得分记录
UPDATE game_stats gs
SET pts = COALESCE((
  SELECT SUM(
    CASE a.action_type
      WHEN 'pts_1' THEN 1
      WHEN 'pts_2' THEN 2
      WHEN 'pts_3' THEN 3
      ELSE 0
    END * a.delta
  )
  FROM action_logs a
  WHERE a.game_id = gs.game_id
    AND a.player_id = gs.player_id
    AND a.action_type IN ('pts_1', 'pts_2', 'pts_3')
), 0)
WHERE gs.game_id IN (
  SELECT DISTINCT game_id FROM action_logs WHERE action_type IN ('pts_2', 'pts_3')
);

-- 重新计算 game_stats.fga（两分出手 = 两分命中 + 两分不中）
UPDATE game_stats gs
SET fga = COALESCE((
  SELECT SUM(CASE WHEN a.action_type IN ('pts_2', 'fga_miss') THEN a.delta ELSE 0 END)
  FROM action_logs a
  WHERE a.game_id = gs.game_id
    AND a.player_id = gs.player_id
    AND a.action_type IN ('pts_2', 'fga_miss')
), 0)
WHERE gs.game_id IN (
  SELECT DISTINCT game_id FROM action_logs WHERE action_type IN ('pts_2', 'fga_miss')
);

-- 重新计算 game_stats.fg3a（三分出手 = 三分命中 + 三分不中）
UPDATE game_stats gs
SET fg3a = COALESCE((
  SELECT SUM(CASE WHEN a.action_type IN ('pts_3', 'fg3a_miss') THEN a.delta ELSE 0 END)
  FROM action_logs a
  WHERE a.game_id = gs.game_id
    AND a.player_id = gs.player_id
    AND a.action_type IN ('pts_3', 'fg3a_miss')
), 0)
WHERE gs.game_id IN (
  SELECT DISTINCT game_id FROM action_logs WHERE action_type IN ('pts_3', 'fg3a_miss')
);

-- 重新计算 game_stats.fta（罚球出手 = 罚球命中 + 罚球不中）
UPDATE game_stats gs
SET fta = COALESCE((
  SELECT SUM(CASE WHEN a.action_type IN ('pts_1', 'fta_miss') THEN a.delta ELSE 0 END)
  FROM action_logs a
  WHERE a.game_id = gs.game_id
    AND a.player_id = gs.player_id
    AND a.action_type IN ('pts_1', 'fta_miss')
), 0)
WHERE gs.game_id IN (
  SELECT DISTINCT game_id FROM action_logs WHERE action_type IN ('pts_1', 'fta_miss')
);

-- 重新计算 games 比分（确保比分板与实际得分一致）
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
WHERE g.id IN (
  SELECT DISTINCT game_id FROM action_logs WHERE action_type IN ('pts_1', 'pts_2', 'pts_3')
);

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
WHERE g.id IN (
  SELECT DISTINCT game_id FROM action_logs WHERE action_type IN ('pts_1', 'pts_2', 'pts_3')
);
