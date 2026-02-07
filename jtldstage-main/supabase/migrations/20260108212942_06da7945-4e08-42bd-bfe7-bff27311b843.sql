-- RBAC Consistency Remediation: Fix all _with_token functions to use require_role pattern
-- Drop all functions first to avoid return type conflicts

-- ============================================================================
-- DROP ALL FUNCTIONS FIRST
-- ============================================================================
DROP FUNCTION IF EXISTS public.delete_deployment_with_token(uuid, uuid);
DROP FUNCTION IF EXISTS public.update_deployment_secrets_with_token(uuid, uuid, jsonb);
DROP FUNCTION IF EXISTS public.delete_file_with_token(uuid, uuid);
DROP FUNCTION IF EXISTS public.move_file_with_token(uuid, uuid, text);
DROP FUNCTION IF EXISTS public.reset_repo_files_with_token(uuid, uuid);
DROP FUNCTION IF EXISTS public.rollback_to_commit_with_token(uuid, uuid, text);
DROP FUNCTION IF EXISTS public.upsert_files_batch_with_token(uuid, uuid, jsonb);
DROP FUNCTION IF EXISTS public.log_repo_commit_with_token(uuid, uuid, text, text, text, jsonb, boolean);
DROP FUNCTION IF EXISTS public.delete_project_repo_with_token(uuid, uuid);
DROP FUNCTION IF EXISTS public.create_agent_session_with_token(uuid, uuid, text, text);
DROP FUNCTION IF EXISTS public.add_blackboard_entry_with_token(uuid, uuid, text, text, jsonb);
DROP FUNCTION IF EXISTS public.add_session_context_with_token(uuid, uuid, text, jsonb);
DROP FUNCTION IF EXISTS public.insert_agent_message_with_token(uuid, uuid, text, text, jsonb);
DROP FUNCTION IF EXISTS public.log_agent_operation_with_token(uuid, uuid, text, text, jsonb);
DROP FUNCTION IF EXISTS public.update_agent_operation_status_with_token(uuid, uuid, text, text);
DROP FUNCTION IF EXISTS public.update_agent_session_status_with_token(uuid, uuid, text);
DROP FUNCTION IF EXISTS public.request_agent_session_abort_with_token(uuid, uuid);
DROP FUNCTION IF EXISTS public.get_agent_session_with_token(uuid, uuid);
DROP FUNCTION IF EXISTS public.get_agent_sessions_with_token(uuid, uuid);
DROP FUNCTION IF EXISTS public.get_agent_operations_with_token(uuid, uuid);
DROP FUNCTION IF EXISTS public.get_blackboard_entries_with_token(uuid, uuid);
DROP FUNCTION IF EXISTS public.get_session_context_with_token(uuid, uuid);
DROP FUNCTION IF EXISTS public.insert_requirement_standard_with_token(uuid, uuid, uuid);
DROP FUNCTION IF EXISTS public.delete_requirement_standard_with_token(uuid, uuid, uuid);
DROP FUNCTION IF EXISTS public.get_requirement_standards_with_token(uuid, uuid);

-- ============================================================================
-- PHASE 1: Fix Deployment Functions
-- ============================================================================

CREATE FUNCTION public.delete_deployment_with_token(p_deployment_id uuid, p_token uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_project_id uuid;
BEGIN
  SELECT project_id INTO v_project_id FROM public.project_deployments WHERE id = p_deployment_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Deployment not found';
  END IF;
  PERFORM public.require_role(v_project_id, p_token, 'owner');
  DELETE FROM public.project_deployments WHERE id = p_deployment_id;
END;
$function$;

CREATE FUNCTION public.update_deployment_secrets_with_token(p_deployment_id uuid, p_token uuid, p_secrets jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_project_id uuid;
BEGIN
  SELECT project_id INTO v_project_id FROM public.project_deployments WHERE id = p_deployment_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Deployment not found';
  END IF;
  PERFORM public.require_role(v_project_id, p_token, 'owner');
  UPDATE public.project_deployments
  SET secrets = p_secrets, updated_at = now()
  WHERE id = p_deployment_id;
END;
$function$;

-- ============================================================================
-- PHASE 2: Fix File/Repo Functions
-- ============================================================================

CREATE FUNCTION public.delete_file_with_token(p_file_id uuid, p_token uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_project_id uuid;
BEGIN
  v_project_id := public.get_project_id_from_file(p_file_id);
  IF v_project_id IS NULL THEN
    RAISE EXCEPTION 'File not found';
  END IF;
  PERFORM public.require_role(v_project_id, p_token, 'editor');
  DELETE FROM public.repo_files WHERE id = p_file_id;
END;
$function$;

CREATE FUNCTION public.move_file_with_token(p_file_id uuid, p_token uuid, p_new_path text)
RETURNS public.repo_files
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_project_id uuid;
  v_result public.repo_files;
BEGIN
  v_project_id := public.get_project_id_from_file(p_file_id);
  IF v_project_id IS NULL THEN
    RAISE EXCEPTION 'File not found';
  END IF;
  PERFORM public.require_role(v_project_id, p_token, 'editor');
  UPDATE public.repo_files
  SET path = p_new_path, updated_at = now()
  WHERE id = p_file_id
  RETURNING * INTO v_result;
  RETURN v_result;
END;
$function$;

CREATE FUNCTION public.reset_repo_files_with_token(p_repo_id uuid, p_token uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_project_id uuid;
BEGIN
  v_project_id := public.get_project_id_from_repo(p_repo_id);
  IF v_project_id IS NULL THEN
    RAISE EXCEPTION 'Repository not found';
  END IF;
  PERFORM public.require_role(v_project_id, p_token, 'owner');
  DELETE FROM public.repo_staging WHERE repo_id = p_repo_id;
  DELETE FROM public.repo_files WHERE repo_id = p_repo_id;
  DELETE FROM public.repo_commits WHERE repo_id = p_repo_id;
END;
$function$;

CREATE FUNCTION public.rollback_to_commit_with_token(p_repo_id uuid, p_token uuid, p_commit_sha text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_project_id uuid;
  v_commit_id uuid;
BEGIN
  v_project_id := public.get_project_id_from_repo(p_repo_id);
  IF v_project_id IS NULL THEN
    RAISE EXCEPTION 'Repository not found';
  END IF;
  PERFORM public.require_role(v_project_id, p_token, 'owner');
  SELECT id INTO v_commit_id FROM public.repo_commits WHERE repo_id = p_repo_id AND sha = p_commit_sha;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Commit not found';
  END IF;
  DELETE FROM public.repo_commits WHERE repo_id = p_repo_id AND created_at > (
    SELECT created_at FROM public.repo_commits WHERE id = v_commit_id
  );
  DELETE FROM public.repo_staging WHERE repo_id = p_repo_id;
END;
$function$;

CREATE FUNCTION public.upsert_files_batch_with_token(p_repo_id uuid, p_token uuid, p_files jsonb)
RETURNS SETOF public.repo_files
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_project_id uuid;
  v_file jsonb;
BEGIN
  v_project_id := public.get_project_id_from_repo(p_repo_id);
  IF v_project_id IS NULL THEN
    RAISE EXCEPTION 'Repository not found';
  END IF;
  PERFORM public.require_role(v_project_id, p_token, 'editor');
  FOR v_file IN SELECT * FROM jsonb_array_elements(p_files)
  LOOP
    RETURN QUERY
    INSERT INTO public.repo_files (repo_id, path, content, is_binary)
    VALUES (
      p_repo_id,
      v_file->>'path',
      v_file->>'content',
      COALESCE((v_file->>'is_binary')::boolean, false)
    )
    ON CONFLICT (repo_id, path) DO UPDATE
    SET content = EXCLUDED.content,
        is_binary = EXCLUDED.is_binary,
        updated_at = now()
    RETURNING *;
  END LOOP;
END;
$function$;

CREATE FUNCTION public.log_repo_commit_with_token(p_repo_id uuid, p_token uuid, p_sha text, p_message text, p_branch text, p_files_changed jsonb DEFAULT NULL, p_pushed boolean DEFAULT false)
RETURNS public.repo_commits
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_project_id uuid;
  v_result public.repo_commits;
BEGIN
  v_project_id := public.get_project_id_from_repo(p_repo_id);
  IF v_project_id IS NULL THEN
    RAISE EXCEPTION 'Repository not found';
  END IF;
  PERFORM public.require_role(v_project_id, p_token, 'editor');
  INSERT INTO public.repo_commits (repo_id, sha, message, branch, files_changed, pushed)
  VALUES (p_repo_id, p_sha, p_message, p_branch, p_files_changed, p_pushed)
  RETURNING * INTO v_result;
  RETURN v_result;
END;
$function$;

CREATE FUNCTION public.delete_project_repo_with_token(p_repo_id uuid, p_token uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_project_id uuid;
BEGIN
  v_project_id := public.get_project_id_from_repo(p_repo_id);
  IF v_project_id IS NULL THEN
    RAISE EXCEPTION 'Repository not found';
  END IF;
  PERFORM public.require_role(v_project_id, p_token, 'owner');
  DELETE FROM public.project_repos WHERE id = p_repo_id;
END;
$function$;

-- ============================================================================
-- PHASE 3: Fix Agent Session Functions
-- ============================================================================

CREATE FUNCTION public.create_agent_session_with_token(p_project_id uuid, p_token uuid, p_mode text, p_task_description text DEFAULT NULL)
RETURNS public.agent_sessions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_result public.agent_sessions;
BEGIN
  PERFORM public.require_role(p_project_id, p_token, 'editor');
  INSERT INTO public.agent_sessions (project_id, mode, task_description, created_by)
  VALUES (p_project_id, p_mode, p_task_description, auth.uid())
  RETURNING * INTO v_result;
  RETURN v_result;
END;
$function$;

CREATE FUNCTION public.add_blackboard_entry_with_token(p_session_id uuid, p_token uuid, p_entry_type text, p_content text, p_metadata jsonb DEFAULT NULL)
RETURNS public.agent_blackboard
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_project_id uuid;
  v_result public.agent_blackboard;
BEGIN
  v_project_id := public.get_project_id_from_session(p_session_id);
  IF v_project_id IS NULL THEN
    RAISE EXCEPTION 'Session not found';
  END IF;
  PERFORM public.require_role(v_project_id, p_token, 'editor');
  INSERT INTO public.agent_blackboard (session_id, entry_type, content, metadata)
  VALUES (p_session_id, p_entry_type, p_content, p_metadata)
  RETURNING * INTO v_result;
  RETURN v_result;
END;
$function$;

CREATE FUNCTION public.add_session_context_with_token(p_session_id uuid, p_token uuid, p_context_type text, p_context_data jsonb)
RETURNS public.agent_session_context
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_project_id uuid;
  v_result public.agent_session_context;
BEGIN
  v_project_id := public.get_project_id_from_session(p_session_id);
  IF v_project_id IS NULL THEN
    RAISE EXCEPTION 'Session not found';
  END IF;
  PERFORM public.require_role(v_project_id, p_token, 'editor');
  INSERT INTO public.agent_session_context (session_id, context_type, context_data)
  VALUES (p_session_id, p_context_type, p_context_data)
  RETURNING * INTO v_result;
  RETURN v_result;
END;
$function$;

CREATE FUNCTION public.insert_agent_message_with_token(p_session_id uuid, p_token uuid, p_role text, p_content text, p_metadata jsonb DEFAULT NULL)
RETURNS public.agent_messages
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_project_id uuid;
  v_result public.agent_messages;
BEGIN
  v_project_id := public.get_project_id_from_session(p_session_id);
  IF v_project_id IS NULL THEN
    RAISE EXCEPTION 'Session not found';
  END IF;
  PERFORM public.require_role(v_project_id, p_token, 'editor');
  INSERT INTO public.agent_messages (session_id, role, content, metadata)
  VALUES (p_session_id, p_role, p_content, p_metadata)
  RETURNING * INTO v_result;
  RETURN v_result;
END;
$function$;

CREATE FUNCTION public.log_agent_operation_with_token(p_session_id uuid, p_token uuid, p_operation_type text, p_file_path text DEFAULT NULL, p_details jsonb DEFAULT NULL)
RETURNS public.agent_file_operations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_project_id uuid;
  v_result public.agent_file_operations;
BEGIN
  v_project_id := public.get_project_id_from_session(p_session_id);
  IF v_project_id IS NULL THEN
    RAISE EXCEPTION 'Session not found';
  END IF;
  PERFORM public.require_role(v_project_id, p_token, 'editor');
  INSERT INTO public.agent_file_operations (session_id, operation_type, file_path, details)
  VALUES (p_session_id, p_operation_type, p_file_path, p_details)
  RETURNING * INTO v_result;
  RETURN v_result;
END;
$function$;

CREATE FUNCTION public.update_agent_operation_status_with_token(p_operation_id uuid, p_token uuid, p_status text, p_error_message text DEFAULT NULL)
RETURNS public.agent_file_operations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_project_id uuid;
  v_session_id uuid;
  v_result public.agent_file_operations;
BEGIN
  SELECT session_id INTO v_session_id FROM public.agent_file_operations WHERE id = p_operation_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Operation not found';
  END IF;
  v_project_id := public.get_project_id_from_session(v_session_id);
  IF v_project_id IS NULL THEN
    RAISE EXCEPTION 'Session not found';
  END IF;
  PERFORM public.require_role(v_project_id, p_token, 'editor');
  UPDATE public.agent_file_operations
  SET status = p_status,
      error_message = p_error_message,
      completed_at = CASE WHEN p_status IN ('completed', 'error') THEN now() ELSE completed_at END
  WHERE id = p_operation_id
  RETURNING * INTO v_result;
  RETURN v_result;
END;
$function$;

CREATE FUNCTION public.update_agent_session_status_with_token(p_session_id uuid, p_token uuid, p_status text)
RETURNS public.agent_sessions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_project_id uuid;
  v_result public.agent_sessions;
BEGIN
  v_project_id := public.get_project_id_from_session(p_session_id);
  IF v_project_id IS NULL THEN
    RAISE EXCEPTION 'Session not found';
  END IF;
  PERFORM public.require_role(v_project_id, p_token, 'editor');
  UPDATE public.agent_sessions
  SET status = p_status,
      updated_at = now(),
      completed_at = CASE WHEN p_status IN ('completed', 'error', 'aborted') THEN now() ELSE completed_at END
  WHERE id = p_session_id
  RETURNING * INTO v_result;
  RETURN v_result;
END;
$function$;

CREATE FUNCTION public.request_agent_session_abort_with_token(p_session_id uuid, p_token uuid)
RETURNS public.agent_sessions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_project_id uuid;
  v_result public.agent_sessions;
BEGIN
  v_project_id := public.get_project_id_from_session(p_session_id);
  IF v_project_id IS NULL THEN
    RAISE EXCEPTION 'Session not found';
  END IF;
  PERFORM public.require_role(v_project_id, p_token, 'editor');
  UPDATE public.agent_sessions
  SET abort_requested = true,
      updated_at = now()
  WHERE id = p_session_id
  RETURNING * INTO v_result;
  RETURN v_result;
END;
$function$;

CREATE FUNCTION public.get_agent_session_with_token(p_session_id uuid, p_token uuid)
RETURNS public.agent_sessions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_project_id uuid;
  v_result public.agent_sessions;
BEGIN
  v_project_id := public.get_project_id_from_session(p_session_id);
  IF v_project_id IS NULL THEN
    RAISE EXCEPTION 'Session not found';
  END IF;
  PERFORM public.require_role(v_project_id, p_token, 'viewer');
  SELECT * INTO v_result FROM public.agent_sessions WHERE id = p_session_id;
  RETURN v_result;
END;
$function$;

CREATE FUNCTION public.get_agent_sessions_with_token(p_project_id uuid, p_token uuid)
RETURNS SETOF public.agent_sessions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM public.require_role(p_project_id, p_token, 'viewer');
  RETURN QUERY SELECT * FROM public.agent_sessions WHERE project_id = p_project_id ORDER BY created_at DESC;
END;
$function$;

CREATE FUNCTION public.get_agent_operations_with_token(p_session_id uuid, p_token uuid)
RETURNS SETOF public.agent_file_operations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_project_id uuid;
BEGIN
  v_project_id := public.get_project_id_from_session(p_session_id);
  IF v_project_id IS NULL THEN
    RAISE EXCEPTION 'Session not found';
  END IF;
  PERFORM public.require_role(v_project_id, p_token, 'viewer');
  RETURN QUERY SELECT * FROM public.agent_file_operations WHERE session_id = p_session_id ORDER BY created_at;
END;
$function$;

CREATE FUNCTION public.get_blackboard_entries_with_token(p_session_id uuid, p_token uuid)
RETURNS SETOF public.agent_blackboard
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_project_id uuid;
BEGIN
  v_project_id := public.get_project_id_from_session(p_session_id);
  IF v_project_id IS NULL THEN
    RAISE EXCEPTION 'Session not found';
  END IF;
  PERFORM public.require_role(v_project_id, p_token, 'viewer');
  RETURN QUERY SELECT * FROM public.agent_blackboard WHERE session_id = p_session_id ORDER BY created_at;
END;
$function$;

CREATE FUNCTION public.get_session_context_with_token(p_session_id uuid, p_token uuid)
RETURNS SETOF public.agent_session_context
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_project_id uuid;
BEGIN
  v_project_id := public.get_project_id_from_session(p_session_id);
  IF v_project_id IS NULL THEN
    RAISE EXCEPTION 'Session not found';
  END IF;
  PERFORM public.require_role(v_project_id, p_token, 'viewer');
  RETURN QUERY SELECT * FROM public.agent_session_context WHERE session_id = p_session_id ORDER BY created_at;
END;
$function$;

-- ============================================================================
-- PHASE 4: Fix Requirement Standards Functions
-- ============================================================================

CREATE FUNCTION public.insert_requirement_standard_with_token(p_requirement_id uuid, p_token uuid, p_standard_id uuid)
RETURNS public.requirement_standards
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
  INSERT INTO public.requirement_standards (requirement_id, standard_id)
  VALUES (p_requirement_id, p_standard_id)
  ON CONFLICT (requirement_id, standard_id) DO NOTHING
  RETURNING * INTO v_result;
  RETURN v_result;
END;
$function$;

CREATE FUNCTION public.delete_requirement_standard_with_token(p_requirement_id uuid, p_token uuid, p_standard_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_project_id uuid;
BEGIN
  SELECT project_id INTO v_project_id FROM public.requirements WHERE id = p_requirement_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Requirement not found';
  END IF;
  PERFORM public.require_role(v_project_id, p_token, 'editor');
  DELETE FROM public.requirement_standards 
  WHERE requirement_id = p_requirement_id AND standard_id = p_standard_id;
END;
$function$;

CREATE FUNCTION public.get_requirement_standards_with_token(p_requirement_id uuid, p_token uuid)
RETURNS SETOF public.requirement_standards
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_project_id uuid;
BEGIN
  SELECT project_id INTO v_project_id FROM public.requirements WHERE id = p_requirement_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Requirement not found';
  END IF;
  PERFORM public.require_role(v_project_id, p_token, 'viewer');
  RETURN QUERY SELECT * FROM public.requirement_standards WHERE requirement_id = p_requirement_id;
END;
$function$;