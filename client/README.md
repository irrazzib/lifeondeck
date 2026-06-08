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

Production build pointing at a real API host:

```bash
flutter build web --dart-define=API_BASE_URL=https://api.dominio.tld/api/v1
```

## Build produzione (PWA)

La build PWA è in due fasi: Flutter genera gli asset web, poi `workbox-cli`
genera il service worker `sw.js`. **`--pwa-strategy=none`** disabilita il SW
default di Flutter, altrimenti confligge con quello Workbox.

```bash
cd lifeondeck
flutter build web --release \
  --pwa-strategy=none \
  --dart-define=API_BASE_URL=https://api.dominio.tld/api/v1
cd web-build-tools
npx workbox-cli generateSW workbox-config.cjs
# output finale: lifeondeck/build/web/
```

In alternativa lo script `build-web.sh` incapsula i due comandi:

```bash
./build-web.sh https://api.dominio.tld/api/v1
```

Prerequisito una tantum: `cd web-build-tools && npm install` (vedi
`web-build-tools/package.json`).
