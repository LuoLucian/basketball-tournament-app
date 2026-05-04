-- ============================================================
-- swap_player RPC 幂等修复 + 去重 game_lineup 现有重复数据
-- 在 Supabase SQL Editor 中分段执行（每次选一段执行）
-- ============================================================

-- ── 第1段：清理现有重复数据 ─────────────────────────────────
-- 同一 (game_id, player_id) 只保留 id 最小的那条记录
DELETE FROM game_lineup a
USING game_lineup b
WHERE a.id < b.id
  AND a.game_id = b.game_id
  AND a.player_id = b.player_id;

-- ── 第2段：添加唯一约束防止未来重复 ────────────────────────
-- （必须在清理完重复数据后执行）
ALTER TABLE game_lineup
  ADD CONSTRAINT game_lineup_game_id_player_id_key UNIQUE (game_id, player_id);

-- ── 第3段：重建 swap_player（幂等版本）────────────────────
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
    -- 幂等：使用 ON CONFLICT 防止重复插入
    INSERT INTO game_lineup (game_id, team_id, player_id, slot_no)
    VALUES (p_game_id, p_team_id, p_player_id, p_slot_no)
    ON CONFLICT (game_id, player_id)
      DO UPDATE SET slot_no = EXCLUDED.slot_no
    RETURNING id INTO v_lineup_id;

    RETURN json_build_object('lineup_id', v_lineup_id)::JSON;

  ELSIF p_mode = 'remove' THEN
    -- 删除该球员在阵容中的所有记录
    DELETE FROM game_lineup
    WHERE game_id = p_game_id AND player_id = p_player_id;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
