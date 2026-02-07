-- Drop the old 5-parameter version of insert_artifact_with_token that doesn't have p_image_url
-- This resolves the PGRST203 overload error by keeping only the 6-parameter version
DROP FUNCTION IF EXISTS public.insert_artifact_with_token(uuid, uuid, text, text, uuid);