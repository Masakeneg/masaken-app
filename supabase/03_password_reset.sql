-- ============================================================================
--  Masaken App — customer password reset (owner-mediated, no email/SMS needed)
--  Run in the Supabase SQL editor after 02_customer_accounts.sql. Safe to re-run.
--
--  Customer accounts use a phone number (no real email), so the normal
--  "reset link by email" doesn't apply. Instead:
--    1. customer taps "نسيت كلمة المرور؟" → opens WhatsApp to Masaken
--    2. an admin, from the orders panel, sets a new temporary password
--    3. admin sends it to the customer on WhatsApp; customer can change it
--       later from حسابي
-- ============================================================================

create extension if not exists pgcrypto with schema extensions;

-- Admin-only: set a new password for the customer account tied to a phone.
create or replace function public.admin_set_customer_password(p_phone text, p_new_password text)
returns text
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  v_digits text := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
  v_email  text;
  v_id     uuid;
begin
  if not public.is_admin() then
    raise exception 'not authorized';
  end if;
  if length(v_digits) < 10 then
    raise exception 'invalid phone';
  end if;
  if length(coalesce(p_new_password, '')) < 6 then
    raise exception 'password too short';
  end if;

  v_email := '0' || right(v_digits, 10) || '@phone.masakeneg.app';
  select id into v_id from auth.users where email = v_email;
  if v_id is null then
    return 'no-account';           -- this phone has never made an account
  end if;

  update auth.users
     set encrypted_password = extensions.crypt(p_new_password, extensions.gen_salt('bf', 10)),
         updated_at = now()
   where id = v_id;

  return 'ok';
end;
$$;

revoke all on function public.admin_set_customer_password(text, text) from public;
grant execute on function public.admin_set_customer_password(text, text) to authenticated;
