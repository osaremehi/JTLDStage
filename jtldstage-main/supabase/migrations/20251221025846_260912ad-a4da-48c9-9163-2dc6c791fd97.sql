-- Add project_id column (nullable initially for backfill)
ALTER TABLE public.chat_messages 
ADD COLUMN project_id uuid REFERENCES public.projects(id) ON DELETE CASCADE;

-- Create trigger function to auto-populate project_id from parent session
CREATE OR REPLACE FUNCTION public.set_chat_message_project_id()
RETURNS TRIGGER AS $$
BEGIN
  SELECT project_id INTO NEW.project_id
  FROM public.chat_sessions
  WHERE id = NEW.chat_session_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
CREATE TRIGGER set_chat_message_project_id_trigger
BEFORE INSERT ON public.chat_messages
FOR EACH ROW
EXECUTE FUNCTION public.set_chat_message_project_id();

-- Backfill existing messages
UPDATE public.chat_messages cm
SET project_id = cs.project_id
FROM public.chat_sessions cs
WHERE cm.chat_session_id = cs.id
AND cm.project_id IS NULL;

-- Make column NOT NULL after backfill
ALTER TABLE public.chat_messages 
ALTER COLUMN project_id SET NOT NULL;

-- Add index for efficient project-level queries
CREATE INDEX idx_chat_messages_project_id ON public.chat_messages(project_id);

-- Enable realtime for project-level filtering
ALTER TABLE public.chat_messages REPLICA IDENTITY FULL;