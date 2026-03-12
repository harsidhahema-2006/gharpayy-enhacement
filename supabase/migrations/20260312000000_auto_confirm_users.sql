-- Revert: Remove auto-confirm trigger so email verification is enforced
DROP TRIGGER IF EXISTS on_auth_user_confirmed ON auth.users;
DROP FUNCTION IF EXISTS public.confirm_new_user();

-- Keep the role assignment trigger (still useful)
CREATE OR REPLACE FUNCTION public.assign_default_role()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.user_roles (user_id, role)
  VALUES (NEW.id, 'agent')
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_role_assigned ON auth.users;
CREATE TRIGGER on_auth_user_role_assigned
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.assign_default_role();
