-- Fix search_path for the trigger function
CREATE OR REPLACE FUNCTION public.set_chat_message_project_id()
RETURNS TRIGGER AS $$
BEGIN
  SELECT project_id INTO NEW.project_id
  FROM public.chat_sessions
  WHERE id = NEW.chat_session_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql
SET search_path TO 'public';