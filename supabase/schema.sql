-- ============================================================================
--  Masaken App — database schema
--  Run this once in the Supabase dashboard:  SQL Editor → New query → paste →
--  Run.  Safe to re-run (uses IF NOT EXISTS / CREATE OR REPLACE / drops policies
--  before recreating them).
-- ============================================================================

-- ----------------------------------------------------------------------------
--  Table: orders
-- ----------------------------------------------------------------------------
create table if not exists public.orders (
  id           uuid        primary key default gen_random_uuid(),
  seq          bigint      generated always as identity,   -- human order number
  created_at   timestamptz not null default now(),
  phone        text        not null,
  address      text        not null,
  notes        text,
  items        jsonb       not null default '[]'::jsonb,    -- [{name, qty, price}]
  client_date  text,                                        -- date shown to the client
  status       text        not null default 'pending'
               check (status in ('pending','contacted','confirmed','supervised','done'))
);

create index if not exists orders_seq_idx        on public.orders (seq desc);
create index if not exists orders_created_at_idx on public.orders (created_at desc);

-- ----------------------------------------------------------------------------
--  Row Level Security
--  The public (anon key in the browser) must NOT be able to read customer
--  phone numbers / addresses or change order status. They can only create
--  orders, and only through the create_order() function below.
--  Masaken team members sign in (Supabase Auth) and get full read + update.
-- ----------------------------------------------------------------------------
alter table public.orders enable row level security;

drop policy if exists "team can read orders"      on public.orders;
drop policy if exists "team can update orders"     on public.orders;
drop policy if exists "no direct public insert"    on public.orders;

create policy "team can read orders"
  on public.orders for select
  to authenticated
  using (true);

create policy "team can update orders"
  on public.orders for update
  to authenticated
  using (true)
  with check (true);

-- No insert / delete policy for anon or authenticated:
--   * inserts happen via create_order() (security definer, below)
--   * deletes are impossible through the API on purpose

-- ----------------------------------------------------------------------------
--  Function: create_order()
--  Lets the public submit an order without being able to touch the table
--  directly. Returns only the new id + order number.
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
  insert into public.orders (phone, address, notes, items, client_date)
  values (
    v_phone,
    v_address,
    nullif(btrim(coalesce(p_notes, '')), ''),
    p_items,
    nullif(btrim(coalesce(p_client_date, '')), '')
  )
  returning orders.id, orders.seq;
end;
$$;

revoke all on function public.create_order(text, text, text, jsonb, text) from public;
grant execute on function public.create_order(text, text, text, jsonb, text) to anon, authenticated;

-- ----------------------------------------------------------------------------
--  Realtime: let the admin panel refresh live when orders change.
-- ----------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'orders'
  ) then
    alter publication supabase_realtime add table public.orders;
  end if;
end $$;

-- ============================================================================
--  After running this:
--   1. Authentication → Providers → Email: turn OFF "Allow new users to sign up"
--      (you only want the accounts you create by hand).
--   2. Authentication → Users → Add user: create one login per Masaken team
--      member who should see orders. Give them the email + password.
--   3. Put your Project URL + anon key into public/config.js.
-- ============================================================================
