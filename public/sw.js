/*
 * Masaken App service worker.
 * Goal: make the app installable and give it a basic offline shell, without
 * ever trapping users on a stale build.
 *
 *  - HTML / navigations : network-first (always try to get the latest app),
 *                         fall back to the cached shell when offline.
 *  - Other static files : cache-first, refreshed in the background.
 *  - Supabase / EmailJS  : never touched by the worker (handled by the network).
 *
 * Bump CACHE_VERSION whenever you want old caches cleared on next visit.
 */
const CACHE_VERSION = 'masaken-v1';
const SHELL = ['./', './index.html', './config.js', './manifest.webmanifest', './icon.svg'];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_VERSION).then((c) => c.addAll(SHELL)).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE_VERSION).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const { request } = event;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  // Only manage our own origin. Let API + CDN calls go straight to the network.
  if (url.origin !== self.location.origin) return;

  const isNavigation = request.mode === 'navigate' ||
    (request.headers.get('accept') || '').includes('text/html');

  if (isNavigation) {
    event.respondWith(
      fetch(request)
        .then((res) => {
          caches.open(CACHE_VERSION).then((c) => c.put('./index.html', res.clone()));
          return res;
        })
        .catch(() => caches.match('./index.html'))
    );
    return;
  }

  event.respondWith(
    caches.match(request).then((cached) => {
      const network = fetch(request)
        .then((res) => {
          if (res && res.ok) {
            const copy = res.clone();
            caches.open(CACHE_VERSION).then((c) => c.put(request, copy));
          }
          return res;
        })
        .catch(() => cached);
      return cached || network;
    })
  );
});
