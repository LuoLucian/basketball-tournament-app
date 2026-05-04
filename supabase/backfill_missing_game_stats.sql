-- ============================================================
-- 为已完成的比赛补建缺失球员的 game_stats 记录
--
-- 背景：以前已完成的比赛，没有产生任何数据的球员
--       在 game_stats 表中没有记录，导致详情页看不到这些球员
--       本脚本为这些球员补建全 0 的 game_stats 记录（含快照字段）
-- ============================================================

-- 为所有 status = 'finished' 的比赛，补建参赛但无 game_stats 记录的球员
INSERT INTO game_stats (game_id, player_id, team_id, game_type,
  pts, reb, oreb, dreb, ast, stl, blk, tov, pf, fgm, fga, fg3m, fg3a, ftm, fta, min_played,
  player_name, jersey_no, player_position, player_avatar_url, team_name, team_color)
SELECT
  g.id AS game_id,
  tp.player_id,
  tp.team_id,
  g.game_type,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  p.name,
  tp.jersey_no,
  tp.position,
  p.avatar_url,
  t.name,
  t.color
FROM games g
JOIN team_players tp ON tp.team_id IN (g.home_team_id, g.away_team_id)
  AND tp.is_active = true
JOIN players p ON p.id = tp.player_id
JOIN teams t ON t.id = tp.team_id
WHERE g.status IN ('finished', 'cancelled')
  AND NOT EXISTS (
    SELECT 1 FROM game_stats gs
    WHERE gs.game_id = g.id AND gs.player_id = tp.player_id
  );
