-- ============================================================
-- record_action RPC：一次性完成录入动作
--   1. 写入 action_logs
--   2. 更新 game_stats（upsert 对应字段）
--   3. 如果是得分动作，同时更新 games 的比分
--
-- SECURITY DEFINER + SET search_path 绕过 RLS
-- recorded_by 参数由前端传入（自定义认证体系）
-- ============================================================

DROP FUNCTION IF EXISTS record_action(UUID, UUID, UUID, VARCHAR(30), SMALLINT, SMALLINT, UUID);
DROP FUNCTION IF EXISTS record_action(UUID, UUID, UUID, VARCHAR(30), SMALLINT, SMALLINT);
DROP FUNCTION IF EXISTS update_stat_field(UUID, UUID, UUID, TEXT, SMALLINT);
DROP FUNCTION IF EXISTS update_stat_field(UUID, UUID, TEXT, SMALLINT);

CREATE OR REPLACE FUNCTION record_action(
  p_game_id     UUID,
  p_player_id   UUID,
  p_team_id     UUID,
  p_action_type VARCHAR(30),
  p_delta       SMALLINT DEFAULT 1,
  p_quarter     SMALLINT DEFAULT 1,
  p_recorded_by UUID DEFAULT NULL   -- 前端传入当前用户 ID
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
BEGIN
  -- recorded_by：优先用参数，否则降级为 auth.uid() 或系统默认
  v_recorder := COALESCE(p_recorded_by, auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid);

  -- 1. 写入 action_logs
  INSERT INTO action_logs (game_id, player_id, team_id, action_type, delta, quarter, recorded_by)
  VALUES (p_game_id, p_player_id, p_team_id, p_action_type, p_delta, p_quarter, v_recorder)
  RETURNING id INTO v_log_id;

  -- 2. 映射 action_type → game_stats 字段
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

  -- 3. 更新 game_stats（动态字段）
  IF v_field IS NOT NULL THEN
    SELECT id INTO v_stat_id
    FROM game_stats
    WHERE game_id = p_game_id AND player_id = p_player_id;

    IF v_stat_id IS NOT NULL THEN
      EXECUTE format(
        'UPDATE game_stats SET %I = GREATEST(0, COALESCE(%I, 0) + $1), updated_at = NOW() WHERE id = $2',
        v_field, v_field
      ) USING p_delta, v_stat_id;
    ELSE
      EXECUTE format(
        'INSERT INTO game_stats (game_id, player_id, team_id, game_type, %I)
         VALUES ($1, $2, $3, (SELECT game_type FROM games WHERE id = $1), GREATEST(0, $4))',
        v_field
      ) USING p_game_id, p_player_id, p_team_id, p_delta;
    END IF;

    -- 罚球/两分/三分同时更新命中数
    IF p_action_type = 'pts_1' THEN
      PERFORM update_stat_field(p_game_id, p_player_id, p_team_id, 'ftm', p_delta);
    ELSIF p_action_type = 'pts_2' THEN
      PERFORM update_stat_field(p_game_id, p_player_id, p_team_id, 'fgm', p_delta);
    ELSIF p_action_type = 'pts_3' THEN
      PERFORM update_stat_field(p_game_id, p_player_id, p_team_id, 'fg3m', p_delta);
    END IF;
  END IF;

  -- 4. 如果是得分动作，更新比分
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

  -- 返回结果
  RETURN jsonb_build_object(
    'success', true,
    'log_id', v_log_id,
    'action_type', p_action_type,
    'delta', p_delta
  );
END;
$$;

-- 辅助函数：更新 game_stats 的某个字段
CREATE OR REPLACE FUNCTION update_stat_field(
  p_game_id   UUID,
  p_player_id UUID,
  p_team_id   UUID,
  p_field     TEXT,
  p_delta     SMALLINT
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_existing_team_id UUID;
BEGIN
  -- 获取已有的 team_id（如果记录存在的话）
  SELECT team_id INTO v_existing_team_id
  FROM game_stats
  WHERE game_id = p_game_id AND player_id = p_player_id
  LIMIT 1;

  EXECUTE format(
    'INSERT INTO game_stats (game_id, player_id, team_id, game_type, %I)
     VALUES ($1, $2, $3, (SELECT game_type FROM games WHERE id = $1), GREATEST(0, $5))
     ON CONFLICT (game_id, player_id) DO UPDATE
       SET %I = GREATEST(0, COALESCE(game_stats.%I, 0) + $5),
           updated_at = NOW()',
    p_field, p_field, p_field
  )
  USING p_game_id, p_player_id, COALESCE(v_existing_team_id, p_team_id), NULL, p_delta;
END;
$$;

-- ============================================================
-- update_game_status RPC：更新比赛状态（绕过 RLS）
-- 用于开始/结束比赛等状态变更
-- ============================================================
CREATE OR REPLACE FUNCTION update_game_status(
  p_game_id   UUID,
  p_status    VARCHAR(20),
  p_started_at TIMESTAMPTZ DEFAULT NULL,
  p_finished_at TIMESTAMPTZ DEFAULT NULL
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE games SET
    status = p_status,
    started_at = COALESCE(p_started_at, started_at),
    finished_at = COALESCE(p_finished_at, finished_at)
  WHERE id = p_game_id;
END;
$$;

-- ============================================================
-- swap_player RPC：换人操作（绕过 RLS）
-- p_mode: 'add' 添加球员到阵容 / 'remove' 将球员移出阵容
-- ============================================================
CREATE OR REPLACE FUNCTION swap_player(
  p_game_id   UUID,
  p_team_id   UUID,
  p_player_id UUID,
  p_slot_no   SMALLINT DEFAULT NULL,
  p_mode      VARCHAR(10) DEFAULT 'add'  -- 'add' or 'remove'
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_lineup_id UUID;
  v_result    JSONB;
BEGIN
  IF p_mode = 'add' THEN
    -- 添加球员到阵容
    INSERT INTO game_lineup (game_id, team_id, player_id, slot_no, quarter, on_at, is_current)
    VALUES (p_game_id, p_team_id, p_player_id, COALESCE(p_slot_no, 1), 1, NOW(), true)
    RETURNING id INTO v_lineup_id;

    v_result := jsonb_build_object('success', true, 'mode', 'add', 'lineup_id', v_lineup_id);

  ELSIF p_mode = 'remove' THEN
    -- 将球员移出阵容
    UPDATE game_lineup
    SET is_current = false, off_at = NOW()
    WHERE game_id = p_game_id
      AND team_id = p_team_id
      AND player_id = p_player_id
      AND is_current = true
    RETURNING id INTO v_lineup_id;

    IF v_lineup_id IS NULL THEN
      RAISE EXCEPTION '该球员不在上场阵容中';
    END IF;

    v_result := jsonb_build_object('success', true, 'mode', 'remove', 'lineup_id', v_lineup_id);
  ELSE
    RAISE EXCEPTION '无效的模式：%', p_mode;
  END IF;

  RETURN v_result;
END;
$$;
