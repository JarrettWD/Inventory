-- ===========================================================================
-- Migration 003: per-item low-stock monitoring toggle
--
-- Run this in the Supabase dashboard: SQL Editor -> New query -> Run.
-- Safe to run more than once.
--
-- WHY THE DEFAULT IS TRUE
-- Adding the column with `default true` backfills every existing row with
-- true, so items you already have keep being watched exactly as they are
-- today - nothing silently disappears from the shopping list the moment this
-- runs. The app creates NEW items with false, because most things in the
-- basement do not need watching.
--
-- The app works WITHOUT this migration: it probes for the column at start-up
-- and, if it is missing, treats every item as watched (today's behaviour) and
-- shows the toggle switched on and disabled.
-- ===========================================================================

alter table public.inventory
  add column if not exists low_stock_enabled boolean not null default true;

comment on column public.inventory.low_stock_enabled is
  'Whether this item is watched for low stock. Existing rows were backfilled '
  'true to preserve behaviour; the app creates new items false.';
