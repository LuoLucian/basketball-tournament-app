-- ══════════════════════════════════════════════════════════
-- 清理测试数据：API 测试锦标赛（5cdd894b）及其 5 场测试比赛
-- 在 Supabase SQL Editor 中执行
-- ══════════════════════════════════════════════════════════
BEGIN;

-- 1. 删除锦标赛赛程（7条，含小组赛/半决赛/决赛占位）
DELETE FROM tournament_matches
WHERE tournament_id = '5cdd894b-503f-4529-ab0e-f185cc659ec7';

-- 2. 删除锦标赛-球队关联
DELETE FROM tournament_teams
WHERE tournament_id = '5cdd894b-503f-4529-ab0e-f185cc659ec7';

-- 3. 删除 5 场测试比赛及其全部关联数据（delete_game 会清理
--    action_logs / game_mvp / game_stats / game_lineup / game_recorders）
SELECT delete_game(id, '9f86fd5a-4f21-4b9a-ac67-b3d2f9dc6aca')
FROM games
WHERE id IN (
  'f259b030-77a7-4e0e-88e3-95d6ac7283c1',  -- 小组赛A第1轮 金浠科技 vs 英泰联合队
  '477ae19d-4f51-4822-b3f4-0cc9a91302b5',  -- 小组赛A第2轮 英泰 vs 英泰联合队
  '0326877d-eff6-498c-b04b-1798095abf70',  -- 小组赛A第3轮 英泰 vs 金浠科技
  '98191421-ea35-4d80-8a10-cb9835eec2d2',  -- 小组赛B第1轮 瑞波光电 vs 联合小舰队
  '651d5cd6-35df-411e-8c00-f67b0cb0de27'   -- 半决赛 英泰 vs 联合小舰队
);

-- 4. 删除测试锦标赛本身
DELETE FROM tournaments
WHERE id = '5cdd894b-503f-4529-ab0e-f185cc659ec7';

COMMIT;

-- ── 验证：以下都应返回 0 ──
SELECT 'games' AS item, count(*) FROM games
WHERE id IN (
  'f259b030-77a7-4e0e-88e3-95d6ac7283c1',
  '477ae19d-4f51-4822-b3f4-0cc9a91302b5',
  '0326877d-eff6-498c-b04b-1798095abf70',
  '98191421-ea35-4d80-8a10-cb9835eec2d2',
  '651d5cd6-35df-411e-8c00-f67b0cb0de27'
)
UNION ALL SELECT 'tournament_matches', count(*) FROM tournament_matches
WHERE tournament_id = '5cdd894b-503f-4529-ab0e-f185cc659ec7'
UNION ALL SELECT 'tournament_teams', count(*) FROM tournament_teams
WHERE tournament_id = '5cdd894b-503f-4529-ab0e-f185cc659ec7'
UNION ALL SELECT 'tournaments', count(*) FROM tournaments
WHERE id = '5cdd894b-503f-4529-ab0e-f185cc659ec7';
