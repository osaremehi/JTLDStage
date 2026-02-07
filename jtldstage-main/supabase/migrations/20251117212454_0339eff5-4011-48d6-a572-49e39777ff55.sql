-- Drop trigger first, then function
DROP TRIGGER IF EXISTS auto_generate_requirement_code_trigger ON requirements;
DROP TRIGGER IF EXISTS trigger_auto_generate_requirement_code ON requirements;
DROP FUNCTION IF EXISTS public.auto_generate_requirement_code() CASCADE;

-- Drop and recreate generate_requirement_code with correct signature
DROP FUNCTION IF EXISTS public.generate_requirement_code(uuid, uuid, text) CASCADE;
DROP FUNCTION IF EXISTS public.generate_requirement_code(uuid, uuid, requirement_type) CASCADE;

CREATE OR REPLACE FUNCTION public.generate_requirement_code(
  p_project_id uuid, 
  p_parent_id uuid, 
  p_type text
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  parent_code TEXT;
  sibling_count INTEGER;
  type_prefix TEXT;
  new_code TEXT;
BEGIN
  type_prefix := CASE p_type
    WHEN 'EPIC' THEN 'E'
    WHEN 'FEATURE' THEN 'F'
    WHEN 'STORY' THEN 'S'
    WHEN 'ACCEPTANCE_CRITERIA' THEN 'AC'
  END;
  
  IF p_parent_id IS NULL THEN
    SELECT COUNT(*) INTO sibling_count
    FROM requirements
    WHERE project_id = p_project_id
      AND parent_id IS NULL
      AND type::text = p_type;
    
    new_code := type_prefix || '-' || LPAD((sibling_count + 1)::TEXT, 3, '0');
    RETURN new_code;
  END IF;
  
  SELECT code INTO parent_code
  FROM requirements
  WHERE id = p_parent_id;
  
  SELECT COUNT(*) INTO sibling_count
  FROM requirements
  WHERE parent_id = p_parent_id
    AND type::text = p_type;
  
  new_code := parent_code || '-' || type_prefix || '-' || LPAD((sibling_count + 1)::TEXT, 3, '0');
  
  RETURN new_code;
END;
$$;

-- Recreate the trigger function with correct type casting
CREATE OR REPLACE FUNCTION public.auto_generate_requirement_code()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF NEW.code IS NULL THEN
    NEW.code := generate_requirement_code(NEW.project_id, NEW.parent_id, NEW.type::text);
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER auto_generate_requirement_code_trigger
  BEFORE INSERT ON requirements
  FOR EACH ROW
  EXECUTE FUNCTION auto_generate_requirement_code();

-- Add project metadata columns
ALTER TABLE projects
  ADD COLUMN IF NOT EXISTS organization text,
  ADD COLUMN IF NOT EXISTS budget numeric(15, 2),
  ADD COLUMN IF NOT EXISTS scope text,
  ADD COLUMN IF NOT EXISTS timeline_start date,
  ADD COLUMN IF NOT EXISTS timeline_end date,
  ADD COLUMN IF NOT EXISTS priority text DEFAULT 'medium',
  ADD COLUMN IF NOT EXISTS tags text[];