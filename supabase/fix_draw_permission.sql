-- ============================================================
-- 抽签权限收紧：draw_lottery 仅本队队员可抽（超管可代抽），
--                draw_groups（一键代抽）仅超管可用
-- 在 Supabase SQL Editor 中整体执行（可重复执行，幂等）
-- 说明：
--   应用为自定义认证（无 Supabase 会话，auth.uid() 恒为 NULL），
--   因此前端调用时显式传 p_user_id，函数内回退 auth.uid() 后校验：
--   1) super_admin → 可为任意球队代抽
--   2) 其他角色 → 必须是该队"队员"：
--      players.user_id 直接绑定，或球员姓名 = 账号用户名/显示名
--      （球员-账号绑定目前无界面，姓名匹配为零配置方案）
-- ============================================================

-- ══ 0. 删除旧签名（改参数个数不会覆盖旧函数，必须先 DROP，
--        否则旧的无校验版本仍可被调用）═══════════════════
DROP FUNCTION IF EXISTS draw_lottery(UUID, UUID, VARCHAR);
DROP FUNCTION IF EXISTS draw_groups(UUID);

-- ══ 1. draw_lottery 增加身份校验 ══════════════════════════
CREATE OR REPLACE FUNCTION draw_lottery(
  p_tournament_id UUID,
  p_team_id       UUID,
  p_drawer_name   VARCHAR(100) DEFAULT NULL,   -- 抽签人姓名（播报用）
  p_user_id       UUID          DEFAULT NULL    -- 抽签操作者账号 id
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_group_count INT;
  v_total INT;
  v_drawn INT;
  v_capacity INT;
  v_team_name TEXT;
  v_group VARCHAR(4);
  v_slot_no INT;
  v_full_groups TEXT[];
  v_user UUID;
  v_username TEXT;
  v_display_name TEXT;
  v_role TEXT;
BEGIN
  SELECT name, group_count INTO v_team_name, v_group_count
  FROM tournaments WHERE id = p_tournament_id;
  IF v_team_name IS NULL THEN RAISE EXCEPTION '锦标赛不存在'; END IF;

  -- ── 身份校验：本队队员 或 超管 ──
  v_user := COALESCE(p_user_id, auth.uid());
  IF v_user IS NULL THEN RAISE EXCEPTION '请先登录后再抽签'; END IF;
  SELECT username, display_name, role INTO v_username, v_display_name, v_role
  FROM profiles WHERE id = v_user AND is_active;
  IF v_username IS NULL THEN RAISE EXCEPTION '账号不存在或已停用'; END IF;
  IF v_role <> 'super_admin' THEN
    IF NOT EXISTS (
      SELECT 1
      FROM team_players tp
      JOIN players pl ON pl.id = tp.player_id
      WHERE tp.team_id = p_team_id
        AND tp.is_active
        AND (pl.user_id = v_user
             OR pl.name = v_username
             OR (v_display_name IS NOT NULL AND pl.name = v_display_name))
    ) THEN
      RAISE EXCEPTION '权限不足：仅本队队员可抽签（超管可代抽）';
    END IF;
  END IF;

  SELECT count(*) INTO v_total FROM tournament_teams WHERE tournament_id = p_tournament_id;
  SELECT count(*) INTO v_drawn FROM tournament_teams
    WHERE tournament_id = p_tournament_id AND group_name IS NOT NULL;
  IF v_drawn >= v_total THEN RAISE EXCEPTION '全部球队已完成抽签'; END IF;
  IF EXISTS (SELECT 1 FROM tournament_matches WHERE tournament_id = p_tournament_id AND stage = 'group') THEN
    RAISE EXCEPTION '赛程已生成，无法抽签';
  END IF;

  -- 该队是否已抽
  IF EXISTS (SELECT 1 FROM tournament_teams
             WHERE tournament_id = p_tournament_id AND team_id = p_team_id AND group_name IS NOT NULL) THEN
    RAISE EXCEPTION '该球队已完成抽签';
  END IF;

  -- 每组容量 = ceil(总数/组数)，从未满的组里随机抽一个
  v_capacity := CEIL(v_total::numeric / v_group_count)::INT;
  SELECT array_agg(group_name) INTO v_full_groups
  FROM (
    SELECT group_name, count(*) AS cnt
    FROM tournament_teams
    WHERE tournament_id = p_tournament_id AND group_name IS NOT NULL
    GROUP BY group_name
    HAVING count(*) >= v_capacity
  ) x;
  IF v_full_groups IS NULL OR array_length(v_full_groups, 1) = 0 THEN
    v_full_groups := ARRAY['__none__'];
  END IF;

  SELECT g.name INTO v_group
  FROM unnest((ARRAY['A','B','C','D'])[1:LEAST(v_group_count, 4)]) AS g(name)
  WHERE g.name <> ALL(v_full_groups)
  ORDER BY random()
  LIMIT 1;
  IF v_group IS NULL THEN v_group := 'A'; END IF;

  -- 组内号位 = 该组已有数量 + 1
  SELECT count(*) + 1 INTO v_slot_no
  FROM tournament_teams
  WHERE tournament_id = p_tournament_id AND group_name = v_group;

  UPDATE tournament_teams
  SET group_name = v_group,
      draw_order = v_drawn + 1,
      drawn_at = NOW()
  WHERE tournament_id = p_tournament_id AND team_id = p_team_id;

  -- 公告播报（超管代抽时标注身份）
  PERFORM add_tournament_announcement(p_tournament_id, 'draw',
    COALESCE('🎉 ' || NULLIF(p_drawer_name, '') ||
             CASE WHEN v_role = 'super_admin' THEN '（超管代抽）代表 ' ELSE ' 代表 ' END, '🎉 ') ||
    v_team_name || ' 抽签：' ||
    CASE WHEN v_group_count = 1 THEN '抽中 ' || v_slot_no || ' 号签位！'
         ELSE '抽中 ' || v_group || ' 组 ' || v_slot_no || ' 号位！' END);

  -- 全部抽完 → 自动生成赛程
  IF v_drawn + 1 >= v_total THEN
    PERFORM generate_group_schedule(p_tournament_id);
  END IF;

  RETURN jsonb_build_object('success', true, 'group_name', v_group, 'slot_no', v_slot_no);
END;
$$;

-- ══ 2. draw_groups（一键代抽）仅超管可用 ═══════════════════
CREATE OR REPLACE FUNCTION draw_groups(
  p_tournament_id UUID,
  p_user_id       UUID DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_rec RECORD;
  v_last JSONB;
  v_user UUID;
BEGIN
  v_user := COALESCE(p_user_id, auth.uid());
  IF v_user IS NULL OR NOT EXISTS (
    SELECT 1 FROM profiles WHERE id = v_user AND role = 'super_admin' AND is_active
  ) THEN
    RAISE EXCEPTION '权限不足：仅超管可一键代抽';
  END IF;

  IF EXISTS (SELECT 1 FROM tournament_matches WHERE tournament_id = p_tournament_id AND stage = 'group') THEN
    RAISE EXCEPTION '已生成小组赛程，无法重新抽签';
  END IF;

  FOR v_rec IN
    SELECT team_id FROM tournament_teams
    WHERE tournament_id = p_tournament_id AND group_name IS NULL
    ORDER BY random()
  LOOP
    v_last := draw_lottery(p_tournament_id, v_rec.team_id, NULL, v_user);
  END LOOP;

  IF v_last IS NULL THEN
    -- 没有未抽的球队：直接补生成赛程（幂等）
    PERFORM generate_group_schedule(p_tournament_id);
  END IF;

  RETURN jsonb_build_object('success', true,
    'match_count', (SELECT count(*) FROM tournament_matches WHERE tournament_id = p_tournament_id));
END;
$$;

-- ══ 3. 授权保持不变（anon 可调用，身份由函数内 p_user_id 校验）═══
GRANT EXECUTE ON FUNCTION draw_lottery(UUID, UUID, VARCHAR, UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION draw_groups(UUID, UUID) TO anon, authenticated;

-- 验证
SELECT proname, pg_get_function_identity_arguments(oid) AS args
FROM pg_proc
WHERE pronamespace = 'public'::regnamespace
  AND proname IN ('draw_lottery', 'draw_groups');
