import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/config.dart';
import 'core/constants.dart';
import 'l10n/app_strings.dart';
import 'screens/home/home_screen.dart';

class YugiLifeCounterApp extends StatefulWidget {
  const YugiLifeCounterApp({super.key});

  @override
  State<YugiLifeCounterApp> createState() => _YugiLifeCounterAppState();
}

class _YugiLifeCounterAppState extends State<YugiLifeCounterApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(AppOrientationLock.enforceMobilePortrait());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(AppOrientationLock.enforceMobilePortrait());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppRuntimeConfig.language,
      builder: (BuildContext context, AppLanguage language, Widget? _) {
        final String localeCode = language.localeCode;
        return MaterialApp(
          title: const AppStrings('en').t('app.title'),
          debugShowCheckedModeBanner: false,
          locale: language.materialLocale,
          supportedLocales: const <Locale>[Locale('en'), Locale('it')],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFE53935),
              brightness: Brightness.dark,
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(foregroundColor: Colors.white),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(foregroundColor: Colors.white),
            ),
          ),
          builder: (BuildContext context, Widget? child) {
            return AppTextScope(
              strings: AppStrings(localeCode),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const HomeScreen(),
        );
      },
    );
  }
}
