-- 查看所有 add_player 函数
SELECT p.proname, pg_get_function_arguments(p.oid) as args
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' AND p.proname = 'add_player';

-- 删除所有 add_player 函数
DO $$
DECLARE
    func_oid oid;
BEGIN
    FOR func_oid IN 
        SELECT p.oid
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' AND p.proname = 'add_player'
    LOOP
        EXECUTE 'DROP FUNCTION ' || func_oid::regprocedure;
    END LOOP;
END $$;

-- 重新创建 add_player 函数
CREATE OR REPLACE FUNCTION public.add_player(
  p_name text,
  p_position text DEFAULT NULL,
  p_height integer DEFAULT NULL,
  p_weight integer DEFAULT NULL,
  p_skills text DEFAULT NULL,
  p_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_player_id uuid;
  v_current_user_id uuid;
BEGIN
  v_current_user_id := auth.uid();
  
  INSERT INTO public.players (
    name, position, height, weight, skills, notes, 
    is_active, created_by
  ) VALUES (
    p_name, p_position, p_height, p_weight, p_skills, p_notes,
    true, v_current_user_id
  )
  RETURNING id INTO v_player_id;

  RETURN jsonb_build_object(
    'success', true,
    'player_id', v_player_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_player TO authenticated;

SELECT 'add_player 已修复！' as result;
