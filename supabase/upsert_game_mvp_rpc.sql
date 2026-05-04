-- MVP 评选写入 RPC（SECURITY DEFINER 绕过 RLS）
-- 调用方通过参数传入 player_ids、mvp_scores、winner_player_id
-- 用途：比赛结束时一次性写入所有球员的 MVP 评分，标记赢家
-- 注意：所有 RPC 必须加 SET search_path = public

CREATE OR REPLACE FUNCTION public.upsert_game_mvp(
  p_game_id        UUID,
  p_players        JSONB,   -- [{ "player_id": "uuid", "mvp_score": 12.5 }, ...]
  p_winner_id      UUID     -- MVP 获胜球员 ID
)
RETURNS VOID AS $$
BEGIN
  -- 先清理旧数据
  DELETE FROM game_mvp WHERE game_id = p_game_id;

  -- 批量插入
  INSERT INTO game_mvp (game_id, player_id, mvp_score, is_winner)
  SELECT
    p_game_id,
    (rec->>'player_id')::UUID,
    (rec->>'mvp_score')::NUMERIC(8,2),
    (rec->>'player_id')::UUID = p_winner_id
  FROM jsonb_array_elements(p_players) AS rec;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
