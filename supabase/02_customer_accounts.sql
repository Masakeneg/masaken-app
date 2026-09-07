-- ============================================================================
--  Masaken App — customer accounts + order tracking
--  Run this in the Supabase SQL editor AFTER schema.sql. Safe to re-run.
--
--  Adds:
--   * an `admins` allowlist — signed-in users in this table see ALL orders;
--     everyone else (customers) sees only their own.
--   * `orders.user_id` linking an order to the customer who placed it.
--   * link_my_orders() — a customer can claim past guest orders that used
--     their phone number.
-- ============================================================================

-- ----------------------------------------------------------------------------
--  1. Admins allowlist
-- ----------------------------------------------------------------------------
create table if not exists public.admins (
  id        uuid        primary key references auth.users(id) on delete cascade,
  email     text,
  added_at  timestamptz not null default now()
);

alter table public.admins enable row level security;

drop policy if exists "see my own admin row" on public.admins;
create policy "see my own admin row"
  on public.admins for select to authenticated
  using (id = auth.uid());

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$ select exists (select 1 from public.admins where id = auth.uid()) $$;

grant execute on function public.is_admin() to anon, authenticated;

-- Bootstrap the existing staff login as an admin.
-- To add another team member later:
--   1. Authentication → Users → Add user (create their login)
--   2. run:  insert into public.admins (id, email)
--            select id, email from auth.users where email = 'them@example.com';
insert into public.admins (id, email)
select u.id, u.email
from auth.users u
where u.email = 'mustafaghonim95@gmail.com'
on conflict (id) do nothing;

-- ----------------------------------------------------------------------------
--  2. Link orders to a customer account (nullable — guests have no account)
-- ----------------------------------------------------------------------------
alter table public.orders
  add column if not exists user_id uuid references auth.users(id) on delete set null;

create index if not exists orders_user_id_idx on public.orders (user_id);

-- ----------------------------------------------------------------------------
--  3. Row Level Security — customers see their own, admins see everything
-- ----------------------------------------------------------------------------
alter table public.orders enable row level security;

drop policy if exists "team can read orders"    on public.orders;
drop policy if exists "team can update orders"   on public.orders;
drop policy if exists "read own orders or admin" on public.orders;
drop policy if exists "admins update orders"     on public.orders;

create policy "read own orders or admin"
  on public.orders for select to authenticated
  using (user_id = auth.uid() or public.is_admin());

create policy "admins update orders"
  on public.orders for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());
-- still no INSERT/DELETE policy: inserts go through create_order(), deletes
-- are dashboard-only.

-- ----------------------------------------------------------------------------
--  4. create_order() — stamp the caller's account id (null for guests)
-- ----------------------------------------------------------------------------
create or replace function public.create_order(
  p_phone       text,
  p_address     text,
  p_notes       text,
  p_items       jsonb,
  p_client_date text
)
returns table (id uuid, seq bigint)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_phone   text := btrim(coalesce(p_phone, ''));
  v_address text := btrim(coalesce(p_address, ''));
begin
  if length(v_phone) < 6 or length(v_phone) > 20 then
    raise exception 'invalid phone';
  end if;
  if length(v_address) < 3 or length(v_address) > 400 then
    raise exception 'invalid address';
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'no items';
  end if;
  if jsonb_array_length(p_items) > 60 then
    raise exception 'too many items';
  end if;

  return query
  insert into public.orders (phone, address, notes, items, client_date, user_id)
  values (
    v_phone,
    v_address,
    nullif(btrim(coalesce(p_notes, '')), ''),
    p_items,
    nullif(btrim(coalesce(p_client_date, '')), ''),
    auth.uid()
  )
  returning orders.id, orders.seq;
end;
$$;

revoke all on function public.create_order(text, text, text, jsonb, text) from public;
grant execute on function public.create_order(text, text, text, jsonb, text) to anon, authenticated;

-- ----------------------------------------------------------------------------
--  5. link_my_orders() — claim past guest orders that used my phone
--     Matches on the last 10 digits so 010…, +20 10…, 0020 10… all line up.
-- ----------------------------------------------------------------------------
create or replace function public.link_my_orders(p_phone text)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_digits text := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
  v_tail   text;
  n        integer;
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  if length(v_digits) < 10 then
    return 0;
  end if;
  v_tail := right(v_digits, 10);

  update public.orders o
     set user_id = auth.uid()
   where o.user_id is null
     and right(regexp_replace(o.phone, '\D', '', 'g'), 10) = v_tail;

  get diagnostics n = row_count;
  return n;
end;
$$;

revoke all on function public.link_my_orders(text) from public;
grant execute on function public.link_my_orders(text) to authenticated;

-- ----------------------------------------------------------------------------
--  6. Realtime already covers public.orders (from schema.sql). RLS is applied
--     to realtime too, so customers only get events for their own orders.
-- ----------------------------------------------------------------------------

-- ============================================================================
--  After running this, in the Supabase dashboard:
--   Authentication → Sign In / Providers → Email:
--     * turn ON  "Allow new users to sign up"      (customers can register)
--     * turn OFF "Confirm email"                   (phone accounts have no
--                                                   real inbox to confirm)
-- ============================================================================
