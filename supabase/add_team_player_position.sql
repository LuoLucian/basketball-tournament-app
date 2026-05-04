-- ============================================================
-- team_players 表添加 position 字段
-- 球员在球队中打的位置（从球员自身位置中选一个）
-- 在 Supabase SQL Editor 中执行
-- ============================================================

-- ── 1. 添加 position 字段 ──
ALTER TABLE team_players ADD COLUMN IF NOT EXISTS position VARCHAR(20);

-- ── 2. 更新 add_team_player：支持传入位置 ──
CREATE OR REPLACE FUNCTION add_team_player(
  p_team_id   UUID,
  p_player_id  UUID,
  p_jersey_no SMALLINT DEFAULT NULL,
  p_position   VARCHAR(20) DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
  v_auto_no  SMALLINT;
  v_used_nos SMALLINT[];
  v_i        SMALLINT;
BEGIN
  IF p_team_id IS NULL OR p_player_id IS NULL THEN
    RAISE EXCEPTION '球队ID和球员ID不能为空';
  END IF;

  -- 如果没传球衣号，自动分配
  IF p_jersey_no IS NULL THEN
    SELECT array_agg(tp.jersey_no) INTO v_used_nos
    FROM team_players tp
    WHERE tp.team_id = p_team_id AND tp.jersey_no IS NOT NULL AND tp.is_active = true;

    v_i := 1;
    WHILE v_i <= 99 LOOP
      IF NOT (v_used_nos @> ARRAY[v_i]) THEN
        v_auto_no := v_i;
        EXIT;
      END IF;
      v_i := v_i + 1;
    END LOOP;

    IF v_auto_no IS NULL THEN
      v_auto_no := 99;
    END IF;
  ELSE
    v_auto_no := p_jersey_no;
  END IF;

  INSERT INTO team_players (team_id, player_id, jersey_no, position)
  VALUES (p_team_id, p_player_id, v_auto_no, p_position)
  ON CONFLICT (team_id, player_id) DO UPDATE SET
    jersey_no   = COALESCE(EXCLUDED.jersey_no, team_players.jersey_no),
    position    = COALESCE(EXCLUDED.position, team_players.position),
    is_active   = TRUE,
    joined_at   = CURRENT_DATE,
    left_at     = NULL;
  RETURN jsonb_build_object('success', true, 'jersey_no', v_auto_no);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ── 3. 单独更新球员在球队的位置 ──
CREATE OR REPLACE FUNCTION update_team_player_position(
  p_team_id    UUID,
  p_player_id  UUID,
  p_position   VARCHAR(20)
) RETURNS JSONB AS $$
BEGIN
  IF p_team_id IS NULL OR p_player_id IS NULL THEN
    RAISE EXCEPTION '参数不能为空';
  END IF;

  UPDATE team_players
  SET position = p_position,
      updated_at = NOW()
  WHERE team_id = p_team_id AND player_id = p_player_id AND is_active = true;

  RETURN jsonb_build_object('success', true, 'position', p_position);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ── 验证 ──
SELECT 'team_players.position 字段已添加，RPC 已更新' AS status;
SELECT proname, pg_get_function_arguments(oid) AS args
FROM pg_proc
WHERE proname IN ('add_team_player','update_team_player_position')
ORDER BY proname;
