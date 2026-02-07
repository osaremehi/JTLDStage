-- Phase 6: Final Duplicate Cleanup

-- Step 1: Drop the old 2-parameter get_artifacts_with_token overload
-- Keep only the 3-parameter version with optional p_search_term
DROP FUNCTION IF EXISTS public.get_artifacts_with_token(uuid, uuid);

-- Step 2: Drop ALL existing update_project_with_token overloads
DROP FUNCTION IF EXISTS public.update_project_with_token(uuid, uuid, text, text, text, text, numeric, text, date, date, text, text[]);
DROP FUNCTION IF EXISTS public.update_project_with_token(uuid, uuid, text, text, text, text, numeric, text, date, date, project_status, text);
DROP FUNCTION IF EXISTS public.update_project_with_token(uuid, uuid, text, text, text, text, numeric, text, date, date, project_status, text, text[]);

-- Step 3: Create single unified update_project_with_token (NO github_repo - handled by project_repos table now)
CREATE OR REPLACE FUNCTION public.update_project_with_token(
  p_project_id uuid,
  p_token uuid DEFAULT NULL,
  p_name text DEFAULT NULL,
  p_description text DEFAULT NULL,
  p_organization text DEFAULT NULL,
  p_scope text DEFAULT NULL,
  p_budget numeric DEFAULT NULL,
  p_priority text DEFAULT NULL,
  p_timeline_start date DEFAULT NULL,
  p_timeline_end date DEFAULT NULL,
  p_status project_status DEFAULT NULL,
  p_tags text[] DEFAULT NULL
)
RETURNS projects
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  result public.projects;
BEGIN
  PERFORM public.require_role(p_project_id, p_token, 'editor');

  UPDATE public.projects
  SET
    name = COALESCE(p_name, name),
    description = COALESCE(p_description, description),
    organization = COALESCE(p_organization, organization),
    scope = COALESCE(p_scope, scope),
    budget = COALESCE(p_budget, budget),
    priority = COALESCE(p_priority, priority),
    timeline_start = COALESCE(p_timeline_start, timeline_start),
    timeline_end = COALESCE(p_timeline_end, timeline_end),
    status = COALESCE(p_status, status),
    tags = COALESCE(p_tags, tags),
    updated_at = now()
  WHERE id = p_project_id
  RETURNING * INTO result;

  RETURN result;
END;
$function$;