-- ===========================================================================
-- Migration 002: store the scanned barcode on each item
--
-- Run this in the Supabase dashboard: SQL Editor -> New query -> Run.
-- Safe to run more than once.
--
-- The app works WITHOUT this migration: it probes for the column on start-up
-- and simply stops sending the field if it is missing, so scanning still
-- fills in the name and category, it just cannot remember the barcode.
-- Run it when you want the barcode kept.
-- ===========================================================================

alter table public.inventory
  add column if not exists barcode text;

-- Looking an item up by barcode is the whole point, so index it.
-- Not unique: the same product can legitimately sit in two locations, and
-- the app treats a barcode match as a duplicate *warning*, not a block.
create index if not exists inventory_barcode_idx
  on public.inventory (barcode)
  where barcode is not null;
