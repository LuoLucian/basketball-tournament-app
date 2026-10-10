-- ============================================================
-- 清理测试数据：测试锦标赛 + 测试4队 + 独占球员 + 孤儿比赛
-- 在 Supabase SQL Editor 中整体执行
-- 保留：娱乐赛 ×2、[123/德泰/瑞波/金浠科技/联合小舰队/英泰/英泰联合队/启元智控(f6f5ff4b)]
-- ============================================================

BEGIN;

-- ══ 1. 测试锦标赛（announcements 由 tournament 级联，这里显式删子表兜底）═══
DELETE FROM tournament_announcements WHERE tournament_id = 'ccabacea-5783-486c-8ce3-498ea2e3b2e3';
DELETE FROM tournament_teams       WHERE tournament_id = 'ccabacea-5783-486c-8ce3-498ea2e3b2e3';
DELETE FROM tournament_matches     WHERE tournament_id = 'ccabacea-5783-486c-8ce3-498ea2e3b2e3';
DELETE FROM tournaments            WHERE id = 'ccabacea-5783-486c-8ce3-498ea2e3b2e3';

-- ══ 2. 孤儿/测试比赛（标题含【测试】、德泰杯、德泰科技园前缀，均非娱乐赛）═══
CREATE TEMP TABLE tmp_delete_games AS
SELECT id FROM games
WHERE title LIKE '%【测试】%' OR title LIKE '德泰杯%' OR title LIKE '德泰科技园%';

DELETE FROM game_stats      WHERE game_id IN (SELECT id FROM tmp_delete_games);
DELETE FROM game_lineup     WHERE game_id IN (SELECT id FROM tmp_delete_games);
DELETE FROM game_mvp        WHERE game_id IN (SELECT id FROM tmp_delete_games);
DELETE FROM game_recorders  WHERE game_id IN (SELECT id FROM tmp_delete_games);
DELETE FROM action_logs     WHERE game_id IN (SELECT id FROM tmp_delete_games);
DELETE FROM games           WHERE id    IN (SELECT id FROM tmp_delete_games);

-- ══ 3. 测试4队的球员关联（共享球员的关联仅随队删，球员本体保留）═══
CREATE TEMP TABLE tmp_test_teams AS
SELECT id FROM teams WHERE id IN (
  '5236887a-8e7c-44b7-8316-c9fed9321dc7',  -- 启元智控
  'aa24812c-0314-4065-9177-8f8b55e7db90',  -- 晨曦电子
  '37a39788-55be-4ad7-978a-ce2b4a161818',  -- 中科云谷
  '70327dcf-d630-49d3-bf12-a89934c05c9f'   -- 瑞波光电
);

CREATE TEMP TABLE tmp_test_members AS
SELECT DISTINCT player_id FROM team_players WHERE team_id IN (SELECT id FROM tmp_test_teams);

-- 找出只属于测试队、不在任何保留队中的球员 = 可删除的独占球员
CREATE TEMP TABLE tmp_solo_players AS
SELECT m.player_id FROM tmp_test_members m
WHERE NOT EXISTS (
  SELECT 1 FROM team_players tp
  JOIN tmp_test_teams tt ON tt.id = tp.team_id
  WHERE tp.player_id = m.player_id
)
AND NOT EXISTS (
  SELECT 1 FROM team_players tp
  WHERE tp.player_id = m.player_id
    AND tp.team_id NOT IN (SELECT id FROM tmp_test_teams)
);

DELETE FROM team_players WHERE team_id IN (SELECT id FROM tmp_test_teams);
DELETE FROM game_stats    WHERE player_id IN (SELECT player_id FROM tmp_solo_players);
DELETE FROM game_lineup   WHERE player_id IN (SELECT player_id FROM tmp_solo_players);
DELETE FROM game_mvp      WHERE player_id IN (SELECT player_id FROM tmp_solo_players);
DELETE FROM players       WHERE id IN (SELECT player_id FROM tmp_solo_players);
DELETE FROM teams         WHERE id IN (SELECT id FROM tmp_test_teams);

DROP TABLE tmp_delete_games, tmp_test_teams, tmp_test_members, tmp_solo_players;

COMMIT;

-- ══ 验证 ══
SELECT 'tournaments' AS item, count(*) FROM tournaments
UNION ALL SELECT 'teams', count(*) FROM teams
UNION ALL SELECT 'players', count(*) FROM players
UNION ALL SELECT 'games', count(*) FROM games;