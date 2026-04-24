import 'dart:math';
import 'package:flutter/material.dart';
import '../models/sideboard.dart';

const Set<String> supportedTcgStorageKeys = <String>{
  'yugioh',
  'mtg',
  'riftbound',
  'lorcana',
};
const String appBuildTag = 'build 8286103';
const int defaultDieSides = 6;
const Duration diceResultVisibilityDuration = Duration(seconds: 3);
const List<Color> appColorPalette = <Color>[
  Color(0xFF141414),
  Color(0xFF341212),
  Color(0xFF1E1B1B),
  Color(0xFF18321D),
  Color(0xFF15293B),
  Color(0xFF2E244A),
  Color(0xFF4A2A12),
  Color(0xFF5B2424),
  Color(0xFF1C5D35),
  Color(0xFF245D5A),
  Color(0xFF3B3B3B),
  Color(0xFF264653),
];

int nextDieValue(Random random, {int sides = defaultDieSides}) {
  return random.nextInt(sides) + 1;
}

enum AppLanguage { system, english, italian }

extension AppLanguageX on AppLanguage {
  static const Map<AppLanguage, String> _storageCodes = <AppLanguage, String>{
    AppLanguage.english: 'en',
    AppLanguage.italian: 'it',
  };

  String get storageKey => _storageCodes[this] ?? 'system';

  String get localeCode {
    if (this == AppLanguage.system) {
      final String systemCode = WidgetsBinding
          .instance.platformDispatcher.locale.languageCode
          .toLowerCase();
      return _storageCodes.values.firstWhere(
        (String code) => systemCode.startsWith(code),
        orElse: () => 'en',
      );
    }
    return _storageCodes[this] ?? 'en';
  }

  Locale? get materialLocale {
    final String? code = _storageCodes[this];
    return code == null ? null : Locale(code);
  }

  static AppLanguage fromStorageKey(String? raw) {
    final String normalized = (raw ?? '').trim().toLowerCase();
    return _storageCodes.entries
        .firstWhere(
          (MapEntry<AppLanguage, String> e) => e.value == normalized,
          orElse: () => const MapEntry<AppLanguage, String>(
            AppLanguage.system,
            'system',
          ),
        )
        .key;
  }
}

const List<String> supportedGameStages = <String>['G1', 'G2', 'G3'];
const List<String> supportedMatchResults = <String>['Win', 'Loss', 'Draw'];
const String historyExportSchema = 'TCG_LIFE_COUNTER_HISTORY_V1';

enum SupportedTcg { yugioh, mtg, riftbound, lorcana }

const List<SupportedTcg> supportedTcgAlphabeticalOrder = <SupportedTcg>[
  SupportedTcg.lorcana,
  SupportedTcg.mtg,
  SupportedTcg.riftbound,
  SupportedTcg.yugioh,
];

extension SupportedTcgX on SupportedTcg {
  String get label {
    switch (this) {
      case SupportedTcg.yugioh:
        return 'Yugioh';
      case SupportedTcg.mtg:
        return 'MTG';
      case SupportedTcg.riftbound:
        return 'Riftbound';
      case SupportedTcg.lorcana:
        return 'Lorcana';
    }
  }

  String get storageKey {
    switch (this) {
      case SupportedTcg.yugioh:
        return 'yugioh';
      case SupportedTcg.mtg:
        return 'mtg';
      case SupportedTcg.riftbound:
        return 'riftbound';
      case SupportedTcg.lorcana:
        return 'lorcana';
    }
  }

  static SupportedTcg fromStorageKey(String? raw) {
    final String normalized = (raw ?? '').trim().toLowerCase();
    switch (normalized) {
      case 'lorcana':
        return SupportedTcg.lorcana;
      case 'mtg':
        return SupportedTcg.mtg;
      case 'riftbound':
        return SupportedTcg.riftbound;
      case 'yugioh':
      default:
        return SupportedTcg.yugioh;
    }
  }

  ({Color bgStart, Color bgEnd}) get homePresetColors {
    switch (this) {
      case SupportedTcg.yugioh:
        return (bgStart: const Color(0xFF1A0A0A), bgEnd: const Color(0xFF3D1A1A));
      case SupportedTcg.mtg:
        return (bgStart: const Color(0xFF0A0F1A), bgEnd: const Color(0xFF1A2B3D));
      case SupportedTcg.riftbound:
        return (bgStart: const Color(0xFF0A1A0A), bgEnd: const Color(0xFF1A3A1A));
      case SupportedTcg.lorcana:
        return (bgStart: const Color(0xFF150A1A), bgEnd: const Color(0xFF3D1A50));
    }
  }
}

enum DuelRuleSet { yugioh, mtg }

String formatDateTime(DateTime date, [BuildContext? context]) {
  final DateTime local = date.toLocal();
  if (context != null) {
    final MaterialLocalizations localizations = MaterialLocalizations.of(
      context,
    );
    final String datePart = localizations.formatCompactDate(local);
    final String timePart = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: true,
    );
    return '$datePart $timePart';
  }
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${twoDigits(local.day)}/${twoDigits(local.month)}/${local.year} ${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

int gameStageSortKey(String rawStage) {
  final String normalized = rawStage.trim().toUpperCase();
  if (normalized.startsWith('G')) {
    final int? parsed = int.tryParse(normalized.substring(1));
    if (parsed != null) {
      return parsed;
    }
  }
  return 999;
}

String normalizeTcgKey(String? raw, {String fallback = 'yugioh'}) {
  final String normalized = (raw ?? '').trim().toLowerCase();
  if (supportedTcgStorageKeys.contains(normalized)) {
    return normalized;
  }
  return fallback;
}

String? supportedTcgKeyOrNull(Object? raw) {
  if (raw is! String) {
    return null;
  }
  final String normalized = raw.trim().toLowerCase();
  if (supportedTcgStorageKeys.contains(normalized)) {
    return normalized;
  }
  return null;
}

String normalizeDeckName(String raw) {
  return raw.trim().toLowerCase();
}

SideboardDeck? findUniqueDeckByName(
  Iterable<SideboardDeck> decks,
  String rawName,
) {
  final String normalized = normalizeDeckName(rawName);
  if (normalized.isEmpty) {
    return null;
  }
  SideboardDeck? match;
  for (final SideboardDeck deck in decks) {
    if (normalizeDeckName(deck.name) != normalized) {
      continue;
    }
    if (match != null) {
      return null;
    }
    match = deck;
  }
  return match;
}

bool hasDeckNameConflict(
  Iterable<SideboardDeck> decks,
  String rawName, {
  String excludedDeckId = '',
}) {
  final String normalized = normalizeDeckName(rawName);
  if (normalized.isEmpty) {
    return false;
  }
  final String trimmedExcludedId = excludedDeckId.trim();
  for (final SideboardDeck deck in decks) {
    if (trimmedExcludedId.isNotEmpty && deck.id == trimmedExcludedId) {
      continue;
    }
    if (normalizeDeckName(deck.name) == normalized) {
      return true;
    }
  }
  return false;
}

bool deckMatchesFormat(SideboardDeck deck, String format) {
  final String normalizedFormat = format.trim().toLowerCase();
  if (normalizedFormat.isEmpty) {
    return true;
  }
  return deck.format.trim().toLowerCase() == normalizedFormat;
}

List<SideboardDeck> filterDecksByFormat(
  Iterable<SideboardDeck> decks,
  String format,
) {
  return decks
      .where((SideboardDeck deck) => deckMatchesFormat(deck, format))
      .toList(growable: false);
}
