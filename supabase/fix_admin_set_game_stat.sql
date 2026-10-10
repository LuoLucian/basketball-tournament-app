-- ============================================================
-- 修复超管编辑比赛数据：admin_set_game_stat 适配新表结构
-- 在 Supabase SQL Editor 中整体执行（可重复执行，幂等）
--
-- Bug 原因：game_stats 表字段已从 fgm/fga 改为 fg2m/fg2a，
-- 但函数体仍引用不存在的 fgm/fga 列，导致任何字段修改都在
-- 运行时抛 "column game_stats.fgm does not exist"，超管编辑
-- 完全不可用。
--
-- 本次修复：
--   1. 白名单改为 fg2m/fg2a/fg3m/fg3a（与表结构一致）
--   2. 一致性联动：fg2m≤fg2a、fg3m≤fg3a、ftm≤fta
--   3. 修改 pts 时同步更新 games 比分（保留）
--   4. 保留审计日志
--   5. p_user_id 缺省 NULL（兼容 auth.uid()）
-- ============================================================

DROP FUNCTION IF EXISTS admin_set_game_stat(UUID, UUID, UUID, VARCHAR, INTEGER, UUID);

CREATE OR REPLACE FUNCTION admin_set_game_stat(
  p_game_id     UUID,
  p_player_id   UUID,
  p_team_id     UUID,
  p_field       VARCHAR(30),
  p_new_value   INTEGER,
  p_user_id     UUID DEFAULT NULL
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
BEGIN
  -- 1. 权限校验：仅 super_admin 可调用
  IF NOT EXISTS (
    SELECT 1 FROM profiles WHERE id = COALESCE(p_user_id, auth.uid()) AND role = 'super_admin'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', '权限不足：仅超管可修改比赛数据');
  END IF;

  -- 2. 字段白名单校验（与 game_stats 表结构一致）
  IF p_field NOT IN (
    'pts','reb','oreb','dreb','ast','stl','blk','tov','pf',
    'fg2m','fg2a','fg3m','fg3a','ftm','fta','min_played'
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
      WHEN 'pts'        THEN pts
      WHEN 'reb'        THEN reb
      WHEN 'oreb'       THEN oreb
      WHEN 'dreb'       THEN dreb
      WHEN 'ast'        THEN ast
      WHEN 'stl'        THEN stl
      WHEN 'blk'        THEN blk
      WHEN 'tov'        THEN tov
      WHEN 'pf'         THEN pf
      WHEN 'fg2m'       THEN fg2m
      WHEN 'fg2a'       THEN fg2a
      WHEN 'fg3m'       THEN fg3m
      WHEN 'fg3a'       THEN fg3a
      WHEN 'ftm'        THEN ftm
      WHEN 'fta'        THEN fta
      WHEN 'min_played' THEN min_played
    END
  INTO v_stat_id, v_old_val
  FROM game_stats
  WHERE game_id = p_game_id AND player_id = p_player_id;

  v_old_val := COALESCE(v_old_val, 0);
  v_delta   := p_new_value - v_old_val;

  -- 5. 若记录不存在，先 INSERT（写入快照字段）
  IF v_stat_id IS NULL THEN
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
      fg2m, fg2a, fg3m, fg3a, ftm, fta, min_played,
      player_name, jersey_no, player_position, player_avatar_url,
      team_name, team_color
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
      CASE WHEN p_field = 'fg2m'       THEN p_new_value ELSE 0 END,
      CASE WHEN p_field = 'fg2a'       THEN p_new_value ELSE 0 END,
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
    -- 6. 更新已有记录：命中数 ≤ 出手数 联动
    IF p_field = 'fg2m' THEN
      UPDATE game_stats
      SET fg2m = p_new_value, fg2a = GREATEST(COALESCE(fg2a, 0), p_new_value), updated_at = NOW()
      WHERE id = v_stat_id;
    ELSIF p_field = 'fg2a' THEN
      UPDATE game_stats
      SET fg2a = p_new_value, fg2m = LEAST(COALESCE(fg2m, 0), p_new_value), updated_at = NOW()
      WHERE id = v_stat_id;
    ELSIF p_field = 'fg3m' THEN
      UPDATE game_stats
      SET fg3m = p_new_value, fg3a = GREATEST(COALESCE(fg3a, 0), p_new_value), updated_at = NOW()
      WHERE id = v_stat_id;
    ELSIF p_field = 'fg3a' THEN
      UPDATE game_stats
      SET fg3a = p_new_value, fg3m = LEAST(COALESCE(fg3m, 0), p_new_value), updated_at = NOW()
      WHERE id = v_stat_id;
    ELSIF p_field = 'ftm' THEN
      UPDATE game_stats
      SET ftm = p_new_value, fta = GREATEST(COALESCE(fta, 0), p_new_value), updated_at = NOW()
      WHERE id = v_stat_id;
    ELSIF p_field = 'fta' THEN
      UPDATE game_stats
      SET fta = p_new_value, ftm = LEAST(COALESCE(ftm, 0), p_new_value), updated_at = NOW()
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
    p_game_id, p_player_id, p_team_id,
    'admin_set_' || p_field,
    v_delta,
    0,
    COALESCE(p_user_id, auth.uid())
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

GRANT EXECUTE ON FUNCTION admin_set_game_stat(UUID, UUID, UUID, VARCHAR, INTEGER, UUID) TO anon, authenticated;
