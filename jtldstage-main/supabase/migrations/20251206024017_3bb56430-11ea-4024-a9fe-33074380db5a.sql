-- Phase 3: Update all RPC functions to use new authorization architecture
-- First DROP functions with changed return types, then recreate

-- ============================================
-- DROP FUNCTIONS WITH CHANGED RETURN TYPES
-- ============================================
DROP FUNCTION IF EXISTS public.agent_get_project_metadata_with_token(uuid, uuid);

-- ============================================
-- PROJECT-BASED FUNCTIONS (9 functions)
-- ============================================

-- 1. agent_get_artifacts_with_token (READ → viewer)
CREATE OR REPLACE FUNCTION public.agent_get_artifacts_with_token(p_project_id uuid, p_token uuid, p_search_term text DEFAULT NULL)
RETURNS TABLE(id uuid, ai_title text, ai_summary text, content text, source_type text, created_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM public.require_role(p_project_id, p_token, 'viewer');

  RETURN QUERY
    SELECT a.id, a.ai_title, a.ai_summary, a.content, a.source_type, a.created_at
    FROM public.artifacts a
    WHERE a.project_id = p_project_id
      AND (p_search_term IS NULL OR 
           a.content ILIKE '%' || p_search_term || '%' OR
           a.ai_title ILIKE '%' || p_search_term || '%')
    ORDER BY a.created_at DESC;
END;
$function$;

-- 2. agent_get_canvas_summary_with_token (READ → viewer)
CREATE OR REPLACE FUNCTION public.agent_get_canvas_summary_with_token(p_project_id uuid, p_token uuid)
RETURNS TABLE(nodes_count integer, edges_count integer, layers_count integer, node_types jsonb, nodes jsonb, edges jsonb)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM public.require_role(p_project_id, p_token, 'viewer');

  RETURN QUERY
    SELECT
      (SELECT count(*)::integer FROM canvas_nodes WHERE project_id = p_project_id),
      (SELECT count(*)::integer FROM canvas_edges WHERE project_id = p_project_id),
      (SELECT count(*)::integer FROM canvas_layers WHERE project_id = p_project_id),
      (SELECT jsonb_object_agg(type, cnt) FROM (
        SELECT type, count(*) as cnt FROM canvas_nodes WHERE project_id = p_project_id GROUP BY type
      ) t),
      (SELECT jsonb_agg(jsonb_build_object('id', id, 'type', type, 'data', data)) FROM canvas_nodes WHERE project_id = p_project_id),
      (SELECT jsonb_agg(jsonb_build_object('id', id, 'source_id', source_id, 'target_id', target_id, 'label', label)) FROM canvas_edges WHERE project_id = p_project_id);
END;
$function$;

-- 3. agent_get_project_metadata_with_token (READ → viewer) - recreated after drop
CREATE OR REPLACE FUNCTION public.agent_get_project_metadata_with_token(p_project_id uuid, p_token uuid)
RETURNS TABLE(id uuid, name text, description text, organization text, budget numeric, scope text, status text, priority text, timeline_start date, timeline_end date, selected_model text, max_tokens integer, thinking_enabled boolean, thinking_budget integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM public.require_role(p_project_id, p_token, 'viewer');

  RETURN QUERY
    SELECT p.id, p.name, p.description, p.organization, p.budget, p.scope, p.status::text, p.priority, p.timeline_start, p.timeline_end, p.selected_model, p.max_tokens, p.thinking_enabled, p.thinking_budget
    FROM public.projects p
    WHERE p.id = p_project_id;
END;
$function$;

-- 4. agent_get_tech_stacks_with_token (READ → viewer)
CREATE OR REPLACE FUNCTION public.agent_get_tech_stacks_with_token(p_project_id uuid, p_token uuid)
RETURNS TABLE(id uuid, name text, description text, type text, parent_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM public.require_role(p_project_id, p_token, 'viewer');

  RETURN QUERY
    SELECT ts.id, ts.name, ts.description, ts.type, ts.parent_id
    FROM public.tech_stacks ts
    INNER JOIN public.project_tech_stacks pts ON pts.tech_stack_id = ts.id
    WHERE pts.project_id = p_project_id;
END;
$function$;

-- 5. agent_search_files_with_token (READ → viewer)
CREATE OR REPLACE FUNCTION public.agent_search_files_with_token(p_project_id uuid, p_token uuid, p_keyword text)
RETURNS TABLE(id uuid, path text, content text, match_type text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM public.require_role(p_project_id, p_token, 'viewer');

  RETURN QUERY
    SELECT rf.id, rf.path, rf.content, 'content'::text as match_type
    FROM public.repo_files rf
    WHERE rf.project_id = p_project_id
      AND (rf.path ILIKE '%' || p_keyword || '%' OR rf.content ILIKE '%' || p_keyword || '%')
    UNION ALL
    SELECT rs.id, rs.file_path as path, rs.new_content as content, 'staged'::text as match_type
    FROM public.repo_staging rs
    WHERE rs.project_id = p_project_id
      AND rs.operation_type IN ('add', 'edit')
      AND (rs.file_path ILIKE '%' || p_keyword || '%' OR rs.new_content ILIKE '%' || p_keyword || '%');
END;
$function$;

-- 6. agent_search_requirements_with_token (READ → viewer)
CREATE OR REPLACE FUNCTION public.agent_search_requirements_with_token(p_project_id uuid, p_token uuid, p_search_term text DEFAULT NULL)
RETURNS TABLE(id uuid, code text, title text, content text, type text, parent_id uuid, order_index integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM public.require_role(p_project_id, p_token, 'viewer');

  RETURN QUERY
    SELECT r.id, r.code, r.title, r.content, r.type::text, r.parent_id, r.order_index
    FROM public.requirements r
    WHERE r.project_id = p_project_id
      AND (p_search_term IS NULL OR 
           r.title ILIKE '%' || p_search_term || '%' OR
           r.content ILIKE '%' || p_search_term || '%' OR
           r.code ILIKE '%' || p_search_term || '%')
    ORDER BY r.order_index;
END;
$function$;

-- 7. agent_search_standards_with_token (READ → viewer)
CREATE OR REPLACE FUNCTION public.agent_search_standards_with_token(p_project_id uuid, p_token uuid, p_search_term text DEFAULT NULL)
RETURNS TABLE(id uuid, code text, title text, description text, content text, category_id uuid, category_name text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM public.require_role(p_project_id, p_token, 'viewer');

  RETURN QUERY
    SELECT s.id, s.code, s.title, s.description, s.content, s.category_id, sc.name as category_name
    FROM public.standards s
    INNER JOIN public.project_standards ps ON ps.standard_id = s.id
    INNER JOIN public.standard_categories sc ON sc.id = s.category_id
    WHERE ps.project_id = p_project_id
      AND (p_search_term IS NULL OR 
           s.title ILIKE '%' || p_search_term || '%' OR
           s.content ILIKE '%' || p_search_term || '%' OR
           s.code ILIKE '%' || p_search_term || '%')
    ORDER BY s.order_index;
END;
$function$;

-- 8. agent_wildcard_search_with_token (READ → viewer)
CREATE OR REPLACE FUNCTION public.agent_wildcard_search_with_token(p_project_id uuid, p_token uuid, p_search_terms text[])
RETURNS TABLE(id uuid, path text, content_preview text, match_count integer, matched_terms text[], is_staged boolean)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM public.require_role(p_project_id, p_token, 'viewer');

  RETURN QUERY
    WITH file_matches AS (
      SELECT 
        rf.id,
        rf.path,
        LEFT(rf.content, 200) as content_preview,
        (SELECT count(*)::integer FROM unnest(p_search_terms) t WHERE rf.content ILIKE '%' || t || '%' OR rf.path ILIKE '%' || t || '%') as match_count,
        (SELECT array_agg(t) FROM unnest(p_search_terms) t WHERE rf.content ILIKE '%' || t || '%' OR rf.path ILIKE '%' || t || '%') as matched_terms,
        false as is_staged
      FROM public.repo_files rf
      WHERE rf.project_id = p_project_id
    ),
    staged_matches AS (
      SELECT 
        rs.id,
        rs.file_path as path,
        LEFT(rs.new_content, 200) as content_preview,
        (SELECT count(*)::integer FROM unnest(p_search_terms) t WHERE rs.new_content ILIKE '%' || t || '%' OR rs.file_path ILIKE '%' || t || '%') as match_count,
        (SELECT array_agg(t) FROM unnest(p_search_terms) t WHERE rs.new_content ILIKE '%' || t || '%' OR rs.file_path ILIKE '%' || t || '%') as matched_terms,
        true as is_staged
      FROM public.repo_staging rs
      WHERE rs.project_id = p_project_id
        AND rs.operation_type IN ('add', 'edit')
    )
    SELECT * FROM file_matches WHERE match_count > 0
    UNION ALL
    SELECT * FROM staged_matches WHERE match_count > 0
    ORDER BY match_count DESC;
END;
$function$;

-- 9. update_project_with_token (WRITE → editor)
CREATE OR REPLACE FUNCTION public.update_project_with_token(p_project_id uuid, p_token uuid, p_name text DEFAULT NULL, p_description text DEFAULT NULL, p_organization text DEFAULT NULL, p_budget numeric DEFAULT NULL, p_scope text DEFAULT NULL, p_status text DEFAULT NULL, p_priority text DEFAULT NULL, p_timeline_start date DEFAULT NULL, p_timeline_end date DEFAULT NULL, p_tags text[] DEFAULT NULL)
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
    budget = COALESCE(p_budget, budget),
    scope = COALESCE(p_scope, scope),
    status = COALESCE(p_status::project_status, status),
    priority = COALESCE(p_priority, priority),
    timeline_start = COALESCE(p_timeline_start, timeline_start),
    timeline_end = COALESCE(p_timeline_end, timeline_end),
    tags = COALESCE(p_tags, tags),
    updated_at = now()
  WHERE id = p_project_id
  RETURNING * INTO result;

  RETURN result;
END;
$function$;

-- ============================================
-- REPO-BASED FUNCTIONS (6 functions)
-- ============================================

-- 10. agent_list_files_by_path_with_token (READ → viewer)
CREATE OR REPLACE FUNCTION public.agent_list_files_by_path_with_token(p_repo_id uuid, p_token uuid, p_path_prefix text DEFAULT NULL)
RETURNS TABLE(id uuid, path text, repo_id uuid, updated_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_project_id uuid;
BEGIN
  v_project_id := public.get_project_id_from_repo(p_repo_id);
  PERFORM public.require_role(v_project_id, p_token, 'viewer');

  RETURN QUERY
    SELECT rf.id, rf.path, rf.repo_id, rf.updated_at
    FROM public.repo_files rf
    WHERE rf.repo_id = p_repo_id
      AND (p_path_prefix IS NULL OR rf.path LIKE p_path_prefix || '%')
    ORDER BY rf.path;
END;
$function$;

-- 11. create_file_with_token (WRITE → editor)
CREATE OR REPLACE FUNCTION public.create_file_with_token(p_repo_id uuid, p_path text, p_content text DEFAULT '', p_token uuid DEFAULT NULL)
RETURNS repo_files
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_project_id uuid;
  result public.repo_files;
BEGIN
  v_project_id := public.get_project_id_from_repo(p_repo_id);
  PERFORM public.require_role(v_project_id, p_token, 'editor');

  INSERT INTO public.repo_files (project_id, repo_id, path, content)
  VALUES (v_project_id, p_repo_id, p_path, p_content)
  RETURNING * INTO result;

  RETURN result;
END;
$function$;

-- 12. get_repo_by_id_with_token (READ → viewer)
CREATE OR REPLACE FUNCTION public.get_repo_by_id_with_token(p_repo_id uuid, p_token uuid)
RETURNS SETOF project_repos
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_project_id uuid;
BEGIN
  v_project_id := public.get_project_id_from_repo(p_repo_id);
  PERFORM public.require_role(v_project_id, p_token, 'viewer');

  RETURN QUERY SELECT * FROM public.project_repos WHERE id = p_repo_id;
END;
$function$;

-- 13. get_repo_files_with_token (READ → viewer)
CREATE OR REPLACE FUNCTION public.get_repo_files_with_token(p_repo_id uuid, p_token uuid)
RETURNS SETOF repo_files
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_project_id uuid;
BEGIN
  v_project_id := public.get_project_id_from_repo(p_repo_id);
  PERFORM public.require_role(v_project_id, p_token, 'viewer');

  RETURN QUERY
    SELECT * FROM public.repo_files
    WHERE repo_id = p_repo_id
    ORDER BY path;
END;
$function$;

-- 14. rename_folder_with_token (WRITE → editor)
CREATE OR REPLACE FUNCTION public.rename_folder_with_token(p_repo_id uuid, p_old_folder_path text, p_new_folder_path text, p_token uuid DEFAULT NULL)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_project_id uuid;
  v_count integer;
BEGIN
  v_project_id := public.get_project_id_from_repo(p_repo_id);
  PERFORM public.require_role(v_project_id, p_token, 'editor');

  UPDATE public.repo_files
  SET 
    path = p_new_folder_path || substring(path from length(p_old_folder_path) + 1),
    updated_at = now()
  WHERE repo_id = p_repo_id
    AND (path = p_old_folder_path OR path LIKE p_old_folder_path || '/%');

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$function$;

-- 15. upsert_file_with_token (WRITE → editor)
CREATE OR REPLACE FUNCTION public.upsert_file_with_token(p_repo_id uuid, p_path text, p_content text, p_token uuid DEFAULT NULL, p_is_binary boolean DEFAULT false)
RETURNS repo_files
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_project_id uuid;
  result public.repo_files;
BEGIN
  v_project_id := public.get_project_id_from_repo(p_repo_id);
  PERFORM public.require_role(v_project_id, p_token, 'editor');

  INSERT INTO public.repo_files (project_id, repo_id, path, content, is_binary)
  VALUES (v_project_id, p_repo_id, p_path, p_content, p_is_binary)
  ON CONFLICT (repo_id, path)
  DO UPDATE SET content = EXCLUDED.content, is_binary = EXCLUDED.is_binary, updated_at = now()
  RETURNING * INTO result;

  RETURN result;
END;
$function$;

-- ============================================
-- FILE-BASED FUNCTIONS (3 functions)
-- ============================================

-- 16. agent_read_file_with_token (READ → viewer)
CREATE OR REPLACE FUNCTION public.agent_read_file_with_token(p_file_id uuid, p_token uuid)
RETURNS TABLE(id uuid, path text, content text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_project_id uuid;
BEGIN
  v_project_id := public.get_project_id_from_file(p_file_id);
  PERFORM public.require_role(v_project_id, p_token, 'viewer');

  -- Return staged content if exists, otherwise committed content
  RETURN QUERY
    SELECT 
      COALESCE(rs.id, rf.id) as id,
      COALESCE(rs.file_path, rf.path) as path,
      COALESCE(rs.new_content, rf.content) as content
    FROM public.repo_files rf
    LEFT JOIN public.repo_staging rs ON rs.repo_id = rf.repo_id AND rs.file_path = rf.path AND rs.operation_type IN ('add', 'edit')
    WHERE rf.id = p_file_id
    UNION ALL
    SELECT rs.id, rs.file_path as path, rs.new_content as content
    FROM public.repo_staging rs
    WHERE rs.id = p_file_id AND rs.operation_type = 'add';
END;
$function$;

-- 17. agent_read_multiple_files_with_token (READ → viewer)
CREATE OR REPLACE FUNCTION public.agent_read_multiple_files_with_token(p_file_ids uuid[], p_token uuid)
RETURNS TABLE(id uuid, path text, content text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_file_id uuid;
  v_project_id uuid;
BEGIN
  -- Validate access for each file (they might be from different projects)
  FOREACH v_file_id IN ARRAY p_file_ids LOOP
    v_project_id := public.get_project_id_from_file(v_file_id);
    PERFORM public.require_role(v_project_id, p_token, 'viewer');
  END LOOP;

  RETURN QUERY
    SELECT 
      COALESCE(rs.id, rf.id) as id,
      COALESCE(rs.file_path, rf.path) as path,
      COALESCE(rs.new_content, rf.content) as content
    FROM public.repo_files rf
    LEFT JOIN public.repo_staging rs ON rs.repo_id = rf.repo_id AND rs.file_path = rf.path AND rs.operation_type IN ('add', 'edit')
    WHERE rf.id = ANY(p_file_ids)
    UNION ALL
    SELECT rs.id, rs.file_path as path, rs.new_content as content
    FROM public.repo_staging rs
    WHERE rs.id = ANY(p_file_ids) AND rs.operation_type = 'add';
END;
$function$;

-- 18. rename_file_with_token (WRITE → editor)
CREATE OR REPLACE FUNCTION public.rename_file_with_token(p_file_id uuid, p_new_path text, p_token uuid DEFAULT NULL)
RETURNS repo_files
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_project_id uuid;
  result public.repo_files;
BEGIN
  v_project_id := public.get_project_id_from_file(p_file_id);
  PERFORM public.require_role(v_project_id, p_token, 'editor');

  UPDATE public.repo_files
  SET path = p_new_path, updated_at = now()
  WHERE id = p_file_id
  RETURNING * INTO result;

  RETURN result;
END;
$function$;

-- ============================================
-- UPDATE REMAINING CRITICAL FUNCTIONS
-- ============================================

-- 19. get_project_with_token (READ → viewer)
CREATE OR REPLACE FUNCTION public.get_project_with_token(p_project_id uuid, p_token uuid)
RETURNS projects
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  result public.projects;
BEGIN
  PERFORM public.require_role(p_project_id, p_token, 'viewer');

  SELECT * INTO result
  FROM public.projects
  WHERE id = p_project_id;

  RETURN result;
END;
$function$;

-- 20. delete_project_with_token (ADMIN → owner only)
CREATE OR REPLACE FUNCTION public.delete_project_with_token(p_project_id uuid, p_token uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM public.require_role(p_project_id, p_token, 'owner');

  -- Delete all related data (cascading)
  DELETE FROM public.agent_blackboard WHERE session_id IN (SELECT id FROM public.agent_sessions WHERE project_id = p_project_id);
  DELETE FROM public.agent_file_operations WHERE session_id IN (SELECT id FROM public.agent_sessions WHERE project_id = p_project_id);
  DELETE FROM public.agent_messages WHERE session_id IN (SELECT id FROM public.agent_sessions WHERE project_id = p_project_id);
  DELETE FROM public.agent_session_context WHERE session_id IN (SELECT id FROM public.agent_sessions WHERE project_id = p_project_id);
  DELETE FROM public.agent_sessions WHERE project_id = p_project_id;
  DELETE FROM public.repo_commits WHERE repo_id IN (SELECT id FROM public.project_repos WHERE project_id = p_project_id);
  DELETE FROM public.repo_files WHERE repo_id IN (SELECT id FROM public.project_repos WHERE project_id = p_project_id);
  DELETE FROM public.repo_pats WHERE repo_id IN (SELECT id FROM public.project_repos WHERE project_id = p_project_id);
  DELETE FROM public.repo_staging WHERE repo_id IN (SELECT id FROM public.project_repos WHERE project_id = p_project_id);
  DELETE FROM public.project_repos WHERE project_id = p_project_id;
  DELETE FROM public.chat_messages WHERE chat_session_id IN (SELECT id FROM public.chat_sessions WHERE project_id = p_project_id);
  DELETE FROM public.chat_sessions WHERE project_id = p_project_id;
  DELETE FROM public.artifacts WHERE project_id = p_project_id;
  DELETE FROM public.canvas_edges WHERE project_id = p_project_id;
  DELETE FROM public.canvas_nodes WHERE project_id = p_project_id;
  DELETE FROM public.canvas_layers WHERE project_id = p_project_id;
  DELETE FROM public.project_specifications WHERE project_id = p_project_id;
  DELETE FROM public.project_standards WHERE project_id = p_project_id;
  DELETE FROM public.project_tech_stacks WHERE project_id = p_project_id;
  DELETE FROM public.requirement_standards WHERE requirement_id IN (SELECT id FROM public.requirements WHERE project_id = p_project_id);
  DELETE FROM public.requirements WHERE project_id = p_project_id;
  DELETE FROM public.audit_findings WHERE audit_run_id IN (SELECT id FROM public.audit_runs WHERE project_id = p_project_id);
  DELETE FROM public.audit_runs WHERE project_id = p_project_id;
  DELETE FROM public.build_sessions WHERE project_id = p_project_id;
  DELETE FROM public.activity_logs WHERE project_id = p_project_id;
  DELETE FROM public.project_tokens WHERE project_id = p_project_id;
  DELETE FROM public.projects WHERE id = p_project_id;
END;
$function$;

-- 21. regenerate_share_token (ADMIN → owner only)
CREATE OR REPLACE FUNCTION public.regenerate_share_token(p_project_id uuid, p_token uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  new_token uuid;
BEGIN
  PERFORM public.require_role(p_project_id, p_token, 'owner');

  new_token := gen_random_uuid();

  UPDATE public.projects
  SET share_token = new_token
  WHERE id = p_project_id;

  -- Also create a new project_token entry
  INSERT INTO public.project_tokens (project_id, token, role, label, created_by)
  VALUES (p_project_id, new_token, 'editor', 'Generated share token', auth.uid());

  RETURN new_token;
END;
$function$;