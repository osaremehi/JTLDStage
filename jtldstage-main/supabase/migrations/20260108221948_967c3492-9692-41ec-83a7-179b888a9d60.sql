-- Drop the older version with validate_project_access
DROP FUNCTION IF EXISTS public.insert_requirement_standard_with_token(uuid, uuid, uuid, text);

-- Update the newer version to accept optional p_notes parameter
CREATE OR REPLACE FUNCTION public.insert_requirement_standard_with_token(
  p_requirement_id uuid, 
  p_token uuid, 
  p_standard_id uuid,
  p_notes text DEFAULT NULL
)
RETURNS requirement_standards
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_project_id uuid;
  v_result public.requirement_standards;
BEGIN
  SELECT project_id INTO v_project_id FROM public.requirements WHERE id = p_requirement_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Requirement not found';
  END IF;
  PERFORM public.require_role(v_project_id, p_token, 'editor');
  INSERT INTO public.requirement_standards (requirement_id, standard_id, notes)
  VALUES (p_requirement_id, p_standard_id, p_notes)
  ON CONFLICT (requirement_id, standard_id) DO NOTHING
  RETURNING * INTO v_result;
  RETURN v_result;
END;
$function$;