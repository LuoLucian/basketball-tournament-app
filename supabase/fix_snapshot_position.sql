-- ============================================================
-- 修复 snapshot_game_players 字段名 BUG
-- 原因：SELECT 中 tp.position 未起别名，INSERT 却引用 v_rec.player_position
--       导致函数一执行就报 42703 错误，全员快照从未成功过
-- ============================================================

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
    SELECT tp.player_id, tp.team_id, tp.jersey_no, tp.position AS player_position,
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

-- 验证：应返回 success=true 及快照人数
SELECT snapshot_game_players('95b9c347-364e-4b25-9cfb-4d8e0814013d');
