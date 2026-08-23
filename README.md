# Basement Food Inventory Tracker

A small, mobile-first web app for tracking what food is in the basement: what
is expiring, what is running low, and what not to buy again. Installable on
Android as a PWA.

Built from the brief in `Personal_Food_Inventory_App_Brief_Template.docx`.

## What it does

- Add, edit, delete, search and filter food items
- Quantity, unit, category, storage location, expiry date, stock date
- Expired and expiring-soon flags, grouped 0-30 / 31-60 / 61-90 days
- Duplicate warnings that catch reworded names ("Canned tomatoes" vs
  "Tomatoes, canned"), household synonyms (chickpeas / garbanzo beans) and
  different package sizes
- Shopping list: what to buy from low stock, plus a do-not-buy check for the
  aisle

## How it is put together

| | |
|---|---|
| `index.html` | The whole app - markup, styles and logic in one file, no build step |
| `manifest.json` | PWA metadata (installable, standalone, icons) |
| `sw.js` | Service worker; caches the app shell only, never the API |
| `icons/` | Placeholder icons - replace these two PNGs with your own |
| `supabase/schema.sql` | Table, indexes, trigger and RLS policies |
| `config.js` | Optional local connection settings; gitignored |

Food items live in a Supabase table. Categories, locations, expiry rules and
an offline copy of the inventory are kept in the browser's local storage, so
the list still displays with no signal - writes need a connection.

## Setup

### 1. Create the table

In your Supabase project, open **SQL Editor -> New query**, paste the contents
of `supabase/schema.sql`, and run it.

Read the Row Level Security section of that file before you do. The app has no
login, so the policies let anyone holding the project URL and publishable key
read and write the table. That is usually a fine trade for a household food
list; the file has a locked-down alternative if you want sign-in instead.

### 2. Open the app and connect it

Open the app and it asks for your **Project URL** and **publishable (anon)
key**, both from Supabase under *Project Settings -> API keys*. It checks them
before saving, and stores them on that device only - nothing is committed to
this repository.

You can paste the dashboard link, the API URL, or just the project ref; all
three work. To change or clear it later: **Settings -> Connection**.

Never paste a secret or service-role key. The app refuses it, because anything
it holds is readable by anyone using the app.

For local development you can skip the prompt by copying `config.example.js`
to `config.js` and filling it in. That file is gitignored.

### 3. Running it

Opening `index.html` straight from disk works for everyday use, but service
workers need HTTPS, so the app cannot be **installed** that way. To install it,
host it (see below).

## Hosting on GitHub Pages

```
git remote add origin https://github.com/USERNAME/REPO.git
git push -u origin main
```

Then in the repository: **Settings -> Pages -> Build and deployment ->
Source: Deploy from a branch**, branch `main`, folder `/ (root)`. After a
minute the app is at `https://USERNAME.github.io/REPO/`.

All paths in the app are relative, so serving from a subfolder works.

### Installing on Android

Open the Pages URL in Chrome, then **menu -> Add to Home screen** (it may say
*Install app*). It launches standalone with no browser chrome. The first launch
asks for the Supabase details as above.

## Replacing the icons

Drop your own `icon-192.png` and `icon-512.png` into `icons/`, same names and
sizes. Keep the artwork inside the middle ~60% and the background full-bleed,
so Android's circular mask does not clip it. Bump `CACHE_VERSION` in `sw.js`
so installed copies pick up the change.
