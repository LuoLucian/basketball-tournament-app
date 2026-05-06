-- ============================================================
-- 彻底修复 swap_player 函数重载歧义 (v2)
-- 先查看所有 swap_player 版本，再全部删除并重建
-- 在 Supabase SQL Editor 中执行此文件（一次性全部执行）
-- ============================================================

-- 第0步：查看当前所有 swap_player 重载版本（调试用，不影响逻辑）
-- 执行后可在 Results 面板看到现有函数签名
SELECT p.proname, pg_get_function_arguments(p.oid) as args, pg_get_function_identity_arguments(p.oid) as identity
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'swap_player'
  AND n.nspname = 'public';

-- 第1步：暴力删除所有 swap_player（无论参数签名如何）
DO $$
DECLARE
  func_rec RECORD;
BEGIN
  FOR func_rec IN
    SELECT p.oid::regprocedure AS func_sig
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE p.proname = 'swap_player'
      AND n.nspname = 'public'
  LOOP
    EXECUTE 'DROP FUNCTION IF EXISTS ' || func_rec.func_sig || ' CASCADE';
    RAISE NOTICE 'Dropped: %', func_rec.func_sig;
  END LOOP;
END $$;

-- 第2步：确保 game_lineup 有唯一约束（如已存在则忽略）
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'game_lineup_game_id_player_id_key'
  ) THEN
    -- 先清理重复数据
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

-- 第4步：验证只有一个版本
SELECT p.proname, pg_get_function_arguments(p.oid) as args, pg_get_function_identity_arguments(p.oid) as identity
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'swap_player'
  AND n.nspname = 'public';
