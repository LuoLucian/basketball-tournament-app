-- ============================================================
-- 清理测试数据重跑产生的重复赛果公告
-- 原因：模拟脚本第一次运行在季军赛处中断，重跑时已结束的
--       14 场比赛重复触发了赛果播报（内容完全相同的第二条）
-- 策略：同一锦标赛内 content 相同的公告，保留最早一条，删除后来重复的
-- 在 Supabase SQL Editor 中执行
-- ============================================================

DELETE FROM tournament_announcements a
USING tournament_announcements b
WHERE a.tournament_id = b.tournament_id
  AND a.type = b.type
  AND a.content = b.content
  AND a.created_at > b.created_at;

-- 验证：应剩 47 条（8抽签 + 2赛程 + 16开赛 + 16赛果 + 4晋级 + 1冠军）
SELECT type, count(*) AS cnt
FROM tournament_announcements
GROUP BY type ORDER BY type;
