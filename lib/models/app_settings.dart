import 'package:flutter/material.dart';

import '../core/constants.dart';

@immutable
class AppSettings {
  const AppSettings({
    required this.playerOneName,
    required this.playerTwoName,
    required this.startupTcgKey,
    required this.appLanguageKey,
    required this.backgroundStartColor,
    required this.backgroundEndColor,
    required this.buttonColor,
    required this.lifePointsBackgroundColor,
    required this.playerOneColor,
    required this.playerTwoColor,
  });

  factory AppSettings.defaults() {
    return const AppSettings(
      playerOneName: 'Player 1',
      playerTwoName: 'Player 2',
      startupTcgKey: 'yugioh',
      appLanguageKey: 'system',
      backgroundStartColor: Color(0xFF141414),
      backgroundEndColor: Color(0xFF341212),
      buttonColor: Color(0xFF2B2424),
      lifePointsBackgroundColor: Color(0xFF261E1E),
      playerOneColor: Color(0xFF261E1E),
      playerTwoColor: Color(0xFF1E2626),
    );
  }

  final String playerOneName;
  final String playerTwoName;
  final String startupTcgKey;
  final String appLanguageKey;
  final Color backgroundStartColor;
  final Color backgroundEndColor;
  final Color buttonColor;
  final Color lifePointsBackgroundColor;
  final Color playerOneColor;
  final Color playerTwoColor;

  AppSettings copyWith({
    String? playerOneName,
    String? playerTwoName,
    String? startupTcgKey,
    String? appLanguageKey,
    Color? backgroundStartColor,
    Color? backgroundEndColor,
    Color? buttonColor,
    Color? lifePointsBackgroundColor,
    Color? playerOneColor,
    Color? playerTwoColor,
  }) {
    return AppSettings(
      playerOneName: playerOneName ?? this.playerOneName,
      playerTwoName: playerTwoName ?? this.playerTwoName,
      startupTcgKey: startupTcgKey ?? this.startupTcgKey,
      appLanguageKey: appLanguageKey ?? this.appLanguageKey,
      backgroundStartColor: backgroundStartColor ?? this.backgroundStartColor,
      backgroundEndColor: backgroundEndColor ?? this.backgroundEndColor,
      buttonColor: buttonColor ?? this.buttonColor,
      lifePointsBackgroundColor:
          lifePointsBackgroundColor ?? this.lifePointsBackgroundColor,
      playerOneColor: playerOneColor ?? this.playerOneColor,
      playerTwoColor: playerTwoColor ?? this.playerTwoColor,
    );
  }

  Map<String, Object> toJson() {
    return <String, Object>{
      'playerOneName': playerOneName,
      'playerTwoName': playerTwoName,
      'startupTcgKey': startupTcgKey,
      'appLanguageKey': appLanguageKey,
      'backgroundStartColor': backgroundStartColor.toARGB32(),
      'backgroundEndColor': backgroundEndColor.toARGB32(),
      'buttonColor': buttonColor.toARGB32(),
      'lifePointsBackgroundColor': lifePointsBackgroundColor.toARGB32(),
      'playerOneColor': playerOneColor.toARGB32(),
      'playerTwoColor': playerTwoColor.toARGB32(),
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final AppSettings fallback = AppSettings.defaults();

    Color parseColor(String key, Color fallbackColor) {
      final Object? raw = json[key];
      if (raw is int) {
        return Color(raw);
      }
      if (raw is String) {
        final int? parsed = int.tryParse(raw);
        if (parsed != null) {
          return Color(parsed);
        }
      }
      return fallbackColor;
    }

    String parseName(String key, String fallbackName) {
      final Object? raw = json[key];
      if (raw is! String) {
        return fallbackName;
      }
      final String trimmed = raw.trim();
      if (trimmed.isEmpty) {
        return fallbackName;
      }
      return trimmed;
    }

    String parseTcgKey(String key, String fallbackKey) {
      final Object? raw = json[key];
      return normalizeTcgKey(
        raw is String ? raw : null,
        fallback: fallbackKey,
      );
    }

    return AppSettings(
      playerOneName: parseName('playerOneName', fallback.playerOneName),
      playerTwoName: parseName('playerTwoName', fallback.playerTwoName),
      startupTcgKey: parseTcgKey('startupTcgKey', fallback.startupTcgKey),
      appLanguageKey: AppLanguageX.fromStorageKey(
        json['appLanguageKey'] as String?,
      ).storageKey,
      backgroundStartColor: parseColor(
        'backgroundStartColor',
        fallback.backgroundStartColor,
      ),
      backgroundEndColor: parseColor(
        'backgroundEndColor',
        fallback.backgroundEndColor,
      ),
      buttonColor: parseColor('buttonColor', fallback.buttonColor),
      lifePointsBackgroundColor: parseColor(
        'lifePointsBackgroundColor',
        fallback.lifePointsBackgroundColor,
      ),
      playerOneColor: parseColor('playerOneColor', fallback.playerOneColor),
      playerTwoColor: parseColor('playerTwoColor', fallback.playerTwoColor),
    );
  }
}
