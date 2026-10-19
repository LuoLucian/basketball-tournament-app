-- ============================================================
-- 24 秒进攻计时「可开关」支持
-- 依赖：add_shot_clock.sql（shot_clock / shot_clock_running / set_shot_clock）
-- 说明：重复执行安全（IF NOT EXISTS / CREATE OR REPLACE）
-- 使用：在 Supabase SQL Editor 中完整执行本文件后，前端开关才会真正写库
-- ============================================================

-- ── 1. games 新增开关字段 ──
-- shot_clock_enabled = FALSE 时：录入页隐藏进攻计时操作区，大屏不显示 24 秒
ALTER TABLE games ADD COLUMN IF NOT EXISTS shot_clock_enabled BOOLEAN NOT NULL DEFAULT TRUE;

-- ── 2. 开关 RPC ──
-- 权限与 set_shot_clock 一致（本场记录员 / 球队管理员 / 管理员）
-- 语义：无论开还是关，都把进攻计时置为停表 + 冻结当前剩余值，
--       避免关闭期间后台仍在走表、重新打开时出现「跳秒」。
--       重新开启后由录入页显式复位（24 秒 + 跟随比赛时钟），逻辑更可控。
CREATE OR REPLACE FUNCTION public.set_shot_clock_enabled(
  p_game_id UUID,
  p_enabled BOOLEAN
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  g           RECORD;
  v_remaining SMALLINT;
BEGIN
  SELECT * INTO g FROM games WHERE id = p_game_id FOR UPDATE;
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
    RAISE EXCEPTION '无权操作进攻时间';
  END IF;

  -- 冻结当前剩余秒数（若正在走表）
  v_remaining := COALESCE(g.shot_clock, 24);
  IF COALESCE(g.shot_clock_running, FALSE) AND g.shot_clock_updated_at IS NOT NULL THEN
    v_remaining := GREATEST(0,
      v_remaining - FLOOR(EXTRACT(EPOCH FROM (NOW() - g.shot_clock_updated_at))))::SMALLINT;
  END IF;

  UPDATE games SET
    shot_clock_enabled  = COALESCE(p_enabled, TRUE),
    shot_clock          = v_remaining,
    shot_clock_running  = FALSE,
    shot_clock_updated_at = NOW()
  WHERE id = p_game_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_shot_clock_enabled(UUID, BOOLEAN) TO anon, authenticated;

-- ── 3. 存量比赛默认开启（新增列已带 DEFAULT，这里兜底 NULL 值）──
UPDATE games SET shot_clock_enabled = TRUE WHERE shot_clock_enabled IS NULL;

-- ── 4. 验证 ──
SELECT 'games.shot_clock_enabled 已添加' AS item, COUNT(*) AS ok
FROM information_schema.columns
WHERE table_name = 'games' AND column_name = 'shot_clock_enabled'
UNION ALL
SELECT 'set_shot_clock_enabled 已创建', COUNT(*)
FROM pg_proc WHERE proname = 'set_shot_clock_enabled';
