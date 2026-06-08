# Platform Setup TODO

## 0. Prerequisiti (una volta sola)

- [ ] Crea progetto Firebase su https://console.firebase.google.com
- [ ] Abilita **Authentication > Sign-in method > Google**
- [ ] Installa FlutterFire CLI: `dart pub global activate flutterfire_cli`
- [ ] Esegui dalla root del progetto Flutter: `flutterfire configure`
  - Seleziona il progetto Firebase
  - Seleziona le piattaforme: web, android, ios
  - Il comando **sovrascrive** `lib/firebase_options.dart` con i valori reali

---

## 1. Web

- [ ] In Firebase Console > Authentication > Settings > Authorized domains:
  aggiungi il dominio della tua VM (es. `lifeondeck.example.com`)
- [ ] In `web/index.html` **non serve** aggiungere Firebase SDK manualmente —
  `firebase_core` Flutter lo gestisce via `firebase_options.dart`
- [ ] CORS backend: aggiorna `Program.cs` per restringere `AllowAnyOrigin()`
  al dominio reale in produzione

---

## 2. Android

- [ ] In Firebase Console > Project settings > Add app > Android
  - Package name: trovalo in `android/app/build.gradle` → `applicationId`
  - (Opzionale) SHA-1 fingerprint per Google Sign-In nativo
- [ ] Scarica `google-services.json` e copialo in `android/app/google-services.json`
- [ ] In `android/build.gradle` (project-level), aggiungi classpath Google services:
  ```groovy
  classpath 'com.google.gms:google-services:4.4.2'
  ```
- [ ] In `android/app/build.gradle` (app-level), applica il plugin in fondo:
  ```groovy
  apply plugin: 'com.google.gms.google-services'
  ```
- [ ] `flutter pub get && flutter run` su dispositivo/emulatore Android

---

## 3. iOS

- [ ] In Firebase Console > Project settings > Add app > iOS
  - Bundle ID: trovalo in Xcode > Runner > General > Bundle Identifier
- [ ] Scarica `GoogleService-Info.plist` e copialo in `ios/Runner/GoogleService-Info.plist`
  tramite **Xcode** (drag & drop nel gruppo Runner, spunta "Copy items if needed")
- [ ] Aggiungi URL scheme per Google Sign-In:
  - Xcode > Runner > Info > URL Types > `+`
  - URL Schemes: il valore `REVERSED_CLIENT_ID` da `GoogleService-Info.plist`
    (es. `com.googleusercontent.apps.1234567890-abcdef`)
- [ ] In `ios/Podfile` assicurati che la minimum deployment target sia ≥ 13.0:
  ```ruby
  platform :ios, '13.0'
  ```
- [ ] `cd ios && pod install && cd ..`
- [ ] `flutter run` su simulatore/dispositivo iOS

---

## 4. Backend (.NET API)

- [ ] Imposta `Firebase:ProjectId` in `appsettings.json` (o env var `Firebase__ProjectId`)
  con l'ID esatto del progetto Firebase (es. `lifeondeck-abc12`)
- [ ] Cambia `Jwt:SecretKey` con una stringa random sicura (≥ 32 caratteri)
- [ ] Cambia `ConnectionStrings:Default` con i dati reali del PostgreSQL sulla VM
- [ ] Esegui migrations:
  ```bash
  dotnet ef migrations add InitialCreate
  dotnet ef database update
  ```
- [ ] Configura HTTPS sul reverse proxy (nginx/caddy) davanti all'API

---

## 5. Note sicurezza produzione

- Imposta variabili d'ambiente invece di editare `appsettings.json`:
  `FIREBASE__PROJECTID`, `JWT__SECRETKEY`, `CONNECTIONSTRINGS__DEFAULT`
- Restringi CORS a dominio specifico in `Program.cs`
- Abilita HTTPS redirect (già presente, verifica che il reverse proxy termini TLS)
