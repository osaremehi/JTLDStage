-- Phase 1: Create project_testing_logs table for real-time error telemetry

CREATE TABLE public.project_testing_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  deployment_id uuid REFERENCES public.project_deployments(id) ON DELETE CASCADE,
  project_id uuid NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  log_type text NOT NULL DEFAULT 'info', -- 'stdout', 'stderr', 'error', 'warning', 'info', 'build'
  message text NOT NULL,
  stack_trace text,
  file_path text,
  line_number integer,
  is_resolved boolean DEFAULT false,
  resolved_at timestamptz,
  resolved_by uuid,
  metadata jsonb DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.project_testing_logs ENABLE ROW LEVEL SECURITY;

-- RLS policy using project token pattern
CREATE POLICY "Users can access testing logs" ON public.project_testing_logs
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM projects p
      WHERE p.id = project_testing_logs.project_id
      AND (
        p.created_by = auth.uid()
        OR EXISTS (
          SELECT 1 FROM project_tokens pt
          WHERE pt.project_id = p.id
          AND pt.token = (current_setting('app.share_token', true))::uuid
          AND (pt.expires_at IS NULL OR pt.expires_at > now())
        )
      )
    )
  );

-- Add to realtime publication for live updates
ALTER PUBLICATION supabase_realtime ADD TABLE project_testing_logs;

-- Create RPC to insert testing log with token validation
CREATE OR REPLACE FUNCTION public.insert_testing_log_with_token(
  p_deployment_id uuid,
  p_token uuid DEFAULT NULL,
  p_log_type text DEFAULT 'info',
  p_message text DEFAULT '',
  p_stack_trace text DEFAULT NULL,
  p_file_path text DEFAULT NULL,
  p_line_number integer DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'
)
RETURNS project_testing_logs
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_project_id uuid;
  result public.project_testing_logs;
BEGIN
  -- Get project_id from deployment
  SELECT project_id INTO v_project_id FROM public.project_deployments WHERE id = p_deployment_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deployment not found'; END IF;
  
  -- Validate access - viewer can insert logs (telemetry should work)
  PERFORM public.require_role(v_project_id, p_token, 'viewer');
  
  INSERT INTO public.project_testing_logs (
    deployment_id, project_id, log_type, message, stack_trace, file_path, line_number, metadata
  )
  VALUES (
    p_deployment_id, v_project_id, p_log_type, p_message, p_stack_trace, p_file_path, p_line_number, p_metadata
  )
  RETURNING * INTO result;
  
  RETURN result;
END;
$$;

-- Create RPC to get testing logs with token validation
CREATE OR REPLACE FUNCTION public.get_testing_logs_with_token(
  p_deployment_id uuid,
  p_token uuid DEFAULT NULL,
  p_limit integer DEFAULT 100,
  p_unresolved_only boolean DEFAULT false
)
RETURNS SETOF project_testing_logs
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_project_id uuid;
BEGIN
  -- Get project_id from deployment
  SELECT project_id INTO v_project_id FROM public.project_deployments WHERE id = p_deployment_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deployment not found'; END IF;
  
  -- Validate access
  PERFORM public.require_role(v_project_id, p_token, 'viewer');
  
  RETURN QUERY
  SELECT * FROM public.project_testing_logs
  WHERE deployment_id = p_deployment_id
    AND (p_unresolved_only = false OR is_resolved = false)
  ORDER BY created_at DESC
  LIMIT p_limit;
END;
$$;

-- Create RPC to mark log as resolved
CREATE OR REPLACE FUNCTION public.resolve_testing_log_with_token(
  p_log_id uuid,
  p_token uuid DEFAULT NULL
)
RETURNS project_testing_logs
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_project_id uuid;
  result public.project_testing_logs;
BEGIN
  -- Get project_id from log
  SELECT project_id INTO v_project_id FROM public.project_testing_logs WHERE id = p_log_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Log not found'; END IF;
  
  -- Validate access - editor can resolve
  PERFORM public.require_role(v_project_id, p_token, 'editor');
  
  UPDATE public.project_testing_logs
  SET is_resolved = true, resolved_at = now(), resolved_by = auth.uid()
  WHERE id = p_log_id
  RETURNING * INTO result;
  
  RETURN result;
END;
$$;