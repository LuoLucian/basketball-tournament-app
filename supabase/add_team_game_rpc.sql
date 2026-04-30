-- ============================================================
-- 球队/赛事/记录员 RPC 函数（绕过 RLS）
-- 在 Supabase SQL Editor 中执行（和 add_player_rpc.sql 一起）
-- ============================================================

-- 创建球队 RPC
CREATE OR REPLACE FUNCTION add_team(
  p_name TEXT,
  p_short_name VARCHAR(20) DEFAULT NULL,
  p_color VARCHAR(7) DEFAULT '#1565c0'
) RETURNS JSONB AS $$
DECLARE
  v_team_id UUID;
BEGIN
  IF p_name IS NULL OR p_name = '' THEN
    RAISE EXCEPTION '球队名称不能为空';
  END IF;

  INSERT INTO teams (name, short_name, color)
  VALUES (p_name, p_short_name, p_color)
  RETURNING id INTO v_team_id;

  RETURN jsonb_build_object('success', true, 'team_id', v_team_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建赛事 RPC
CREATE OR REPLACE FUNCTION add_game(
  p_title TEXT,
  p_game_type VARCHAR(20) DEFAULT 'entertainment',
  p_home_team_id UUID DEFAULT NULL,
  p_away_team_id UUID DEFAULT NULL,
  p_target_score SMALLINT DEFAULT NULL,
  p_quarters SMALLINT DEFAULT NULL,
  p_quarter_seconds SMALLINT DEFAULT NULL,
  p_quarter_clock SMALLINT DEFAULT NULL,
  p_venue VARCHAR(200) DEFAULT NULL,
  p_scheduled_at TIMESTAMPTZ DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
  v_game_id UUID;
BEGIN
  IF p_title IS NULL OR p_title = '' THEN
    RAISE EXCEPTION '赛事标题不能为空';
  END IF;
  IF p_game_type NOT IN ('entertainment', 'official') THEN
    RAISE EXCEPTION '无效的赛制: %', p_game_type;
  END IF;

  INSERT INTO games (title, game_type, home_team_id, away_team_id, target_score, quarters, quarter_seconds, quarter_clock, venue, scheduled_at, notes)
  VALUES (
    p_title, p_game_type, p_home_team_id, p_away_team_id,
    p_target_score, p_quarters, p_quarter_seconds, p_quarter_clock,
    p_venue, p_scheduled_at, p_notes
  )
  RETURNING id INTO v_game_id;

  RETURN jsonb_build_object('success', true, 'game_id', v_game_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 批量指派记录员 RPC
CREATE OR REPLACE FUNCTION assign_recorders(
  p_game_id UUID,
  p_user_ids UUID[]
) RETURNS JSONB AS $$
BEGIN
  IF p_game_id IS NULL THEN
    RAISE EXCEPTION '赛事ID不能为空';
  END IF;
  IF p_user_ids IS NULL OR array_length(p_user_ids, 1) IS NULL THEN
    RETURN jsonb_build_object('success', true, 'assigned_count', 0);
  END IF;

  INSERT INTO game_recorders (game_id, user_id)
  SELECT p_game_id, unnest(p_user_ids)
  ON CONFLICT DO NOTHING;

  RETURN jsonb_build_object('success', true, 'assigned_count', array_length(p_user_ids, 1));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
