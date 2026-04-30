-- ============================================================
-- 球队管理完善：owner 字段 + CRUD RPC + 成员管理
-- 在 Supabase SQL Editor 中执行
-- ============================================================

-- ── 1. teams 表加 owner_id 字段 ──
ALTER TABLE teams ADD COLUMN IF NOT EXISTS owner_id UUID REFERENCES profiles(id) ON DELETE SET NULL;

-- 回填现有球队：把 created_by 复制到 owner_id（如果之前有创建过球队）
UPDATE teams SET owner_id = created_by WHERE owner_id IS NULL AND created_by IS NOT NULL;

-- ── 2. 修改 add_team：增加 owner_id ──
CREATE OR REPLACE FUNCTION add_team(
  p_name TEXT,
  p_short_name VARCHAR(20) DEFAULT NULL,
  p_color VARCHAR(7) DEFAULT '#1565c0',
  p_owner_id UUID DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
  v_team_id UUID;
BEGIN
  IF p_name IS NULL OR p_name = '' THEN
    RAISE EXCEPTION '球队名称不能为空';
  END IF;
  INSERT INTO teams (name, short_name, color, owner_id)
  VALUES (p_name, p_short_name, p_color, p_owner_id)
  RETURNING id INTO v_team_id;
  RETURN jsonb_build_object('success', true, 'team_id', v_team_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── 3. 编辑球队信息 ──
CREATE OR REPLACE FUNCTION update_team(
  p_team_id UUID,
  p_name TEXT DEFAULT NULL,
  p_short_name VARCHAR(20) DEFAULT NULL,
  p_color VARCHAR(7) DEFAULT NULL,
  p_description TEXT DEFAULT NULL
) RETURNS JSONB AS $$
BEGIN
  IF p_team_id IS NULL THEN
    RAISE EXCEPTION '球队ID不能为空';
  END IF;
  UPDATE teams SET
    name        = COALESCE(p_name, name),
    short_name  = p_short_name,
    color       = COALESCE(p_color, color),
    description = p_description,
    updated_at  = NOW()
  WHERE id = p_team_id;
  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── 4. 删除球队（软删除） ──
CREATE OR REPLACE FUNCTION delete_team(
  p_team_id UUID
) RETURNS JSONB AS $$
BEGIN
  IF p_team_id IS NULL THEN
    RAISE EXCEPTION '球队ID不能为空';
  END IF;
  UPDATE teams SET is_active = false, updated_at = NOW() WHERE id = p_team_id;
  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── 5. 添加球员到球队（球衣号自动分配） ──
CREATE OR REPLACE FUNCTION add_team_player(
  p_team_id UUID,
  p_player_id UUID,
  p_jersey_no SMALLINT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
  v_auto_no SMALLINT;
  v_used_nos SMALLINT[];
  v_i SMALLINT;
BEGIN
  IF p_team_id IS NULL OR p_player_id IS NULL THEN
    RAISE EXCEPTION '球队ID和球员ID不能为空';
  END IF;

  -- 如果没传球衣号，自动分配
  IF p_jersey_no IS NULL THEN
    -- 获取该队已使用的球衣号
    SELECT array_agg(tp.jersey_no) INTO v_used_nos
    FROM team_players tp
    WHERE tp.team_id = p_team_id AND tp.jersey_no IS NOT NULL AND tp.is_active = true;

    -- 从 1 开始找第一个未使用的号码
    v_i := 1;
    WHILE v_i <= 99 LOOP
      IF NOT (v_used_nos @> ARRAY[v_i]) THEN
        v_auto_no := v_i;
        EXIT;
      END IF;
      v_i := v_i + 1;
    END LOOP;

    IF v_auto_no IS NULL THEN
      v_auto_no := 99; -- 兜底
    END IF;
  ELSE
    v_auto_no := p_jersey_no;
  END IF;

  INSERT INTO team_players (team_id, player_id, jersey_no)
  VALUES (p_team_id, p_player_id, v_auto_no)
  ON CONFLICT (team_id, player_id) DO UPDATE SET
    jersey_no = COALESCE(EXCLUDED.jersey_no, team_players.jersey_no),
    is_active = TRUE,
    joined_at = CURRENT_DATE,
    left_at = NULL;
  RETURN jsonb_build_object('success', true, 'jersey_no', v_auto_no);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ── 5.5 修改球员球衣号 ──
CREATE OR REPLACE FUNCTION update_player_jersey(
  p_team_id UUID,
  p_player_id UUID,
  p_new_jersey_no SMALLINT
) RETURNS JSONB AS $$
DECLARE
  v_conflict UUID;
BEGIN
  IF p_team_id IS NULL OR p_player_id IS NULL OR p_new_jersey_no IS NULL THEN
    RAISE EXCEPTION '参数不能为空';
  END IF;

  -- 检查号码是否被队内其他球员占用
  SELECT tp.player_id INTO v_conflict
  FROM team_players tp
  WHERE tp.team_id = p_team_id AND tp.jersey_no = p_new_jersey_no
    AND tp.player_id != p_player_id AND tp.is_active = true;

  IF v_conflict IS NOT NULL THEN
    RAISE EXCEPTION '球衣号 % 已被其他球员占用', p_new_jersey_no;
  END IF;

  UPDATE team_players SET jersey_no = p_new_jersey_no
  WHERE team_id = p_team_id AND player_id = p_player_id;

  RETURN jsonb_build_object('success', true, 'jersey_no', p_new_jersey_no);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ── 6. 从球队移除球员 ──
CREATE OR REPLACE FUNCTION remove_team_player(
  p_team_id UUID,
  p_player_id UUID
) RETURNS JSONB AS $$
BEGIN
  IF p_team_id IS NULL OR p_player_id IS NULL THEN
    RAISE EXCEPTION '球队ID和球员ID不能为空';
  END IF;
  DELETE FROM team_players WHERE team_id = p_team_id AND player_id = p_player_id;
  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── 验证 ──
SELECT '球队管理 RPC 创建完成' AS status;
SELECT proname, pg_get_function_arguments(oid) AS args
FROM pg_proc WHERE proname IN ('add_team','update_team','delete_team','add_team_player','remove_team_player')
ORDER BY proname;
