// Komiuta service worker.
//
// Strategy:
//   * offline.html + icons are precached so the app always has an offline shell
//   * hashed static assets (CSS/JS/fonts/images) use stale-while-revalidate
//   * navigations are network-first with the offline page as fallback; HTML
//     responses are intentionally NOT cached (avoids stale/personal data)
//   * Google Fonts are cached separately for offline styling
//   * anything else (LiveView long-poll, form posts, APIs) is untouched
const VERSION = 'komiuta-v3';
const SHELL_CACHE = `${VERSION}-shell`;
const ASSET_CACHE = `${VERSION}-assets`;
const FONT_CACHE = `${VERSION}-fonts`;
const OFFLINE_URL = '/offline.html';

const PRECACHE = [
  OFFLINE_URL,
  '/images/logo_brand.png',
  '/images/icon-192.png',
  '/images/icon-512.png',
  '/images/icon-maskable-512.png',
  '/images/apple-touch-icon.png',
  '/favicon.ico',
];

const FONT_HOSTS = ['fonts.googleapis.com', 'fonts.gstatic.com'];

self.addEventListener('install', event => {
  event.waitUntil(
    caches
      .open(SHELL_CACHE)
      .then(cache => Promise.all(PRECACHE.map(url => cache.add(url).catch(() => null))))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', event => {
  const keep = new Set([SHELL_CACHE, ASSET_CACHE, FONT_CACHE]);
  event.waitUntil(
    caches
      .keys()
      .then(keys => Promise.all(keys.filter(key => !keep.has(key)).map(key => caches.delete(key))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('message', event => {
  if (event.data && event.data.type === 'SKIP_WAITING') self.skipWaiting();
});

async function cacheFirst(cacheName, request) {
  const cache = await caches.open(cacheName);
  const cached = await cache.match(request);
  if (cached) return cached;

  const response = await fetch(request);
  if (response && (response.ok || response.type === 'opaque')) {
    cache.put(request, response.clone()).catch(() => {});
  }
  return response;
}

async function staleWhileRevalidate(cacheName, request) {
  const cache = await caches.open(cacheName);
  const cached = await cache.match(request);

  const network = fetch(request)
    .then(response => {
      if (response && response.ok) cache.put(request, response.clone()).catch(() => {});
      return response;
    })
    .catch(() => null);

  return cached || (await network) || Response.error();
}

async function networkFirstNavigation(request) {
  try {
    return await fetch(request);
  } catch (_error) {
    const cached = await caches.match(OFFLINE_URL);
    return (
      cached ||
      new Response('<h1>You are offline</h1>', {
        status: 503,
        headers: { 'Content-Type': 'text/html; charset=utf-8' },
      })
    );
  }
}

self.addEventListener('fetch', event => {
  const request = event.request;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);

  // Google Fonts (cross-origin): cache so styling survives offline.
  if (FONT_HOSTS.includes(url.hostname)) {
    event.respondWith(cacheFirst(FONT_CACHE, request));
    return;
  }

  // Leave third-party requests and range requests alone.
  if (url.origin !== self.location.origin) return;
  if (request.headers.has('range')) return;

  // Navigations: always try the network first, show the offline page on failure.
  if (request.mode === 'navigate') {
    event.respondWith(networkFirstNavigation(request));
    return;
  }

  // Static assets produced by `mix phx.digest` plus local fonts/images.
  const isStatic =
    ['style', 'script', 'font', 'image'].includes(request.destination) ||
    url.pathname.startsWith('/assets/') ||
    url.pathname.startsWith('/images/') ||
    url.pathname.startsWith('/fonts/') ||
    url.pathname === '/favicon.ico';

  if (isStatic) {
    event.respondWith(staleWhileRevalidate(ASSET_CACHE, request));
  }
});
