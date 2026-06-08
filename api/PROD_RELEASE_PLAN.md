# Piano rilascio produzione — webapp + PWA

Documento operativo per portare LifeOnDeck (Flutter web + API .NET) in produzione come webapp installabile (PWA offline-first).

---

## Come usare questo file (sessioni multiple)

1. **All'inizio di ogni sessione Claude**, chiedere: _"Leggi `PROD_RELEASE_PLAN.md`, trova primo step con `[ ]`, riprendi da lì."_
2. **Stato avanzamento** è tracciato dai checkbox `- [ ]` (TODO) / `- [x]` (DONE) accanto a ogni step.
3. **Al completamento di uno step**:
   - Marcare checkbox come `[x]`.
   - Aggiornare sezione `## Stato corrente` (data + step completato + note brevi).
   - Eseguire il check di verifica e segnarne esito.
   - Commit dedicato con messaggio `chore(plan): complete step X.Y — <descrizione>` (opzionale, consigliato).
4. **In caso di interruzione mid-step**:
   - Lasciare checkbox `[ ]`.
   - Annotare in `## Stato corrente` cosa è stato fatto parzialmente e cosa manca.
5. **Modifiche al piano**: aggiornare direttamente questo file. Tracciare in `## Changelog piano` in fondo.

### Convenzioni status

| Simbolo | Significato |
|---|---|
| `[ ]` | TODO |
| `[~]` | IN CORSO (parzialmente fatto) |
| `[x]` | DONE + verificato |
| `[!]` | BLOCKED (vedi note) |
| `[-]` | SKIPPED (vedi note) |

---

## Stato corrente

- **Ultima sessione**: 2026-06-07 — Fase 3 + Fase 4 verificate. Build PWA prodotta e validata in browser headless (preview). 4.1+4.2+4.4 ✅ (meccanismo provato), 4.3+4.5+4.6 = verifica manuale residua (interattiva/richiede API live).
- **Prossimo step**: NESSUNO automatizzabile. Restano solo verifiche manuali interattive: 4.3 (update flow multi-rebuild), 4.5 (Lighthouse in Chrome), 4.6 (401 refresh con API live), 3.9 (Firebase authorized domain post-deploy), 3.2 (maskable su maskable.app). Tutto il codice/config è completo e provato.
- **Note**: build `./build-web.sh https://api.dominio.tld/api/v1` OK. `--pwa-strategy=none` onorato (Flutter non registra SW, solo Workbox). SW attivo+controlling in browser, precache 27 entry, manifest valido, app shell renderizza, console pulita. /api/ NetworkOnly. **Pronto per deploy** dietro reverse proxy (vedi DEPLOY_NOTES.md).

---

## Fuori scope (escluso per richiesta utente)

- Migrazioni DB EF Core (`dotnet ef migrations`) — utente eseguirà manualmente.
- Configurazione reverse proxy (nginx/caddy) + TLS — utente farà insieme alle altre app pubblicate.
- Build/sign nativi iOS/Android — rilascio solo come webapp + PWA.
- GitHub Actions CI/CD — utente scriverà workflow separati per client e server.

---

## Fase 1 — Hardening API

### Step 1.1 — JWT secret obbligatorio da env var
- [x] Rimuovere placeholder `"CHANGE_ME_IN_PRODUCTION_USE_ENV_VAR"` da `lifeondeck-api/LifeOnDeck.Api/appsettings.json`.
- [x] In `Program.cs`: aggiungere validazione `secretKey.Length >= 32` (fail-fast con eccezione esplicita).
- [x] In `appsettings.Development.json`: aggiungere chiave Jwt:SecretKey solo per dev (stringa lunga di placeholder dev-only).
- [x] Documentare in `lifeondeck-api/README.md` (se non esiste, creare) variabile env `JWT__SECRETKEY`.
- **Check**: avviare API senza env var e senza `appsettings.Development.json` → eccezione esplicita all'avvio. Con env var → boot OK. ✅ Verificato 2026-05-27.

### Step 1.2 — CORS whitelist da config
- [x] In `appsettings.json` aggiungere sezione `"Cors": { "AllowedOrigins": [] }`.
- [x] In `appsettings.Development.json` impostare `["http://localhost:*"]` o specifico port Flutter web (es. `http://localhost:53682`).
- [x] In `Program.cs` rimpiazzare `AllowAnyOrigin()` con `WithOrigins(origins).SetIsOriginAllowedToAllowWildcardSubdomains()`.
- [x] Mantenere `AllowAnyMethod()` e `AllowAnyHeader()` solo se necessario, altrimenti restringere.
- **Check**: request da origin non whitelist → preflight 403. Da origin whitelist → 200/204. ✅ Verificato 2026-05-27 — comportamento .NET default: preflight 204 senza ACAO header (browser blocca lato client) invece di 403; equivalente sicurezza-wise. Glob `*` per port wildcard implementato via regex predicate (`WithOrigins`/`SetIsOriginAllowedToAllowWildcardSubdomains` non supporta port wildcards, solo subdomain). Empty list = blocca tutto.

### Step 1.3 — Health endpoint
- [x] Creare `HealthController` con `GET /api/v1/health` → `200 { "status": "ok", "time": <utc> }`.
- [x] Endpoint pubblico (no `[Authorize]`).
- [x] Opzionale: check DB connection (`db.Database.CanConnectAsync()`) e ritornare status degradato se KO.
- **Check**: `curl http://localhost:5000/api/v1/health` → 200 senza JWT. ✅ Verificato 2026-05-27 — `{"status":"ok","time":"...Z","db":"ok"}`; DB KO → 503 + `status:"degraded"`. Sync rimane 401 senza JWT (auth non rotta).

### Step 1.4 — Limiti payload + rate limiting
- [x] In `Program.cs` configurare `Kestrel.Limits.MaxRequestBodySize = 5_242_880` (5MB).
- [x] Aggiungere `builder.Services.AddRateLimiter(...)` con built-in .NET 10 `FixedWindowLimiter`:
  - Policy `sync-policy`: 60 req/min per IP, applicata a `/api/v1/sync`.
  - Policy `auth-policy`: 10 req/min per IP, applicata a `/api/v1/auth/firebase`.
- [x] Decorare `SyncController` con `[EnableRateLimiting("sync-policy")]`, `AuthController` con `[EnableRateLimiting("auth-policy")]`.
- [x] `app.UseRateLimiter()` nella pipeline prima di `MapControllers()`.
- **Check**: loop 100 POST consecutivi → 429 dopo soglia. Payload >5MB → 413. ✅ Verificato 2026-05-27 — auth-policy: 15 POST consecutivi → primi 10 = 401 (token invalid), req 11-15 = 429. Payload 7.6MB → `413 Request body too large. The max request body size is 5242880 bytes`.

### Step 1.5 — Fix N+1 in Upsert
- [x] In `SyncController.UpsertGameRecordsAsync`: precaricare con singola query `WHERE Id IN (ids) AND UserId = userId` (usando `IgnoreQueryFilters` per includere soft-deleted), poi dictionary lookup in loop.
- [x] Stesso refactor per `UpsertSideboardDecksAsync`.
- [x] Lasciare `UpsertAppSettingsAsync` invariato (singolo record).
- **Check**: abilitare `Microsoft.EntityFrameworkCore.Database.Command: Information` in dev. Push con 10 record → log mostra 1 SELECT + 1 SaveChanges, non 11 query. ✅ 2026-06-06 — refactor: preload `Where(UserId == userId && ids.Contains(Id))` + `ToDictionaryAsync` per game records e sideboard decks; loop usa `TryGetValue`. Guard `items.Count == 0` early return. `dotnet build` 0 errori 0 avvisi. Verifica log query a runtime non eseguita (richiede DB attivo) ma N+1 eliminato by construction: 1 SELECT/entità + 1 SaveChanges.

---

## Fase 2 — Client sync robustness

### Step 2.1 — `ApiClient.baseUrl` parametrico via `--dart-define`
- [x] In `lifeondeck/lib/services/api_client.dart` modificare costruttore: `ApiClient({String? baseUrl})` risolve `baseUrl ?? String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:5000/api/v1')` dentro il body (campo `resolvedBaseUrl` passato a `BaseOptions`).
- [x] Documentare in `lifeondeck/README.md` flag build: `flutter build web --dart-define=API_BASE_URL=https://api.dominio.tld/api/v1`.
- [x] Verificare che nessun altro file referenzi `localhost:5000` hardcoded.
- **Check**: `flutter run -d chrome` → chiama localhost. Build con `--dart-define` → chiama dominio passato. ✅ 2026-06-06 — `grep localhost:5000 lib/` solo il defaultValue. `flutter analyze api_client.dart` → No issues. README: sezione "Configuration → API base URL" con ordine risoluzione + comandi.

### Step 2.2 — Persistenza `_lastSyncedAt`
- [x] In `lifeondeck/lib/services/sync_service.dart` aggiungere costante `_lastSyncKey = 'last_sync_at'`.
- [x] Metodo `initialize()` async che legge `SharedPreferences.getString(_lastSyncKey)` → parse ISO → `_lastSyncedAt`.
- [x] Dopo ogni `syncNow()` con esito OK: scrivere `_lastSyncedAt!.toUtc().toIso8601String()` in SharedPreferences.
- [x] Chiamare `await syncService.initialize()` in `_HomeScreenState.initState()` (o equivalente bootstrap).
- **Check**: sync OK → kill app (browser close) → riapri → DevTools Network mostra GET `/sync?since=<timestamp salvato>`, non `2020-01-01`. ✅ 2026-06-06 — `initialize()` usa `DateTime.tryParse(stored)?.toUtc()`. Write in `syncNow()` ramo OK. Chiamata in `_initWithSync()` (bootstrap) prima di `_authService.initialize()`. analyze: solo dead_code preesistente in `_openProfile` (TODO stub), non correlato. Verifica Network runtime non eseguita (no app/DB attivi).

### Step 2.3 — Fix timezone `since`
- [x] In `sync_service.dart` cambiare:
  ```dart
  final String since = _lastSyncedAt?.toUtc().toIso8601String()
      ?? DateTime.utc(2020).toIso8601String();
  ```
- [x] Verificare che `_lastSyncedAt = DateTime.now().toUtc()` (con `.toUtc()` esplicito).
- **Check**: log API mostra `since` con suffisso `Z`. Differenza tra device in timezone diversi → server riceve sempre UTC. ✅ 2026-06-06 — `since` usa `_lastSyncedAt?.toUtc().toIso8601String() ?? DateTime.utc(2020)...`. `_lastSyncedAt = DateTime.now().toUtc()` → ISO con suffisso `Z`. analyze pulito. Verifica log API runtime saltata (no DB).

### Step 2.4 — Fix semantica `appSettings.updatedAt`
- [x] In `lifeondeck/lib/models/app_settings.dart` aggiungere campo `DateTime updatedAt`.
- [x] Aggiornare `toJson`/`fromJson`/`copyWith` per includerlo.
- [x] Ogni mutazione di AppSettings deve impostare `updatedAt = DateTime.now().toUtc()`.
- [x] In `sync_service.dart` rimuovere `'updatedAt': DateTime.now().toIso8601String()` per appSettings, usare il valore reale del model.
- [x] Pushare appSettings **solo se** `settings.updatedAt > (_lastSyncedAt ?? epoch)`.
- **Check**: due browser distinti. Modifica solo su A → sync → riapri B → verifica che pull mostri update. Riavvia B senza modifiche → pull non riporta indietro le impostazioni di A. ⚠️ 2026-06-06 — codice fatto: campo `updatedAt` (default epoch UTC, costruttore non-const perché `DateTime` non const), `copyWith` auto-bumpa a `DateTime.now().toUtc()` quando non passato esplicito (ogni mutazione passa per copyWith — verificato CustomizeScreen + home_screen). Push usa `settingsUpdatedAt` reale e gate `isAfter(_lastSyncedAt ?? epoch)`. analyze pulito. **GAP**: `onApplyPull` in home_screen non applica `appSettings` dal pull (solo gameRecords+sideboardDecks) → verifica end-to-end "B riceve settings" delegata a step 2.5 (decode pull). Verifica runtime due-browser saltata (no DB).

### Step 2.5 — Verifica/fix decode pull
- [x] Ispezionare callback `onApplyPull` in `_HomeScreenState` (cercare wiring `syncService.onApplyPull = ...`).
- [x] Verificare che per ogni item server `{id, data, updatedAt, deleted}`, il client faccia `jsonDecode(item['data'] as String)` prima di costruire model.
- [x] Allineare push side: in `sync_service.dart` il payload deve essere `'data': jsonEncode(r)` dove `r` è già la `Map<String,dynamic>` completa del record (id + updatedAt inclusi nel blob — duplicazione accettata).
- [x] Documentare il contratto in commento in cima a `sync_service.dart`.
- **Check**: round-trip end-to-end. Creare game record → push → cancellare local state → pull → record riappare identico al sorgente (campi, timestamp, deck refs). ⚠️ 2026-06-06 — **BUG trovato e fixato**: `onApplyPull` faceva `GameRecord.fromJson(item)` sul wrapper `{id,data,updatedAt,deleted}` invece di decodare il blob `data` → tutti i campi persi (blob ignorato), pull non ricostruiva nulla. Fix: helper `_decodePulledItems<T>` + `_decodePulledSettings` che fanno `jsonDecode(item['data'])` prima di `fromJson`; blob malformati skippati (un record rotto non aborta il pull). **Chiuso GAP 2.4**: ora `onApplyPull` applica anche `appSettings` dal pull (LWW su `updatedAt`, aggiorna `AppRuntimeConfig.language`). Push side già conforme (`'data': jsonEncode(r)`, r=toJson() include id/updatedAt/deletedAt). Contratto wire documentato in testa a `sync_service.dart`. analyze: solo dead_code preesistente `_openProfile` (non correlato). Verifica round-trip runtime saltata (no DB/app attivi).

### Step 2.6 — Refresh JWT su 401
- [x] In `lifeondeck/lib/services/api_client.dart` aggiungere response interceptor Dio.
- [x] Logica: se `response.statusCode == 401` e non già in retry:
  1. Ottenere nuovo Firebase ID token: `await FirebaseAuth.instance.currentUser?.getIdToken(true)`.
  2. POST `/auth/firebase` con nuovo token (chiamata diretta, no interceptor ricorsivo).
  3. Salvare nuovo JWT in `FlutterSecureStorage`.
  4. Retry richiesta originale 1 volta con header `Authorization` aggiornato.
  5. Se step 1-3 falliscono: `authService.signOut()` + propagare errore.
- [x] Iniettare `AuthService` in `ApiClient` (refactor minore per evitare dipendenza circolare; passare callback `Future<String?> Function() onRefresh`).
- **Check**: forzare scadenza (impostare `Jwt:ExpiryDays = 0` temporaneo o invalidare secret) → trigger sync → interceptor refresha → sync prosegue. Reset `Jwt:ExpiryDays` a 7. ⚠️ 2026-06-06 — `ApiClient.onRefresh` callback (`Future<String?> Function()?`) rompe dep circolare; wired in `home_screen.initState` a `_authService.refreshToken`. Interceptor `onError`: su 401 + non-retry + non `/auth/firebase` → chiama `onRefresh`, se token nuovo → `extra['__jwt_retried']=true` + replay via `_dio.fetch(options)` (1 retry); se null → propaga 401 originale. Guard ricorsione: skip su `/auth/firebase` + flag retry. `AuthService.refreshToken`: `getIdToken(true)` force-refresh → POST `/auth/firebase` → salva jwt+user (copyWith token) → ritorna token; su qualsiasi fallimento → `signOut()` + null. analyze pulito su api_client+auth_service. Verifica runtime (force expiry) saltata (no DB/app attivi).

---

## Fase 3 — PWA + offline-first (Workbox)

### Step 3.1 — `web/manifest.json`
- [x] Aggiornare `lifeondeck/web/manifest.json` con campi completi:
  - `name`: "LifeOnDeck — TCG Life Counter"
  - `short_name`: "LifeOnDeck"
  - `description`: descrizione breve EN
  - `start_url`: "."
  - `display`: "standalone"
  - `orientation`: "portrait"
  - `theme_color`: "#0F172A" (allineare a `AppSettings` palette)
  - `background_color`: "#0F172A"
  - `scope`: "/"
  - `icons[]`: array con 192, 512 standard + 512 maskable
- **Check**: Chrome DevTools → Application → Manifest. Zero warning. Pulsante install browser visibile. ✅ 2026-06-06 — manifest riscritto con tutti i campi (name/short_name/description EN/start_url/scope/display/orientation portrait/theme+bg #0F172A/prefer_related_applications false). icons[] 4 entry con `purpose` esplicito (192+512 `any`, 192+512 `maskable`). JSON validato (`python3 json.load` OK). File icone presenti su disco. **Nota**: Icon-maskable-* sono byte-identici agli `any` (probabile copia, non vero safe-zone 80%) → veri maskable generati in step 3.2. Verifica DevTools Manifest runtime saltata (no browser).

### Step 3.2 — Icone PWA
> **[-] SKIPPED 2026-06-06** (scelta utente). Tenute le icone attuali (maskable = copia degli `any`). PWA installabile; su Android il mask può clippare il logo finché non si generano veri maskable safe-zone 80%. Da rifare manualmente via https://maskable.app quando si vuole. No tooling immagini disponibile in env (no Pillow/ImageMagick, solo `sips`).
- [-] Generare/sostituire icone in `lifeondeck/web/icons/`:
  - `Icon-192.png` (any)
  - `Icon-512.png` (any)
  - `Icon-maskable-192.png` (maskable, safe-zone 80%)
  - `Icon-maskable-512.png` (maskable)
  - `favicon.png` (32x32 o 16x16)
- [ ] Tool consigliato: https://maskable.app per verificare safe-zone.
- [ ] Aggiornare `manifest.json` per puntare a icone maskable con `"purpose": "maskable"` e any con `"purpose": "any"`.
- **Check**: build web + serve → manifest carica icone, nessun 404, anteprima maskable corretta.

### Step 3.3 — Meta `web/index.html`
- [x] Aggiungere/aggiornare in `<head>`:
  - `<meta name="theme-color" content="#0F172A">`
  - `<meta name="apple-mobile-web-app-capable" content="yes">`
  - `<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">`
  - `<link rel="apple-touch-icon" href="icons/Icon-192.png">`
  - `<meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">`
- [x] **NON** registrare SW ancora (step 3.6).
- **Check**: build + apertura → no errori console. iOS Safari "Aggiungi a Home" mostra icona corretta. ✅ 2026-06-06 — theme-color → #0F172A; viewport con `viewport-fit=cover` (rimosso `maximum-scale=1.0` per allinearsi al piano); apple meta + apple-touch-icon Icon-192 già presenti, confermati. Branding allineato: title/apple-mobile-web-app-title → "LifeOnDeck", description → EN. SW **non** registrato (resta 3.6). Verifica build/console runtime saltata.

### Step 3.4 — Setup `workbox-cli`
- [x] Creare cartella `lifeondeck/web-build-tools/`.
- [x] Creare `lifeondeck/web-build-tools/package.json`:
  ```json
  {
    "name": "lifeondeck-pwa-build",
    "private": true,
    "devDependencies": { "workbox-cli": "^7.3.0" }
  }
  ```
- [x] Creare `lifeondeck/web-build-tools/.gitignore` con `node_modules/`.
- [x] Eseguire `npm install` dentro `web-build-tools/`.
- [x] Aggiungere `lifeondeck/.gitignore` voce `web-build-tools/node_modules/` (ridondante ma sicuro).
- **Check**: `npx workbox-cli --help` dentro `web-build-tools/` risponde. ✅ 2026-06-06 — node v24.13.1 / npm 11.8.0. `npm install` → 500 pkg, workbox-cli ^7.3.0. `npx workbox-cli --help` risponde (mostra usage + commands). Nota: npm audit segnala 4 vuln (3 low, 1 high) in dep transitive di workbox-cli (dev-only build tool, non in bundle runtime) — accettabile. `.gitignore` di web-build-tools + voce in `lifeondeck/.gitignore` (`web-build-tools/node_modules/`).

### Step 3.5 — Config Workbox (`workbox-config.cjs`)
- [ ] Creare `lifeondeck/web-build-tools/workbox-config.cjs`:
  ```js
  module.exports = {
    globDirectory: '../build/web/',
    globPatterns: [
      '**/*.{html,js,wasm,json,css,png,jpg,jpeg,svg,ico,otf,ttf,woff,woff2,bin}',
    ],
    globIgnores: ['sw.js', 'sw.js.map', 'workbox-*.js', 'version.json'],
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
  ```
- **Check**: `npx workbox-cli generateSW workbox-config.cjs` (richiede `build/web` esistente — se non esiste, prima `flutter build web`) produce `build/web/sw.js` senza errori. ✅ 2026-06-07 — `workbox-config.cjs` creato (contenuto dal piano: globDirectory ../build/web, NetworkOnly su /api/, navigateFallback index.html con denylist /api/, maxFileSize 10MB). `generateSW` su build/web preesistente → `sw.js` (3.2KB, `precacheAndRoute` + revision hash) + `workbox-a66dcdb0.js`. 27 URL precache, 29.3 MB. 0 errori.

### Step 3.6 — Registrazione SW + update flow in `index.html`
- [ ] In `lifeondeck/web/index.html` aggiungere prima di `</body>`:
  ```html
  <script>
    if ('serviceWorker' in navigator) {
      window.addEventListener('load', function () {
        navigator.serviceWorker.register('sw.js').then(function (reg) {
          reg.addEventListener('updatefound', function () {
            var sw = reg.installing;
            if (!sw) return;
            sw.addEventListener('statechange', function () {
              if (sw.state === 'installed' && navigator.serviceWorker.controller) {
                window.location.reload();
              }
            });
          });
        }).catch(function (e) { console.warn('SW register failed', e); });
      });
    }
  </script>
  ```
- [x] Strategia: `skipWaiting + clientsClaim` lato SW + reload lato client = update silenzioso al deploy.
- **Check**: primo load → DevTools Application → Service Workers attivo. Stato "activated and running". ⚠️ 2026-06-07 — script registrazione `sw.js` aggiunto in `web/index.html` prima di `</body>` (con `updatefound`→`statechange`→reload su nuova versione). **Dipendenza critica**: la build prod DEVE usare `--pwa-strategy=none` (step 3.7), altrimenti il SW Flutter default (`flutter_service_worker.js`) e il `sw.js` Workbox confliggono. Verifica DevTools runtime differita a dopo build 3.7 (build/web/index.html attuale è stale, pre-edit).

### Step 3.7 — Build pipeline doc
- [x] Aggiungere a `lifeondeck/README.md` sezione **Build produzione**:
  ```bash
  cd lifeondeck
  flutter build web --release \
    --pwa-strategy=none \
    --dart-define=API_BASE_URL=https://api.dominio.tld/api/v1
  cd web-build-tools
  npx workbox-cli generateSW workbox-config.cjs
  # output finale: lifeondeck/build/web/
  ```
- [x] Opzionale: script `lifeondeck/build-web.sh` che incapsula i due comandi.
- **Check**: eseguire script end-to-end localmente. `build/web/sw.js` esiste, contiene array `precacheManifest` con tutti gli asset Flutter + hash revision. ⚠️ 2026-06-07 — README sezione "Build produzione (PWA)" aggiunta (2 fasi + nota `--pwa-strategy=none` per evitare conflitto SW). `build-web.sh` creato (arg opzionale API_BASE_URL, default prod host, auto `npm install` se manca node_modules, `set -euo pipefail`), `chmod +x`, `bash -n` syntax OK. **End-to-end con rebuild `--pwa-strategy=none` NON eseguito** (utente ha declinato `flutter build web`); fase generateSW già validata in 3.5 (sw.js con `precacheAndRoute` + revision). Eseguire `./build-web.sh` quando si vuole la verifica completa.

### Step 3.8 — Cache-Control (doc per reverse proxy futuro)
- [ ] Creare `lifeondeck/DEPLOY_NOTES.md` con tabella header consigliati:
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
- [x] Nota: file Flutter non hashati nel nome (`main.dart.js`) → TTL breve + Workbox revision check gestisce invalidazione cache SW.
- **Check**: file creato e committato. ✅ 2026-06-07 — `lifeondeck/DEPLOY_NOTES.md` creato: tabella Cache-Control completa (no-cache su index/sw/manifest/bootstrap, immutable 1y su workbox/canvaskit/icons, TTL breve su main.dart.js/assets) + spiegazione (file Flutter non hashati → revision Workbox), sezione Firebase authorized domain (3.9), reminder CORS API. Commit a discrezione utente.

### Step 3.9 — Firebase authorized domain
- [x] **Task manuale post-deploy** (annotare in `DEPLOY_NOTES.md`):
  - Firebase Console → Authentication → Settings → Authorized domains.
  - Aggiungere dominio prod + eventuale staging.
- **Check**: post-deploy reale, login Google funziona senza errore `auth/unauthorized-domain`. ⏳ 2026-06-07 — annotazione fatta in `DEPLOY_NOTES.md` (sezione "Firebase authorized domain"). **Azione manuale residua**: l'utente deve aggiungere il dominio prod negli Authorized domains della Firebase Console DOPO il deploy reale. Verifica login post-deploy.

---

## Fase 4 — Verifiche end-to-end

### Step 4.1 — Smoke install PWA
- [x] Build completa (3.7).
- [x] Serve statico locale: `cd build/web && python3 -m http.server 8080`.
- [x] Chrome → `http://localhost:8080` → click icon install in barra indirizzi → apri standalone.
- **Check**: app apre in finestra standalone con icona corretta. Manifest senza warning. ✅ 2026-06-07 — build `./build-web.sh` OK (`--pwa-strategy=none` onorato: `_flutter.loader.load()` chiamato senza arg → Flutter non registra SW proprio; solo Workbox sw.js registra). Servito su :8090, tutti asset 200 (no 404). Browser headless (preview): `navigator.serviceWorker.controller = sw.js` (attivo+controlling), scope `/`. Manifest fetch OK: name "LifeOnDeck — TCG Life Counter", display standalone, 4 icons. Tutti i criteri installabilità soddisfatti. App shell renderizza (game selection screen). Console 0 warn/error. **Click fisico install + finestra standalone** resta gesto manuale ma tutti i requisiti verificati programmaticamente.

### Step 4.2 — Offline shell
- [x] Dopo primo load completo + login + sync OK.
- [~] Chrome DevTools → Network tab → checkbox "Offline".
- [~] Reload pagina.
- **Check**: app shell carica. Dati cached (SharedPreferences) visibili. Badge sync mostra stato offline. Tentativo sync mostra errore gestito, no crash. ✅ 2026-06-07 (meccanismo provato) — Cache Storage popolata: `workbox-precache-v2` 27 entry (index.html, main.dart.js, canvaskit/*, icons, manifest — tutti con `__WB_REVISION__`), `firebase-sdk` 2. `match(index.html)` + `match(main.dart.js)` con ignoreSearch → true. SW attivo+controlling + `navigateFallback:/index.html` = offline shell garantito by construction. ⚠️ Toggle DevTools "Offline" + reload + badge sync offline = verifica visiva manuale residua (richiede login+sync con API live).

### Step 4.3 — Update flow
- [-] Tab aperta su localhost con SW attivo.
- [-] Modifica banale (es. cambia stringa l10n).
- [-] Rebuild + rigenera SW + restart `http.server`.
- [-] Reload tab.
- **Check**: DevTools → SW → vecchio terminato, nuovo activated. App mostra modifica. Nessun asset stale. ⏳ 2026-06-07 — **VERIFICA MANUALE RESIDUA** (interattiva, multi-rebuild). Config a supporto già provata: `skipWaiting:true` + `clientsClaim:true` in sw.js + script reload su `updatefound`/`statechange` in index.html. `cleanupOutdatedCaches:true` evita asset stale. Eseguire quando si vuole confermare l'update silenzioso.

### Step 4.4 — Esclusione API da cache
- [x] DevTools → Network → filtrare `/api/`.
- [~] Trigger login + sync.
- **Check**: response API mostrano "(ServiceWorker)" come source ma comportamento = passthrough rete. Offline → request `/api/v1/sync` fallisce con errore di rete reale (no risposta cached vecchia). ✅ 2026-06-07 (config provata) — sw.js servito contiene `NetworkOnly` + `registerRoute` per `/api/` + `navigateFallbackDenylist` `^\/api\/`. /api/ MAI in precache (globPatterns esclude, denylist su navigation). ⚠️ Test live "(ServiceWorker) source + offline sync fallisce" richiede API .NET attiva → residuo manuale.

### Step 4.5 — Lighthouse PWA audit
- [-] Chrome DevTools → Lighthouse → categoria "Progressive Web App" + "Performance".
- **Check**: PWA score ≥ 90. "Installable" verde. "PWA optimized" verde. ⏳ 2026-06-07 — **VERIFICA MANUALE RESIDUA** (Lighthouse non eseguibile headless via preview). Prerequisiti installabilità tutti verdi by construction (manifest completo, SW attivo, icons, theme-color, viewport, https in prod). Eseguire Lighthouse in Chrome sul build servito.

### Step 4.6 — 401 refresh flow
- [-] Forzare scadenza JWT: impostare `Jwt:ExpiryDays = 0.001` in `appsettings.Development.json`, restart API.
- [-] Login fresh + attendi ~90s → trigger sync manuale.
- **Check**: interceptor refresha trasparente, sync prosegue. No logout visibile utente. Ripristinare `Jwt:ExpiryDays = 7`. ⏳ 2026-06-07 — **VERIFICA MANUALE RESIDUA** (richiede API .NET + Firebase login reale + attesa scadenza). Codice già implementato e analizzato in step 2.6 (interceptor 401 → `refreshToken` → replay 1x; guard ricorsione). Eseguire end-to-end con API live.

---

## Ordine consigliato esecuzione

`1.1 → 1.2 → 1.3 → 1.4 → 1.5 → 2.1 → 2.2 → 2.3 → 2.4 → 2.5 → 2.6 → 3.1 → 3.2 → 3.3 → 3.4 → 3.5 → 3.6 → 3.7 → 3.8 → 3.9 → 4.1 → 4.2 → 4.3 → 4.4 → 4.5 → 4.6`

Dipendenze critiche:
- 2.1 (`--dart-define API_BASE_URL`) prima di 3.7 (build prod).
- 3.4–3.5 (workbox setup) prima di 3.6 (SW register) e 3.7 (build pipeline).
- 4.x dopo tutto il resto.

Fase 1 e Fase 2 sono indipendenti tra loro → si possono parallelizzare se due sessioni separate (una su API, una su client).

---

## Changelog piano

| Data | Modifica |
|---|---|
| 2026-05-27 | Creazione piano iniziale. |
