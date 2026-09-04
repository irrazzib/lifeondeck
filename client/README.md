# TCG Life Counter

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Configuration

### API base URL

`ApiClient` resolves its base URL from, in order:

1. The `baseUrl` constructor argument (if provided).
2. The `API_BASE_URL` compile-time define (`--dart-define`).
3. Fallback default `http://localhost:5000/api/v1` (local dev).

Local dev (default localhost):

```bash
flutter run -d chrome
```

Production build. The webapp and the API share the host
(`https://lifeondeck.gmarra.it`), so the base URL is root-relative and resolved
against `Uri.base` at runtime — no hardcoded domain, no CORS:

```bash
flutter build web --base-href "/" --dart-define=API_BASE_URL=/api/v1
```

For a build against a different API host, pass an absolute URL instead.

## Build produzione (PWA)

La build PWA è in due fasi: Flutter genera gli asset web, poi `workbox-cli`
genera il service worker `sw.js`. **`--pwa-strategy=none`** disabilita il SW
default di Flutter, altrimenti confligge con quello Workbox.

Usa `build-web.sh`, che incapsula le due fasi ed è lo stesso comando usato
dalla CI (`.github/workflows/deploy-client.yml`). I default sono già quelli di
produzione — `API_BASE_URL=/api/v1`, `base-href=/`:

```bash
cd client
./build-web.sh
# output finale: client/build/web/
```

Override per staging o per un deploy sotto sotto-path:

```bash
./build-web.sh https://api.staging.tld/api/v1 /sottopath/
```

Le due fasi equivalenti, se serve lanciarle a mano:

```bash
cd client
flutter build web --release \
  --pwa-strategy=none \
  --base-href "/" \
  --dart-define=API_BASE_URL=/api/v1
cd web-build-tools
npx workbox-cli generateSW workbox-config.cjs
```

Prerequisito una tantum: `cd web-build-tools && npm install` (vedi
`web-build-tools/package.json`).
