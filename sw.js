/* ==========================================================================
   Service worker - Basement Food Inventory Tracker
   --------------------------------------------------------------------------
   Caches the app shell so the app opens instantly and still launches with no
   signal in the basement.

   What is NOT cached: anything going to Supabase. Those requests are left
   entirely alone so they always hit the network and the app sees the real
   data. When they fail, the app's own localStorage cache supplies the last
   known inventory and shows the offline banner - that logic lives in
   index.html, not here. Caching API responses here would mean showing stale
   stock levels with no way to tell.

   Bump CACHE_VERSION whenever the shell files change, so browsers that
   already installed an older copy pick the new one up.
   ========================================================================== */

const CACHE_VERSION = 'v4';   // v4: new icon design
const CACHE_NAME = `food-inventory-shell-${CACHE_VERSION}`;

/* Files the app needs to start. Relative paths so it works from a subfolder
   (e.g. a GitHub Pages project site at /repo-name/). */
const SHELL = [
  './',
  './index.html',
  './manifest.json',
  './icons/icon-192.png',
  './icons/icon-512.png'
];

/* config.js is gitignored, so it may legitimately be missing on a fresh
   deploy. Cached separately: a 404 here must not fail the whole install. */
const OPTIONAL = ['./config.js'];

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE_NAME);
    await cache.addAll(SHELL);
    await Promise.all(OPTIONAL.map((url) =>
      cache.add(url).catch(() => console.warn('[sw] optional file missing:', url))
    ));
    self.skipWaiting();          // take over as soon as the new copy is ready
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const names = await caches.keys();
    await Promise.all(names
      .filter((n) => n.startsWith('food-inventory-shell-') && n !== CACHE_NAME)
      .map((n) => caches.delete(n)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const { request } = event;

  // Only GET is cacheable, and only our own origin. Everything else -
  // Supabase reads and writes included - falls through to the network
  // untouched because we never call respondWith().
  if (request.method !== 'GET') return;
  if (new URL(request.url).origin !== self.location.origin) return;

  // Navigations: try the network so a redeployed app is picked up, and fall
  // back to the cached shell when there is no signal.
  if (request.mode === 'navigate') {
    event.respondWith((async () => {
      try {
        const fresh = await fetch(request);
        const cache = await caches.open(CACHE_NAME);
        cache.put('./index.html', fresh.clone());
        return fresh;
      } catch (err) {
        const cached = await caches.match('./index.html');
        return cached || Response.error();
      }
    })());
    return;
  }

  // Static assets: serve from cache immediately, refresh in the background.
  event.respondWith((async () => {
    const cached = await caches.match(request);
    const network = fetch(request).then((response) => {
      if (response && response.ok) {
        caches.open(CACHE_NAME).then((cache) => cache.put(request, response.clone()));
      }
      return response;
    }).catch(() => null);
    return cached || network || Response.error();
  })());
});
