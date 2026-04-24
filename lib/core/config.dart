import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'constants.dart';

class AppRuntimeConfig {
  static final ValueNotifier<AppLanguage> language = ValueNotifier<AppLanguage>(
    AppLanguage.system,
  );
}

class AppOrientationLock {
  const AppOrientationLock._();

  static const List<DeviceOrientation> _mobilePortraitOnly =
      <DeviceOrientation>[DeviceOrientation.portraitUp];

  static bool get _shouldLockForCurrentPlatform {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }

  // The current mobile life-counter UX is designed for a fixed portrait canvas.
  // Keeping the lock centralized avoids fragile per-route orientation toggles.
  static Future<void> enforceMobilePortrait() async {
    if (!_shouldLockForCurrentPlatform) {
      return;
    }
    await SystemChrome.setPreferredOrientations(_mobilePortraitOnly);
  }
}
