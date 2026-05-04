-- ============================================================
-- 修复 swap_player：确保 is_current 字段正确处理
-- 问题：ON CONFLICT UPDATE 只更新 slot_no，未将 is_current 设为 true
-- 在 Supabase SQL Editor 中执行此文件
-- ============================================================

CREATE OR REPLACE FUNCTION swap_player(
  p_game_id  UUID,
  p_team_id  UUID,
  p_player_id UUID,
  p_slot_no  INTEGER DEFAULT NULL,
  p_mode      TEXT     DEFAULT 'add'
) RETURNS JSON AS $$
DECLARE
  v_lineup_id UUID;
BEGIN
  SET search_path = public;

  IF p_mode = 'add' THEN
    -- 幂等：如果已存在则更新 slot_no 和 is_current；否则插入
    INSERT INTO game_lineup (game_id, team_id, player_id, slot_no, is_current)
    VALUES (p_game_id, p_team_id, p_player_id, p_slot_no, TRUE)
    ON CONFLICT (game_id, player_id)
      DO UPDATE SET
        slot_no    = EXCLUDED.slot_no,
        team_id    = EXCLUDED.team_id,
        is_current = TRUE,
        off_at     = NULL
    RETURNING id INTO v_lineup_id;

    RETURN json_build_object('lineup_id', v_lineup_id)::JSON;

  ELSIF p_mode = 'remove' THEN
    -- 将球员标记为已下场（is_current = false），而不是删除记录
    -- 这样可以保留历史记录，同时 loadLineup 的 is_current=true 过滤会正确排除
    UPDATE game_lineup
    SET is_current = FALSE,
        off_at = NOW()
    WHERE game_id = p_game_id
      AND player_id = p_player_id
      AND is_current = TRUE;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
