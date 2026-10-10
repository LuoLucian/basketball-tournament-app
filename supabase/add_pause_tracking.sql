-- 在 games 表添加暂停追踪字段
-- paused_at: 当前暂停开始时间（null 表示未暂停）
-- total_paused_ms: 累计暂停总毫秒数

ALTER TABLE games ADD COLUMN IF NOT EXISTS paused_at TIMESTAMPTZ;
ALTER TABLE games ADD COLUMN IF NOT EXISTS total_paused_ms INTEGER DEFAULT 0;

-- 重建 update_game_status，暂停时记录 paused_at，恢复时累加 total_paused_ms
DROP FUNCTION IF EXISTS public.update_game_status(UUID, VARCHAR(20), TIMESTAMPTZ, TIMESTAMPTZ, BOOLEAN);

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
  IF p_is_paused IS NOT NULL AND p_is_paused = TRUE THEN
    -- 暂停：记录暂停开始时间
    UPDATE games SET
      status          = COALESCE(p_status, status),
      started_at      = COALESCE(p_started_at, started_at),
      finished_at     = COALESCE(p_finished_at, finished_at),
      is_paused       = TRUE,
      paused_at       = NOW()
    WHERE id = p_game_id;
  ELSIF p_is_paused IS NOT NULL AND p_is_paused = FALSE THEN
    -- 恢复：累加暂停时长到 total_paused_ms
    UPDATE games SET
      status          = COALESCE(p_status, status),
      started_at      = COALESCE(p_started_at, started_at),
      finished_at     = COALESCE(p_finished_at, finished_at),
      is_paused       = FALSE,
      total_paused_ms = total_paused_ms
        + FLOOR(EXTRACT(EPOCH FROM (NOW() - COALESCE(paused_at, NOW()))) * 1000),
      paused_at       = NULL
    WHERE id = p_game_id;
  ELSE
    UPDATE games SET
      status      = COALESCE(p_status, status),
      started_at  = COALESCE(p_started_at, started_at),
      finished_at = COALESCE(p_finished_at, finished_at),
      is_paused   = COALESCE(p_is_paused, is_paused)
    WHERE id = p_game_id;
  END IF;
END;
$$;

-- 验证
SELECT proname, pg_get_function_identity_arguments(oid) as args
FROM pg_proc
WHERE proname = 'update_game_status' AND pronamespace = 'public'::regnamespace;
