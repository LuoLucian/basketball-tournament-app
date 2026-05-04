-- ============================================================
-- 超管精确设置比赛球员单项数据
--
-- 允许超管将某项统计数据设置为任意指定值，
-- 自动同步更新比分（若为 pts）并写入审计日志。
--
-- 白名单字段：
--   pts, reb, oreb, dreb, ast, stl, blk, tov, pf,
--   fgm, fga, fg3m, fg3a, ftm, fta, min_played
-- ============================================================

CREATE OR REPLACE FUNCTION admin_set_game_stat(
  p_game_id     UUID,
  p_player_id   UUID,
  p_team_id     UUID,
  p_field       VARCHAR(30),
  p_new_value   INTEGER,
  p_user_id     UUID
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_old_val    INTEGER;
  v_delta      INTEGER;
  v_is_home    BOOLEAN;
  v_stat_id    UUID;
  v_snap_name  VARCHAR(50);
  v_snap_jersey SMALLINT;
  v_snap_pos   VARCHAR(20);
  v_snap_avatar TEXT;
  v_snap_team_name VARCHAR(100);
  v_snap_team_color VARCHAR(7);
  v_game_status VARCHAR(20);
BEGIN
  -- 1. 权限校验：仅 super_admin 可调用
  IF NOT EXISTS (
    SELECT 1 FROM profiles WHERE id = p_user_id AND role = 'super_admin'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', '权限不足：仅超管可修改比赛数据');
  END IF;

  -- 2. 字段白名单校验
  IF p_field NOT IN (
    'pts','reb','oreb','dreb','ast','stl','blk','tov','pf',
    'fgm','fga','fg3m','fg3a','ftm','fta','min_played'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', '非法字段：' || p_field);
  END IF;

  -- 3. 新值不能为负
  IF p_new_value < 0 THEN
    RETURN jsonb_build_object('success', false, 'error', '数值不能为负数');
  END IF;

  -- 4. 获取当前值
  SELECT id,
    CASE p_field
      WHEN 'pts'      THEN pts
      WHEN 'reb'      THEN reb
      WHEN 'oreb'     THEN oreb
      WHEN 'dreb'     THEN dreb
      WHEN 'ast'      THEN ast
      WHEN 'stl'      THEN stl
      WHEN 'blk'      THEN blk
      WHEN 'tov'      THEN tov
      WHEN 'pf'       THEN pf
      WHEN 'fgm'      THEN fgm
      WHEN 'fga'      THEN fga
      WHEN 'fg3m'     THEN fg3m
      WHEN 'fg3a'     THEN fg3a
      WHEN 'ftm'      THEN ftm
      WHEN 'fta'      THEN fta
      WHEN 'min_played' THEN min_played
    END
  INTO v_stat_id, v_old_val
  FROM game_stats
  WHERE game_id = p_game_id AND player_id = p_player_id;

  v_old_val := COALESCE(v_old_val, 0);
  v_delta   := p_new_value - v_old_val;

  -- 5. 若记录不存在，先 INSERT（写入快照字段）
  IF v_stat_id IS NULL THEN
    -- 获取快照信息
    SELECT p.name, p.avatar_url INTO v_snap_name, v_snap_avatar
    FROM players p WHERE p.id = p_player_id;

    SELECT tp.jersey_no, tp.position INTO v_snap_jersey, v_snap_pos
    FROM team_players tp
    WHERE tp.player_id = p_player_id AND tp.team_id = p_team_id AND tp.is_active = true
    LIMIT 1;

    SELECT t.name, t.color INTO v_snap_team_name, v_snap_team_color
    FROM teams t WHERE t.id = p_team_id;

    INSERT INTO game_stats (
      game_id, player_id, team_id, game_type,
      pts, reb, oreb, dreb, ast, stl, blk, tov, pf,
      fgm, fga, fg3m, fg3a, ftm, fta, min_played,
      player_name_snapshot, jersey_no_snapshot, player_position_snapshot, player_avatar_url_snapshot,
      team_name_snapshot, team_color_snapshot
    )
    VALUES (
      p_game_id, p_player_id, p_team_id,
      (SELECT game_type FROM games WHERE id = p_game_id),
      CASE WHEN p_field = 'pts'        THEN p_new_value ELSE 0 END,
      CASE WHEN p_field = 'reb'        THEN p_new_value ELSE 0 END,
      CASE WHEN p_field = 'oreb'       THEN p_new_value ELSE 0 END,
      CASE WHEN p_field = 'dreb'       THEN p_new_value ELSE 0 END,
      CASE WHEN p_field = 'ast'        THEN p_new_value ELSE 0 END,
      CASE WHEN p_field = 'stl'        THEN p_new_value ELSE 0 END,
      CASE WHEN p_field = 'blk'        THEN p_new_value ELSE 0 END,
      CASE WHEN p_field = 'tov'        THEN p_new_value ELSE 0 END,
      CASE WHEN p_field = 'pf'         THEN p_new_value ELSE 0 END,
      CASE WHEN p_field = 'fgm'        THEN p_new_value ELSE 0 END,
      CASE WHEN p_field = 'fga'        THEN p_new_value ELSE 0 END,
      CASE WHEN p_field = 'fg3m'       THEN p_new_value ELSE 0 END,
      CASE WHEN p_field = 'fg3a'       THEN p_new_value ELSE 0 END,
      CASE WHEN p_field = 'ftm'        THEN p_new_value ELSE 0 END,
      CASE WHEN p_field = 'fta'        THEN p_new_value ELSE 0 END,
      CASE WHEN p_field = 'min_played' THEN p_new_value ELSE 0 END,
      v_snap_name, v_snap_jersey, v_snap_pos, v_snap_avatar,
      v_snap_team_name, v_snap_team_color
    )
    RETURNING id INTO v_stat_id;
  ELSE
    -- 6. 更新已有记录
    -- 先处理 fgm/fga 一致性：若修改后 fgm > fga，自动把 fga 拉到 fgm
    -- 同理处理 fg3m/fg3a、ftm/fta
    IF p_field = 'fgm' THEN
      UPDATE game_stats
      SET fgm = p_new_value,
          fga = GREATEST(fga, p_new_value),
          updated_at = NOW()
      WHERE id = v_stat_id;
    ELSIF p_field = 'fga' THEN
      UPDATE game_stats
      SET fga = p_new_value,
          fgm = LEAST(fgm, p_new_value),
          updated_at = NOW()
      WHERE id = v_stat_id;
    ELSIF p_field = 'fg3m' THEN
      UPDATE game_stats
      SET fg3m = p_new_value,
          fg3a = GREATEST(fg3a, p_new_value),
          updated_at = NOW()
      WHERE id = v_stat_id;
    ELSIF p_field = 'fg3a' THEN
      UPDATE game_stats
      SET fg3a = p_new_value,
          fg3m = LEAST(fg3m, p_new_value),
          updated_at = NOW()
      WHERE id = v_stat_id;
    ELSIF p_field = 'ftm' THEN
      UPDATE game_stats
      SET ftm = p_new_value,
          fta = GREATEST(fta, p_new_value),
          updated_at = NOW()
      WHERE id = v_stat_id;
    ELSIF p_field = 'fta' THEN
      UPDATE game_stats
      SET fta = p_new_value,
          ftm = LEAST(ftm, p_new_value),
          updated_at = NOW()
      WHERE id = v_stat_id;
    ELSE
      -- 普通字段直接更新
      EXECUTE format(
        'UPDATE game_stats SET %I = $1, updated_at = NOW() WHERE id = $2',
        p_field
      ) USING p_new_value, v_stat_id;
    END IF;
  END IF;

  -- 7. 若修改的是 pts，同步更新 games 表比分
  IF p_field = 'pts' AND v_delta <> 0 THEN
    SELECT (home_team_id = p_team_id) INTO v_is_home
    FROM games WHERE id = p_game_id;

    IF v_is_home THEN
      UPDATE games
      SET home_score = GREATEST(0, COALESCE(home_score, 0) + v_delta)
      WHERE id = p_game_id;
    ELSE
      UPDATE games
      SET away_score = GREATEST(0, COALESCE(away_score, 0) + v_delta)
      WHERE id = p_game_id;
    END IF;
  END IF;

  -- 8. 写入审计日志
  INSERT INTO action_logs (game_id, player_id, team_id, action_type, delta, quarter, recorded_by)
  VALUES (
    p_game_id,
    p_player_id,
    p_team_id,
    'admin_set_' || p_field,
    0,  -- delta 不适用，用备注说明
    0,
    p_user_id
  );

  RETURN jsonb_build_object(
    'success', true,
    'field', p_field,
    'old_value', v_old_val,
    'new_value', p_new_value,
    'delta', v_delta,
    'game_score_updated', (p_field = 'pts' AND v_delta <> 0)
  );
END;
$$;
