-- ============================================================
-- 大屏模式（投屏权限）+ 下一次球权提示 支持脚本
-- 新增内容：
--   1. profiles.can_screen      投屏权限（总管理员在「用户管理」中分配）
--   2. games.possession_home    下一次球权（TRUE=主队 / FALSE=客队 / NULL=未设置）
--   3. set_possession RPC       记录员/管理员/球队管理员切换球权（realtime 自动同步）
--   4. login_by_username        登录返回新增 can_screen 字段
-- 使用：在 Supabase SQL Editor 中完整执行本文件
-- 注意：请先执行本脚本，再发布前端，否则旧库查询会报列不存在
-- ============================================================

-- ── 1. profiles 增加投屏权限 ──
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS can_screen BOOLEAN NOT NULL DEFAULT FALSE;

-- ── 2. games 增加球权字段 ──
ALTER TABLE games ADD COLUMN IF NOT EXISTS possession_home BOOLEAN;

-- ── 3. 球权设置 RPC ──
-- 权限：本场记录员 / 管理员以上 / 两队队长（owner）
-- games 表已在 realtime publication 中，写入后所有设备自动同步
CREATE OR REPLACE FUNCTION public.set_possession(
  p_game_id UUID,
  p_home    BOOLEAN
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  g RECORD;
BEGIN
  SELECT * INTO g FROM games WHERE id = p_game_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION '比赛不存在';
  END IF;

  IF NOT (
    is_game_recorder(p_game_id)
    OR (
      auth.uid() IS NOT NULL
      AND (
        EXISTS (SELECT 1 FROM teams WHERE id = g.home_team_id AND owner_id = auth.uid())
        OR EXISTS (SELECT 1 FROM teams WHERE id = g.away_team_id AND owner_id = auth.uid())
      )
    )
  ) THEN
    RAISE EXCEPTION '无权设置球权';
  END IF;

  UPDATE games SET possession_home = p_home WHERE id = p_game_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_possession(UUID, BOOLEAN) TO authenticated;

-- ── 4. 登录 RPC 返回投屏权限（保持原逻辑，仅增加返回字段）──
CREATE OR REPLACE FUNCTION login_by_username(
  p_username TEXT,
  p_password TEXT
) RETURNS JSONB AS $$
DECLARE
  v_profile RECORD;
BEGIN
  -- 查找用户
  SELECT * INTO v_profile
  FROM profiles
  WHERE username = p_username AND is_active = TRUE;

  IF NOT FOUND THEN
    RAISE EXCEPTION '用户名不存在';
  END IF;

  -- 验证密码（使用 pgcrypto 的 crypt 函数）
  IF v_profile.password_hash IS NULL OR v_profile.password_hash = '' THEN
    RAISE EXCEPTION '该用户未设置密码';
  END IF;

  IF v_profile.password_hash != crypt(p_password, v_profile.password_hash) THEN
    RAISE EXCEPTION '密码错误';
  END IF;

  -- 返回用户信息（不含密码）
  RETURN jsonb_build_object(
    'success', true,
    'id', v_profile.id,
    'username', v_profile.username,
    'display_name', v_profile.display_name,
    'role', v_profile.role,
    'avatar_url', v_profile.avatar_url,
    'can_screen', COALESCE(v_profile.can_screen, FALSE)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── 验证（两条都应返回 1）──
SELECT 'profiles.can_screen 已添加' AS item, COUNT(*) AS ok
FROM information_schema.columns
WHERE table_name = 'profiles' AND column_name = 'can_screen'
UNION ALL
SELECT 'games.possession_home 已添加', COUNT(*)
FROM information_schema.columns
WHERE table_name = 'games' AND column_name = 'possession_home';
