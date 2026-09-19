-- ===========================================================================
-- Basement Food Inventory Tracker - Supabase schema
-- Run this once in the Supabase dashboard: SQL Editor -> New query -> Run.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- Inventory table. Columns match the item fields in the brief (section 4).
-- Postgres uses snake_case; the app maps these to its camelCase field names.
-- ---------------------------------------------------------------------------
create table if not exists public.inventory (
  id          uuid primary key default gen_random_uuid(),

  name        text        not null check (length(btrim(name)) > 0),  -- "Canned tomatoes"
  category    text        not null,                                  -- "Canned goods"
  location    text        not null,                                  -- "Basement storage room"
  qty         numeric(8,2) not null default 0 check (qty >= 0),      -- 4, or 0.5 for a part bag
  unit        text,                                                  -- "cans", "kg", ...

  expiry      date,          -- nullable on purpose: blank is allowed and flagged for review
  stock_date  date        not null default current_date,             -- set automatically on entry

  opened      boolean     not null default false,
  low_stock_enabled boolean not null default true,                     -- is this item watched for low stock at all?
  low_stock   smallint    check (low_stock is null or low_stock >= 0), -- null = use household default
  on_list     boolean     not null default false,                    -- "always keep on the shopping list"
  barcode     text,                                                  -- EAN/UPC from the scanner, if scanned
  notes       text,

  updated_at  timestamptz not null default now()
);

-- Helps the "check before shopping" lookup once the table gets large.
create index if not exists inventory_name_idx     on public.inventory (lower(name));
create index if not exists inventory_expiry_idx   on public.inventory (expiry);
create index if not exists inventory_location_idx on public.inventory (location);

-- Keep updated_at honest, so a future sync can detect other people's edits.
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists inventory_touch_updated_at on public.inventory;
create trigger inventory_touch_updated_at
  before update on public.inventory
  for each row execute function public.touch_updated_at();


-- ---------------------------------------------------------------------------
-- Row Level Security
--
-- READ THIS BEFORE RUNNING.
--
-- The brief says "Login needed? No". Without a login, the only identity the
-- app has is the anonymous role that the publishable key maps to - and that
-- key is visible in the page source to anyone who opens the app. So these
-- policies mean:
--
--     anyone who has your project URL + publishable key can read, add,
--     change and delete rows in this table.
--
-- For a household food list the brief calls low sensitivity, that is usually
-- an acceptable trade. It is NOT acceptable for anything private. If you would
-- rather lock it down, comment out the four policies below and see the
-- "Locked-down alternative" at the end of this file.
-- ---------------------------------------------------------------------------
alter table public.inventory enable row level security;

drop policy if exists "anon can read inventory"   on public.inventory;
drop policy if exists "anon can insert inventory" on public.inventory;
drop policy if exists "anon can update inventory" on public.inventory;
drop policy if exists "anon can delete inventory" on public.inventory;

create policy "anon can read inventory"
  on public.inventory for select to anon, authenticated using (true);

create policy "anon can insert inventory"
  on public.inventory for insert to anon, authenticated with check (true);

create policy "anon can update inventory"
  on public.inventory for update to anon, authenticated using (true) with check (true);

create policy "anon can delete inventory"
  on public.inventory for delete to anon, authenticated using (true);


-- ---------------------------------------------------------------------------
-- Locked-down alternative (recommended once the basics work)
--
-- 1. In the dashboard: Authentication -> Providers -> enable Email.
--    Add yourself and your partner under Authentication -> Users.
-- 2. Replace the four policies above with these, so only signed-in
--    household members can touch the table:
--
--      create policy "household read"   on public.inventory
--        for select to authenticated using (true);
--      create policy "household write"  on public.inventory
--        for all to authenticated using (true) with check (true);
--
-- 3. The app then needs a sign-in screen. Say the word and I will add one -
--    it is a small change, but it does mean the brief's "no login" goes away.
-- ---------------------------------------------------------------------------
