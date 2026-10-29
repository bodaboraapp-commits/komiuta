// Komiuta service worker.
//
// Static assets are cached at runtime (network-first, cache fallback) so the
// digested asset paths produced by `mix phx.digest` are cached correctly, and
// previously visited pages remain available offline.
const CACHE_NAME = 'komiuta-v2';
const PRECACHE = [
  '/images/icon-192.png',
  '/images/icon-512.png',
  '/images/icon-maskable-512.png',
  '/images/apple-touch-icon.png',
  '/favicon.ico'
];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => Promise.all(PRECACHE.map(url => cache.add(url).catch(() => null))))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys => {
      return Promise.all(
        keys.filter(key => key !== CACHE_NAME).map(key => caches.delete(key))
      );
    }).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', event => {
  // Only handle same-origin GET requests; never interfere with LiveView
  // websocket traffic or third-party requests.
  if (event.request.method !== 'GET') return;

  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin) return;

  const isNavigation = event.request.mode === 'navigate';

  event.respondWith(
    fetch(event.request)
      .then(response => {
        if (response && response.ok) {
          const copy = response.clone();
          caches.open(CACHE_NAME).then(cache => cache.put(event.request, copy)).catch(() => {});
        }
        return response;
      })
      .catch(() => {
        return caches.match(event.request).then(cached => {
          if (cached) return cached;
          if (isNavigation) return caches.match('/');
          return Response.error();
        });
      })
  );
});
