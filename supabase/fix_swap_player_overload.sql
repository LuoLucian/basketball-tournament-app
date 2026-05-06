-- ============================================================
-- 修复 swap_player 函数重载歧义
-- 错误：PGRST203 - 多个重载版本冲突，PostgreSQL 无法选择
-- 在 Supabase SQL Editor 中执行此文件（一次性全部执行）
-- ============================================================

-- 第1步：删除所有可能存在的 swap_player 重载版本
DROP FUNCTION IF EXISTS swap_player(UUID, UUID, UUID, INTEGER, TEXT);
DROP FUNCTION IF EXISTS swap_player(UUID, UUID, UUID, SMALLINT, TEXT);
DROP FUNCTION IF EXISTS swap_player(UUID, UUID, UUID, TEXT);
DROP FUNCTION IF EXISTS swap_player(UUID, UUID, UUID, INTEGER);
DROP FUNCTION IF EXISTS public.swap_player(UUID, UUID, UUID, INTEGER, TEXT);
DROP FUNCTION IF EXISTS public.swap_player(UUID, UUID, UUID, SMALLINT, TEXT);
DROP FUNCTION IF EXISTS public.swap_player(UUID, UUID, UUID, TEXT);
DROP FUNCTION IF EXISTS public.swap_player(UUID, UUID, UUID, INTEGER);

-- 第2步：确保 game_lineup 有唯一约束（如已存在则忽略）
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'game_lineup_game_id_player_id_key'
  ) THEN
    -- 先清理重复数据，只保留每个 (game_id, player_id) 的最新一条
    DELETE FROM game_lineup a
    USING game_lineup b
    WHERE a.id < b.id
      AND a.game_id = b.game_id
      AND a.player_id = b.player_id;

    ALTER TABLE game_lineup
      ADD CONSTRAINT game_lineup_game_id_player_id_key UNIQUE (game_id, player_id);
  END IF;
END $$;

-- 第3步：重建唯一一个干净的 swap_player 函数
CREATE OR REPLACE FUNCTION public.swap_player(
  p_game_id   UUID,
  p_team_id   UUID,
  p_player_id UUID,
  p_slot_no   INTEGER DEFAULT NULL,
  p_mode      TEXT    DEFAULT 'add'
) RETURNS JSON AS $$
DECLARE
  v_lineup_id UUID;
BEGIN
  SET search_path = public;

  IF p_mode = 'add' THEN
    -- 幂等插入：冲突时更新 slot_no / is_current / off_at
    INSERT INTO game_lineup (game_id, team_id, player_id, slot_no, is_current)
    VALUES (p_game_id, p_team_id, p_player_id, p_slot_no, TRUE)
    ON CONFLICT (game_id, player_id)
      DO UPDATE SET
        slot_no    = EXCLUDED.slot_no,
        team_id    = EXCLUDED.team_id,
        is_current = TRUE,
        off_at     = NULL
    RETURNING id INTO v_lineup_id;

    RETURN json_build_object('lineup_id', v_lineup_id);

  ELSIF p_mode = 'remove' THEN
    -- 标记下场（保留历史记录）
    UPDATE game_lineup
       SET is_current = FALSE,
           off_at     = NOW()
     WHERE game_id   = p_game_id
       AND player_id = p_player_id
       AND is_current = TRUE;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
