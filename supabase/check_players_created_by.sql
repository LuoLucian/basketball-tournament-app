-- 检查 players 表是否有 created_by 字段
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'public' AND table_name = 'players' 
AND column_name = 'created_by';

-- 如果没有则添加
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'players' AND column_name = 'created_by'
  ) THEN
    ALTER TABLE public.players ADD COLUMN created_by uuid;
    RAISE NOTICE '已添加 created_by 字段';
  END IF;
END $$;

-- 验证字段存在
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'public' AND table_name = 'players' 
AND column_name = 'created_by';

SELECT 'created_by 字段已就绪' as result;
