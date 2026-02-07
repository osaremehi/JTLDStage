-- Update handle_user_login() to also create default user_role
CREATE OR REPLACE FUNCTION public.handle_user_login()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  -- Upsert profile
  INSERT INTO public.profiles (user_id, email, last_login, display_name)
  VALUES (
    NEW.id,
    NEW.email,
    now(),
    COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1))
  )
  ON CONFLICT (user_id) DO UPDATE SET
    email = EXCLUDED.email,
    last_login = now(),
    updated_at = now();

  -- Create default user role if doesn't exist
  INSERT INTO public.user_roles (user_id, role)
  VALUES (NEW.id, 'user')
  ON CONFLICT (user_id, role) DO NOTHING;

  RETURN NEW;
END;
$$;

-- Backfill: Create user roles for any existing users without one
INSERT INTO public.user_roles (user_id, role)
SELECT p.user_id, 'user'::app_role
FROM public.profiles p
WHERE NOT EXISTS (
  SELECT 1 FROM public.user_roles ur WHERE ur.user_id = p.user_id
)
ON CONFLICT (user_id, role) DO NOTHING;