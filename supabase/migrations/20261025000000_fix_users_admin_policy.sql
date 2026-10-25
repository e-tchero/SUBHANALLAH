-- Fix the admin read policy on users.
--
-- "Admins can read all users" ran SELECT ... FROM users inside its own
-- USING clause on the users table, which Postgres rejects with
-- "infinite recursion detected in policy for relation users" (42P17),
-- breaking every read on that table for authenticated users.
--
-- Route the check through a SECURITY DEFINER function instead: the function
-- runs as the owner (postgres), which is not subject to the table's row
-- level security, so it no longer re-enters its own policy.

create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from users
    where id = auth.uid()
      and user_type = 'admin'
  );
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

drop policy if exists "Admins can read all users" on users;

create policy "Admins can read all users"
  on users for select
  to authenticated
  using (public.is_admin());
