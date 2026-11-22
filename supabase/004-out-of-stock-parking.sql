-- ===========================================================================
-- Migration 004: "Out of Stock" parking lot
--
-- Run this in the Supabase dashboard: SQL Editor -> New query -> Run.
-- Safe to run more than once.
--
-- Parked status is NOT stored. An item is parked when qty = 0, full stop.
-- That keeps one source of truth: a stored flag could drift out of step with
-- the quantity (another phone, a direct SQL edit, an import) and leave an item
-- "parked" with four in the basement.
--
-- The two columns below are supporting detail, and the trigger owns them --
-- the app never writes either one. Doing it in the database means the values
-- are correct no matter which device or which route made the change.
-- ===========================================================================

alter table public.inventory
  add column if not exists depleted_at      timestamptz,
  add column if not exists last_restock_qty numeric(8,2);

comment on column public.inventory.depleted_at is
  'When qty last reached 0. Null while in stock. Maintained by trigger only.';
comment on column public.inventory.last_restock_qty is
  'Peak qty reached during the current stock cycle; prefills the Restock '
  'prompt. Reset at the start of each cycle. Maintained by trigger only.';


-- ---------------------------------------------------------------------------
-- Keep depleted_at and last_restock_qty true, whatever writes the row.
--
-- last_restock_qty tracks the PEAK of the current stock cycle, so stepping
-- +1 four times up from zero records 4, exactly as restocking with 4 at once
-- does. It is deliberately left alone on decreases, and survives depletion so
-- it can prefill the next restock.
-- ---------------------------------------------------------------------------
create or replace function public.maintain_stock_cycle()
returns trigger language plpgsql as $$
begin
  -- Quantity is never stored below zero. A withdrawal that would overshoot
  -- lands on 0 and the item parks itself.
  if new.qty is null or new.qty < 0 then
    new.qty := 0;
  end if;

  if tg_op = 'INSERT' then
    if new.qty > 0 then
      new.depleted_at      := null;
      new.last_restock_qty := coalesce(new.last_restock_qty, new.qty);
    else
      -- Created with nothing in it: parked from the start.
      new.depleted_at      := coalesce(new.depleted_at, now());
    end if;
    return new;
  end if;

  -- UPDATE from here on.
  if new.qty > 0 and old.qty <= 0 then
    -- Coming back into stock starts a NEW cycle, so the peak resets.
    new.depleted_at      := null;
    new.last_restock_qty := new.qty;

  elsif new.qty > old.qty then
    -- Still in the same cycle: the peak only ever rises.
    new.depleted_at      := null;
    new.last_restock_qty := greatest(coalesce(new.last_restock_qty, 0), new.qty);

  elsif new.qty > 0 then
    -- A withdrawal, or an edit that left the quantity alone.
    new.depleted_at      := null;

  else
    -- Quantity is now zero.
    if old.qty > 0 then
      new.depleted_at := now();                                -- just ran out
    else
      new.depleted_at := coalesce(old.depleted_at, now());     -- already parked: keep the original date
    end if;
    -- last_restock_qty is left as it is, so it can prefill the next restock.
  end if;

  return new;
end $$;

drop trigger if exists inventory_maintain_stock_cycle on public.inventory;
create trigger inventory_maintain_stock_cycle
  before insert or update on public.inventory
  for each row execute function public.maintain_stock_cycle();


-- ---------------------------------------------------------------------------
-- Backfill
--
-- Items already sitting at zero move into the parking lot dated now, because
-- when they actually ran out is not recorded anywhere. last_restock_qty is
-- deliberately left null for them - it is genuinely unknown, and the app
-- falls back to 1 in the Restock prompt.
-- ---------------------------------------------------------------------------
update public.inventory
   set depleted_at = now()
 where qty <= 0
   and depleted_at is null;


-- ---------------------------------------------------------------------------
-- Row Level Security: nothing to do.
--
-- The four existing policies are row-scoped (`using (true)`), not
-- column-scoped, so they already cover these columns. There are no
-- column-level grants on this table to update either. Listed here only so the
-- next person does not have to re-derive it.
-- ---------------------------------------------------------------------------

-- No index on depleted_at on purpose: the app loads the whole table and sorts
-- client side. Worth adding if this ever grows past a few thousand rows.
