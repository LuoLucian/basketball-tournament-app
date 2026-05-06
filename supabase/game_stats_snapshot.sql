-- ============================================================
-- game_stats 快照字段：冗余存储球员信息
-- 比赛结束后详情页从快照读取，不受后续球队变动影响
--
-- 新增字段：
--   player_name       VARCHAR(50)   -- 球员姓名快照
--   jersey_no         SMALLINT      -- 球衣号快照
--   player_position   VARCHAR(20)   -- 球员在球队的位置快照
--   player_avatar_url TEXT           -- 头像URL快照
--   team_name         VARCHAR(100)   -- 队伍名称快照
--   team_color        VARCHAR(7)     -- 队伍主题色快照
--
-- 执行顺序：在 add_team_player_position.sql 之后执行
-- ============================================================

-- 1. 添加快照字段
ALTER TABLE game_stats ADD COLUMN IF NOT EXISTS player_name VARCHAR(50);
ALTER TABLE game_stats ADD COLUMN IF NOT EXISTS jersey_no SMALLINT;
ALTER TABLE game_stats ADD COLUMN IF NOT EXISTS player_position VARCHAR(20);
ALTER TABLE game_stats ADD COLUMN IF NOT EXISTS player_avatar_url TEXT;
ALTER TABLE game_stats ADD COLUMN IF NOT EXISTS team_name VARCHAR(100);
ALTER TABLE game_stats ADD COLUMN IF NOT EXISTS team_color VARCHAR(7);

-- 2. 为已有 game_stats 记录补充快照数据
UPDATE game_stats
SET
  player_name = p.name,
  jersey_no = tp.jersey_no,
  player_position = tp.position,
  player_avatar_url = p.avatar_url,
  team_name = t.name,
  team_color = t.color
FROM players p, team_players tp, teams t
WHERE game_stats.player_id = p.id
  AND tp.player_id = p.id
  AND tp.team_id = game_stats.team_id
  AND tp.is_active = true
  AND t.id = game_stats.team_id
  AND game_stats.player_name IS NULL;

-- 3. 修改 record_action RPC：创建 game_stats 时自动写入快照
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
BEGIN
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
      -- 新建记录时，获取球员快照信息
      SELECT p.name, p.avatar_url INTO v_snap_name, v_snap_avatar
      FROM players p WHERE p.id = p_player_id;

      SELECT tp.jersey_no, tp.position INTO v_snap_jersey, v_snap_pos
      FROM team_players tp
      WHERE tp.player_id = p_player_id AND tp.team_id = p_team_id AND tp.is_active = true
      LIMIT 1;

      SELECT t.name, t.color INTO v_snap_team_name, v_snap_team_color
      FROM teams t WHERE t.id = p_team_id;

      EXECUTE format(
        'INSERT INTO game_stats (game_id, player_id, team_id, game_type, %I, player_name, jersey_no, player_position, player_avatar_url, team_name, team_color)
         VALUES ($1, $2, $3, (SELECT game_type FROM games WHERE id = $1), GREATEST(0, $4), $5, $6, $7, $8, $9, $10)',
        v_field
      ) USING p_game_id, p_player_id, p_team_id, p_delta,
              v_snap_name, v_snap_jersey, v_snap_pos, v_snap_avatar, v_snap_team_name, v_snap_team_color;
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

  RETURN jsonb_build_object(
    'success', true,
    'log_id', v_log_id,
    'action_type', p_action_type,
    'delta', p_delta
  );
END;
$$;

-- 4. 修改 update_stat_field RPC：新建记录时也写入快照
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
  v_snap_name VARCHAR(50);
  v_snap_jersey SMALLINT;
  v_snap_pos  VARCHAR(20);
  v_snap_avatar TEXT;
  v_snap_team_name VARCHAR(100);
  v_snap_team_color VARCHAR(7);
BEGIN
  SELECT team_id INTO v_existing_team_id
  FROM game_stats
  WHERE game_id = p_game_id AND player_id = p_player_id
  LIMIT 1;

  IF v_existing_team_id IS NOT NULL THEN
    EXECUTE format(
      'UPDATE game_stats SET %I = GREATEST(0, COALESCE(%I, 0) + $1), updated_at = NOW()
       WHERE game_id = $2 AND player_id = $3',
      p_field, p_field
    ) USING p_delta, p_game_id, p_player_id;
  ELSE
    -- 新建记录时获取快照
    SELECT p.name, p.avatar_url INTO v_snap_name, v_snap_avatar
    FROM players p WHERE p.id = p_player_id;

    SELECT tp.jersey_no, tp.position INTO v_snap_jersey, v_snap_pos
    FROM team_players tp
    WHERE tp.player_id = p_player_id AND tp.team_id = p_team_id AND tp.is_active = true
    LIMIT 1;

    SELECT t.name, t.color INTO v_snap_team_name, v_snap_team_color
    FROM teams t WHERE t.id = p_team_id;

    EXECUTE format(
      'INSERT INTO game_stats (game_id, player_id, team_id, game_type, %I, player_name, jersey_no, player_position, player_avatar_url, team_name, team_color)
       VALUES ($1, $2, $3, (SELECT game_type FROM games WHERE id = $1), GREATEST(0, $5), $6, $7, $8, $9, $10, $11)
       ON CONFLICT (game_id, player_id) DO UPDATE
         SET %I = GREATEST(0, COALESCE(game_stats.%I, 0) + $5),
             updated_at = NOW()',
      p_field, p_field, p_field
    )
    USING p_game_id, p_player_id, COALESCE(v_existing_team_id, p_team_id), NULL, p_delta,
          v_snap_name, v_snap_jersey, v_snap_pos, v_snap_avatar, v_snap_team_name, v_snap_team_color;
  END IF;
END;
$$;

-- 5. 创建快照补全 RPC：为未录入数据的参赛球员补建 game_stats 记录
-- 比赛开始时或比赛结束时调用，确保所有参赛球员都有快照
CREATE OR REPLACE FUNCTION snapshot_game_players(p_game_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INT := 0;
  v_rec RECORD;
BEGIN
  FOR v_rec IN
    SELECT tp.player_id, tp.team_id, tp.jersey_no, tp.position,
           p.name AS player_name, p.avatar_url AS player_avatar_url,
           t.name AS team_name, t.color AS team_color
    FROM team_players tp
    JOIN players p ON p.id = tp.player_id
    JOIN teams t ON t.id = tp.team_id
    WHERE tp.team_id IN (
        SELECT home_team_id FROM games WHERE id = p_game_id
        UNION
        SELECT away_team_id FROM games WHERE id = p_game_id
      )
      AND tp.is_active = true
  LOOP
    INSERT INTO game_stats (game_id, player_id, team_id, game_type, player_name, jersey_no, player_position, player_avatar_url, team_name, team_color)
    VALUES (
      p_game_id, v_rec.player_id, v_rec.team_id,
      (SELECT game_type FROM games WHERE id = p_game_id),
      v_rec.player_name, v_rec.jersey_no, v_rec.player_position, v_rec.player_avatar_url,
      v_rec.team_name, v_rec.team_color
    )
    ON CONFLICT (game_id, player_id) DO UPDATE
      SET player_name = EXCLUDED.player_name,
          jersey_no = EXCLUDED.jersey_no,
          player_position = EXCLUDED.player_position,
          player_avatar_url = EXCLUDED.player_avatar_url,
          team_name = EXCLUDED.team_name,
          team_color = EXCLUDED.team_color;
    v_count := v_count + 1;
  END LOOP;

  RETURN jsonb_build_object('success', true, 'snapshotted', v_count);
END;
$$;
