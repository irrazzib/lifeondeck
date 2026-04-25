// GENERATED — run `flutterfire configure` to replace with real values.
// See: https://firebase.flutter.dev/docs/cli
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions not configured for ${defaultTargetPlatform.name}. '
          'Run flutterfire configure.',
        );
    }
  }

  // ── Web ──────────────────────────────────────────────────────────────────────
  // Replace all values after running: flutterfire configure
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'TODO_WEB_API_KEY',
    appId: 'TODO_WEB_APP_ID',
    messagingSenderId: 'TODO_SENDER_ID',
    projectId: 'TODO_PROJECT_ID',
    authDomain: 'TODO_PROJECT_ID.firebaseapp.com',
    storageBucket: 'TODO_PROJECT_ID.firebasestorage.app',
  );

  // ── Android ──────────────────────────────────────────────────────────────────
  // Requires google-services.json — see PLATFORM_TODO.md
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'TODO_ANDROID_API_KEY',
    appId: 'TODO_ANDROID_APP_ID',
    messagingSenderId: 'TODO_SENDER_ID',
    projectId: 'TODO_PROJECT_ID',
    storageBucket: 'TODO_PROJECT_ID.firebasestorage.app',
  );

  // ── iOS ───────────────────────────────────────────────────────────────────────
  // Requires GoogleService-Info.plist — see PLATFORM_TODO.md
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'TODO_IOS_API_KEY',
    appId: 'TODO_IOS_APP_ID',
    messagingSenderId: 'TODO_SENDER_ID',
    projectId: 'TODO_PROJECT_ID',
    storageBucket: 'TODO_PROJECT_ID.firebasestorage.app',
    iosBundleId: 'TODO_IOS_BUNDLE_ID',
  );
}
