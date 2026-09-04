module.exports = {
  globDirectory: '../build/web/',
  globPatterns: [
    '**/*.{html,js,wasm,json,css,png,jpg,jpeg,svg,ico,otf,ttf,woff,woff2,bin}',
  ],
  globIgnores: [
    'sw.js',
    'sw.js.map',
    'workbox-*.js',
    'version.json',
    'flutter_service_worker.js',
  ],
  swDest: '../build/web/sw.js',
  sourcemap: false,
  skipWaiting: true,
  clientsClaim: true,
  cleanupOutdatedCaches: true,
  navigateFallback: '/index.html',
  navigateFallbackDenylist: [/^\/api\//],
  runtimeCaching: [
    {
      urlPattern: ({ url }) => url.pathname.startsWith('/api/'),
      handler: 'NetworkOnly',
    },
    {
      urlPattern: /^https:\/\/www\.gstatic\.com\/firebasejs\//,
      handler: 'StaleWhileRevalidate',
      options: { cacheName: 'firebase-sdk' },
    },
    {
      urlPattern: /^https:\/\/securetoken\.googleapis\.com\//,
      handler: 'NetworkOnly',
    },
  ],
  maximumFileSizeToCacheInBytes: 10 * 1024 * 1024,
};
