-- 修复 1: update_game_status 加 is_paused 参数（暂停功能）
-- 修复 2: swap_player add 模式加幂等保护（防重复上场）

-- 第1步：重建 update_game_status，增加 is_paused 参数
CREATE OR REPLACE FUNCTION public.update_game_status(
  p_game_id    UUID,
  p_status     VARCHAR(20) DEFAULT NULL,
  p_started_at TIMESTAMPTZ DEFAULT NULL,
  p_finished_at TIMESTAMPTZ DEFAULT NULL,
  p_is_paused  BOOLEAN DEFAULT NULL
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE games SET
    status      = COALESCE(p_status, status),
    started_at  = COALESCE(p_started_at, started_at),
    finished_at = COALESCE(p_finished_at, finished_at),
    is_paused   = COALESCE(p_is_paused, is_paused)
  WHERE id = p_game_id;
END;
$$;

-- 第2步：重建 swap_player，add 模式加幂等保护
DO $$ DECLARE
  r RECORD;
BEGIN
  FOR r IN SELECT proname, oid FROM pg_proc WHERE proname = 'swap_player' AND pronamespace = 'public'::regnamespace
  LOOP
    EXECUTE 'DROP FUNCTION IF EXISTS public.' || quote_ident(r.proname) || '(' || pg_get_function_identity_arguments(r.oid) || ')';
  END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.swap_player(
  p_game_id   UUID,
  p_team_id   UUID,
  p_player_id UUID,
  p_slot_no   INTEGER DEFAULT NULL,
  p_mode      TEXT    DEFAULT 'add'
) RETURNS JSON AS $$
DECLARE
  v_lineup_id UUID;
  v_existing  UUID;
BEGIN
  SET search_path = public;

  IF p_mode = 'add' THEN
    -- 幂等检查：如果该球员已有 is_current=true 的记录，直接返回（防重复上场）
    SELECT id INTO v_existing FROM game_lineup
     WHERE game_id = p_game_id AND player_id = p_player_id AND is_current = TRUE
     LIMIT 1;

    IF v_existing IS NOT NULL THEN
      -- 已在场，不重复创建，只更新 slot_no
      UPDATE game_lineup SET slot_no = COALESCE(p_slot_no, slot_no)
       WHERE id = v_existing;
      RETURN json_build_object('lineup_id', v_existing);
    END IF;

    -- 插入新的上场记录
    INSERT INTO game_lineup (game_id, team_id, player_id, slot_no, is_current, on_at, quarter)
    VALUES (p_game_id, p_team_id, p_player_id, p_slot_no, TRUE, NOW(),
            COALESCE((SELECT current_quarter FROM games WHERE id = p_game_id), 1))
    RETURNING id INTO v_lineup_id;

    RETURN json_build_object('lineup_id', v_lineup_id);

  ELSIF p_mode = 'remove' THEN
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

-- 第3步：验证
SELECT proname, pg_get_function_identity_arguments(oid) as args
FROM pg_proc
WHERE proname IN ('update_game_status', 'swap_player') AND pronamespace = 'public'::regnamespace;
