-- 修复 add_player：从前端传递用户ID
DROP FUNCTION IF EXISTS public.add_player;

CREATE OR REPLACE FUNCTION public.add_player(
  p_name text,
  p_position text DEFAULT NULL,
  p_height integer DEFAULT NULL,
  p_weight integer DEFAULT NULL,
  p_skills text DEFAULT NULL,
  p_notes text DEFAULT NULL,
  p_created_by uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_player_id uuid;
BEGIN
  INSERT INTO public.players (
    name, position, height, weight, skills, notes, 
    is_active, created_by
  ) VALUES (
    p_name, p_position, p_height, p_weight, p_skills, p_notes,
    true, p_created_by
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
