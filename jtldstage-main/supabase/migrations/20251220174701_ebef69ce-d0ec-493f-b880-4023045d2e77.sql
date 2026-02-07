-- Drop the duplicate function with uuid parameter to resolve ambiguity
DROP FUNCTION IF EXISTS public.insert_artifact_with_token(uuid, uuid, text, text, uuid, text);