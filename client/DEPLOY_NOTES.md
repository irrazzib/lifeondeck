# Deploy notes — LifeOnDeck webapp (PWA)

Operational notes for serving `build/web/` behind a reverse proxy in production.
Build pipeline: see `README.md` → "Build produzione (PWA)" (or `./build-web.sh`).

## Cache-Control headers (reverse proxy)

Recommended `Cache-Control` per asset class. The client image ships its own
Nginx (`nginx.conf`) that already sets these; an upstream proxy must not
override them.

```
index.html              → Cache-Control: no-cache
sw.js                   → Cache-Control: no-cache
manifest.json           → Cache-Control: no-cache
flutter_bootstrap.js    → Cache-Control: no-cache
workbox-*.js            → Cache-Control: public, max-age=31536000, immutable
main.dart.js            → Cache-Control: public, max-age=3600
canvaskit/*             → Cache-Control: public, max-age=31536000, immutable
assets/*                → Cache-Control: public, max-age=3600
icons/*                 → Cache-Control: public, max-age=31536000, immutable
```

**Why**: Flutter web files like `main.dart.js` are **not** content-hashed in
their filename, so they need a short TTL. The Workbox `sw.js` precache manifest
embeds a per-asset `revision` hash and handles cache invalidation client-side on
each new deploy. `workbox-*.js` and `canvaskit/*` are hashed/immutable, so they
get a 1-year immutable TTL. `index.html` / `sw.js` / `manifest.json` must be
`no-cache` so a deploy is picked up immediately.

## Firebase authorized domain (Step 3.9 — manual, post-deploy)

After the app is reachable at its production URL, the Google sign-in popup will
fail with `auth/unauthorized-domain` until the domain is whitelisted:

- Firebase Console → Authentication → Settings → Authorized domains.
- Add the production domain (and any staging domain).

**Check**: post-deploy, Google login completes without `auth/unauthorized-domain`.

## API CORS (reminder)

The API restricts origins via `Cors:AllowedOrigins` (see
`../api/LifeOnDeck.Api/appsettings.json`). Add the production webapp origin there
before going live — `https://lifeondeck.gmarra.it` is already listed.
