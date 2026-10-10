-- ══════════════════════════════════════════════════════════
-- 修复：game_lineup 加入 paused_ms_at_on 字段
--       swap_player RPC 上场时自动记录当前 total_paused_ms
-- 背景：球员上场时需要记录此时比赛的累计暂停毫秒数，
--       教练视角才能正确扣除暂停时间，让计时从0开始走动
-- ══════════════════════════════════════════════════════════

-- 第1步：game_lineup 表加字段
ALTER TABLE game_lineup
  ADD COLUMN IF NOT EXISTS paused_ms_at_on BIGINT DEFAULT 0;

-- 第2步：删除旧版 swap_player（清除所有重载）
DO $$ DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT proname, oid
    FROM pg_proc
    WHERE proname = 'swap_player' AND pronamespace = 'public'::regnamespace
  LOOP
    EXECUTE 'DROP FUNCTION IF EXISTS public.' || quote_ident(r.proname)
      || '(' || pg_get_function_identity_arguments(r.oid) || ')';
  END LOOP;
END $$;

-- 第3步：重建 swap_player，add 模式自动读取 total_paused_ms 并写入
CREATE OR REPLACE FUNCTION public.swap_player(
  p_game_id   UUID,
  p_team_id   UUID,
  p_player_id UUID,
  p_slot_no   INTEGER DEFAULT NULL,
  p_mode      TEXT    DEFAULT 'add'
) RETURNS JSON AS $$
DECLARE
  v_lineup_id       UUID;
  v_existing        UUID;
  v_paused_ms_at_on BIGINT;
  v_quarter         SMALLINT;
BEGIN
  SET search_path = public;

  IF p_mode = 'add' THEN
    -- 幂等检查：如果该球员已有 is_current=true 的记录，直接返回（防重复上场）
    SELECT id INTO v_existing
    FROM game_lineup
    WHERE game_id = p_game_id
      AND player_id = p_player_id
      AND is_current = TRUE
    LIMIT 1;

    IF v_existing IS NOT NULL THEN
      -- 已在场，只更新 slot_no
      UPDATE game_lineup
         SET slot_no = COALESCE(p_slot_no, slot_no)
       WHERE id = v_existing;
      RETURN json_build_object('lineup_id', v_existing);
    END IF;

    -- 从 games 表读取当前累计暂停毫秒数和节数
    SELECT
      COALESCE(total_paused_ms, 0),
      COALESCE(current_quarter, 1)
    INTO v_paused_ms_at_on, v_quarter
    FROM games
    WHERE id = p_game_id;

    -- 如果当前正在暂停中，还要加上本次暂停已经过去的时间
    -- （这样暂停期间换人的球员，上场后等比赛继续才开始计时）
    SELECT v_paused_ms_at_on
         + COALESCE(
             FLOOR(EXTRACT(EPOCH FROM (NOW() - paused_at)) * 1000),
             0
           )
    INTO v_paused_ms_at_on
    FROM games
    WHERE id = p_game_id
      AND is_paused = TRUE
      AND paused_at IS NOT NULL;

    -- 如果不在暂停中，上面 SELECT 不会改变 v_paused_ms_at_on，保持原值

    -- 插入新的上场记录
    INSERT INTO game_lineup (
      game_id, team_id, player_id, slot_no,
      is_current, on_at, quarter, paused_ms_at_on
    )
    VALUES (
      p_game_id, p_team_id, p_player_id, p_slot_no,
      TRUE, NOW(), v_quarter, COALESCE(v_paused_ms_at_on, 0)
    )
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

-- 验证
SELECT
  proname,
  pg_get_function_identity_arguments(oid) AS args
FROM pg_proc
WHERE proname = 'swap_player'
  AND pronamespace = 'public'::regnamespace;
