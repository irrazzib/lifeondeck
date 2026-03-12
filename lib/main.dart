import 'dart:convert';
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

const Set<String> _supportedTcgStorageKeys = <String>{
  'yugioh',
  'mtg',
  'riftbound',
  'lorcana',
};

String _normalizeTcgKey(String? raw, {String fallback = 'yugioh'}) {
  final String normalized = (raw ?? '').trim().toLowerCase();
  if (_supportedTcgStorageKeys.contains(normalized)) {
    return normalized;
  }
  return fallback;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  runApp(const YugiLifeCounterApp());
}

class YugiLifeCounterApp extends StatelessWidget {
  const YugiLifeCounterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TCG Life Counter',
      debugShowCheckedModeBanner: false,
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
      home: const HomeScreen(),
    );
  }
}

@immutable
class AppSettings {
  const AppSettings({
    required this.playerOneName,
    required this.playerTwoName,
    required this.startupTcgKey,
    required this.backgroundStartColor,
    required this.backgroundEndColor,
    required this.buttonColor,
    required this.lifePointsBackgroundColor,
  });

  factory AppSettings.defaults() {
    return const AppSettings(
      playerOneName: 'Player 1',
      playerTwoName: 'Player 2',
      startupTcgKey: 'yugioh',
      backgroundStartColor: Color(0xFF141414),
      backgroundEndColor: Color(0xFF341212),
      buttonColor: Color(0xFF2B2424),
      lifePointsBackgroundColor: Color(0xFF261E1E),
    );
  }

  final String playerOneName;
  final String playerTwoName;
  final String startupTcgKey;
  final Color backgroundStartColor;
  final Color backgroundEndColor;
  final Color buttonColor;
  final Color lifePointsBackgroundColor;

  AppSettings copyWith({
    String? playerOneName,
    String? playerTwoName,
    String? startupTcgKey,
    Color? backgroundStartColor,
    Color? backgroundEndColor,
    Color? buttonColor,
    Color? lifePointsBackgroundColor,
  }) {
    return AppSettings(
      playerOneName: playerOneName ?? this.playerOneName,
      playerTwoName: playerTwoName ?? this.playerTwoName,
      startupTcgKey: startupTcgKey ?? this.startupTcgKey,
      backgroundStartColor: backgroundStartColor ?? this.backgroundStartColor,
      backgroundEndColor: backgroundEndColor ?? this.backgroundEndColor,
      buttonColor: buttonColor ?? this.buttonColor,
      lifePointsBackgroundColor:
          lifePointsBackgroundColor ?? this.lifePointsBackgroundColor,
    );
  }

  Map<String, Object> toJson() {
    return <String, Object>{
      'playerOneName': playerOneName,
      'playerTwoName': playerTwoName,
      'startupTcgKey': startupTcgKey,
      'backgroundStartColor': backgroundStartColor.toARGB32(),
      'backgroundEndColor': backgroundEndColor.toARGB32(),
      'buttonColor': buttonColor.toARGB32(),
      'lifePointsBackgroundColor': lifePointsBackgroundColor.toARGB32(),
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
      return _normalizeTcgKey(
        raw is String ? raw : null,
        fallback: fallbackKey,
      );
    }

    return AppSettings(
      playerOneName: parseName('playerOneName', fallback.playerOneName),
      playerTwoName: parseName('playerTwoName', fallback.playerTwoName),
      startupTcgKey: parseTcgKey('startupTcgKey', fallback.startupTcgKey),
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
    );
  }
}

@immutable
class GameRecord {
  const GameRecord({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.gameStage,
    required this.notes,
    required this.lifePointHistory,
    this.tcgKey = 'yugioh',
    this.deckId = '',
    this.matchResult = '',
    this.opponentName = '',
    this.deckName = '',
    this.playerOneName = 'Player 1',
    this.playerTwoName = 'Player 2',
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final String gameStage;
  final String notes;
  final List<String> lifePointHistory;
  final String tcgKey;
  final String deckId;
  final String matchResult;
  final String opponentName;
  final String deckName;
  final String playerOneName;
  final String playerTwoName;

  GameRecord copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    String? gameStage,
    String? notes,
    List<String>? lifePointHistory,
    String? tcgKey,
    String? deckId,
    String? matchResult,
    String? opponentName,
    String? deckName,
    String? playerOneName,
    String? playerTwoName,
  }) {
    return GameRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      gameStage: gameStage ?? this.gameStage,
      notes: notes ?? this.notes,
      lifePointHistory: lifePointHistory ?? this.lifePointHistory,
      tcgKey: tcgKey ?? this.tcgKey,
      deckId: deckId ?? this.deckId,
      matchResult: matchResult ?? this.matchResult,
      opponentName: opponentName ?? this.opponentName,
      deckName: deckName ?? this.deckName,
      playerOneName: playerOneName ?? this.playerOneName,
      playerTwoName: playerTwoName ?? this.playerTwoName,
    );
  }

  Map<String, Object> toJson() {
    return <String, Object>{
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'gameStage': gameStage,
      'notes': notes,
      'lifePointHistory': lifePointHistory,
      'tcgKey': tcgKey,
      'deckId': deckId,
      'matchResult': matchResult,
      'opponentName': opponentName,
      'deckName': deckName,
      'playerOneName': playerOneName,
      'playerTwoName': playerTwoName,
    };
  }

  factory GameRecord.fromJson(Map<String, dynamic> json) {
    final String id = (json['id'] as String?)?.trim().isNotEmpty == true
        ? json['id'] as String
        : DateTime.now().microsecondsSinceEpoch.toString();
    final String title = (json['title'] as String?)?.trim().isNotEmpty == true
        ? json['title'] as String
        : 'Duel';
    final String rawGameStage = ((json['gameStage'] as String?) ?? '')
        .trim()
        .toUpperCase();
    final String gameStage = _supportedGameStages.contains(rawGameStage)
        ? rawGameStage
        : 'G1';
    final String notes = (json['notes'] as String?) ?? '';
    final String deckId = ((json['deckId'] as String?) ?? '').trim();
    final String rawResult = ((json['matchResult'] as String?) ?? '').trim();
    final String matchResult = _supportedMatchResults.contains(rawResult)
        ? rawResult
        : '';
    final String opponentName = ((json['opponentName'] as String?) ?? '')
        .trim();
    final String deckName = ((json['deckName'] as String?) ?? '').trim();
    final String playerOneName = ((json['playerOneName'] as String?) ?? '')
        .trim();
    final String playerTwoName = ((json['playerTwoName'] as String?) ?? '')
        .trim();
    final bool hasRawTcgKey =
        json['tcgKey'] is String &&
        (json['tcgKey'] as String).trim().isNotEmpty;
    final String inferredTcgFallback = title.toLowerCase().startsWith('mtg')
        ? 'mtg'
        : 'yugioh';
    final String tcgKey = _normalizeTcgKey(
      hasRawTcgKey ? json['tcgKey'] as String : null,
      fallback: inferredTcgFallback,
    );
    final Object? rawHistory = json['lifePointHistory'];
    final List<String> lifePointHistory = rawHistory is List
        ? rawHistory
              .whereType<Object?>()
              .map((Object? entry) => entry?.toString() ?? '')
              .where((String entry) => entry.trim().isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    final String? rawDate = json['createdAt'] as String?;
    final DateTime createdAt =
        DateTime.tryParse(rawDate ?? '') ?? DateTime.now();

    return GameRecord(
      id: id,
      title: title,
      createdAt: createdAt,
      gameStage: gameStage,
      notes: notes,
      lifePointHistory: lifePointHistory,
      tcgKey: tcgKey,
      deckId: deckId,
      matchResult: matchResult,
      opponentName: opponentName,
      deckName: deckName,
      playerOneName: playerOneName.isEmpty ? 'Player 1' : playerOneName,
      playerTwoName: playerTwoName.isEmpty ? 'Player 2' : playerTwoName,
    );
  }
}

@immutable
class DuelResultPayload {
  const DuelResultPayload({
    required this.lifePointHistory,
    required this.gameStage,
    required this.opponentName,
    required this.deckName,
    required this.matchResult,
    this.shouldSave = true,
  });

  final List<String> lifePointHistory;
  final String gameStage;
  final String opponentName;
  final String deckName;
  final String matchResult;
  final bool shouldSave;
}

@immutable
class TwoPlayerLifeEvent {
  const TwoPlayerLifeEvent({
    required this.player,
    required this.delta,
    required this.resultingLife,
  });

  final int player;
  final int delta;
  final int resultingLife;
}

List<String> _buildTwoPlayerHistoryTable({
  required String playerOneName,
  required String playerTwoName,
  required int initialPlayerOneLife,
  required int initialPlayerTwoLife,
  required List<TwoPlayerLifeEvent> events,
}) {
  String formatSigned(int value) => value > 0 ? '+$value' : '$value';

  final List<(String, String)> rows = <(String, String)>[
    (playerOneName, playerTwoName),
    ('$initialPlayerOneLife', '$initialPlayerTwoLife'),
    for (final TwoPlayerLifeEvent event in events)
      event.player == 1
          ? ('${formatSigned(event.delta)} = ${event.resultingLife}', '')
          : ('', '${formatSigned(event.delta)} = ${event.resultingLife}'),
  ];

  int leftWidth = 0;
  int rightWidth = 0;
  for (final (String left, String right) in rows) {
    leftWidth = max(leftWidth, left.length);
    rightWidth = max(rightWidth, right.length);
  }

  return rows
      .map(
        ((String, String) row) =>
            '${row.$1.padRight(leftWidth)} | ${row.$2.padRight(rightWidth)}',
      )
      .toList(growable: false);
}

bool _looksLikeTwoPlayerHistoryTable(List<String> lines) {
  if (lines.length < 2) {
    return false;
  }
  for (final String line in lines) {
    if (!line.contains('|')) {
      return false;
    }
  }
  return true;
}

List<(String, String)> _splitTwoPlayerHistoryRows(List<String> lines) {
  return lines
      .map(((String line) {
        final int separatorIndex = line.indexOf('|');
        if (separatorIndex < 0) {
          return (line.trim(), '');
        }
        final String left = line.substring(0, separatorIndex).trimRight();
        final String right = line.substring(separatorIndex + 1).trimLeft();
        return (left, right);
      }))
      .toList(growable: false);
}

Widget _buildLifeHistoryView({
  required List<String> lines,
  required Color dividerColor,
}) {
  if (!_looksLikeTwoPlayerHistoryTable(lines)) {
    return SingleChildScrollView(
      child: SelectableText(
        lines.join('\n'),
        style: const TextStyle(height: 1.35, fontFamily: 'monospace'),
      ),
    );
  }

  final List<(String, String)> rows = _splitTwoPlayerHistoryRows(lines);
  final (String, String) header = rows.first;
  final List<(String, String)> bodyRows = rows.skip(1).toList(growable: false);

  Widget buildRow((String, String) row, {required bool isHeader, int? index}) {
    final bool isOdd = index != null && index.isOdd;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: isHeader ? 8 : 7),
      decoration: isHeader
          ? BoxDecoration(
              border: Border(bottom: BorderSide(color: dividerColor, width: 1)),
            )
          : BoxDecoration(
              color: isOdd
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.transparent,
              border: Border(
                bottom: BorderSide(color: dividerColor.withValues(alpha: 0.45)),
              ),
            ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              row.$1,
              textAlign: TextAlign.left,
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: isHeader ? FontWeight.w800 : FontWeight.w500,
                fontSize: isHeader ? 13 : 12.5,
              ),
            ),
          ),
          Container(width: 1, height: isHeader ? 24 : 20, color: dividerColor),
          Expanded(
            child: Text(
              row.$2,
              textAlign: TextAlign.left,
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: isHeader ? FontWeight.w800 : FontWeight.w500,
                fontSize: isHeader ? 13 : 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  return SingleChildScrollView(
    child: Column(
      children: [
        buildRow(header, isHeader: true),
        for (int index = 0; index < bodyRows.length; index += 1)
          buildRow(bodyRows[index], isHeader: false, index: index),
      ],
    ),
  );
}

@immutable
class SideboardCardEntry {
  const SideboardCardEntry({required this.name, required this.copies});

  final String name;
  final int copies;

  SideboardCardEntry copyWith({String? name, int? copies}) {
    return SideboardCardEntry(
      name: name ?? this.name,
      copies: copies ?? this.copies,
    );
  }

  Map<String, Object> toJson() {
    return <String, Object>{'name': name, 'copies': copies};
  }

  factory SideboardCardEntry.fromJson(Map<String, dynamic> json) {
    final String rawName = (json['name'] as String?)?.trim() ?? '';
    final String name = rawName.isEmpty ? 'Card' : rawName;

    int copies = 1;
    final Object? rawCopies = json['copies'];
    if (rawCopies is int) {
      copies = rawCopies;
    } else if (rawCopies is String) {
      copies = int.tryParse(rawCopies) ?? 1;
    }
    copies = copies.clamp(1, 4);

    return SideboardCardEntry(name: name, copies: copies);
  }
}

@immutable
class SideboardMatchup {
  const SideboardMatchup({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.sideIn,
    required this.sideOut,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final List<SideboardCardEntry> sideIn;
  final List<SideboardCardEntry> sideOut;

  SideboardMatchup copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    List<SideboardCardEntry>? sideIn,
    List<SideboardCardEntry>? sideOut,
  }) {
    return SideboardMatchup(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      sideIn: sideIn ?? this.sideIn,
      sideOut: sideOut ?? this.sideOut,
    );
  }

  Map<String, Object> toJson() {
    return <String, Object>{
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'sideIn': sideIn
          .map((SideboardCardEntry entry) => entry.toJson())
          .toList(growable: false),
      'sideOut': sideOut
          .map((SideboardCardEntry entry) => entry.toJson())
          .toList(growable: false),
    };
  }

  factory SideboardMatchup.fromJson(Map<String, dynamic> json) {
    final String id = (json['id'] as String?)?.trim().isNotEmpty == true
        ? json['id'] as String
        : DateTime.now().microsecondsSinceEpoch.toString();
    final String name = (json['name'] as String?)?.trim().isNotEmpty == true
        ? json['name'] as String
        : 'Matchup';
    final String rawCreatedAt = (json['createdAt'] as String?) ?? '';
    DateTime createdAt = DateTime.tryParse(rawCreatedAt) ?? DateTime.now();
    if (rawCreatedAt.trim().isEmpty) {
      final int? createdAtFromId = int.tryParse(id);
      if (createdAtFromId != null) {
        createdAt = DateTime.fromMicrosecondsSinceEpoch(createdAtFromId);
      }
    }

    List<SideboardCardEntry> parseCardList(String key) {
      final Object? raw = json[key];
      if (raw is! List) {
        return const <SideboardCardEntry>[];
      }

      final List<SideboardCardEntry> parsed = <SideboardCardEntry>[];
      for (final Object? item in raw) {
        if (item is Map) {
          parsed.add(
            SideboardCardEntry.fromJson(Map<String, dynamic>.from(item)),
          );
          continue;
        }

        final String asText = item?.toString().trim() ?? '';
        if (asText.isEmpty) {
          continue;
        }
        parsed.add(SideboardCardEntry(name: asText, copies: 1));
      }
      return parsed.toList(growable: false);
    }

    return SideboardMatchup(
      id: id,
      name: name,
      createdAt: createdAt,
      sideIn: parseCardList('sideIn'),
      sideOut: parseCardList('sideOut'),
    );
  }
}

@immutable
class SideboardDeck {
  const SideboardDeck({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.isFavorite,
    required this.userNotes,
    required this.matchups,
    this.tag = '',
    this.tcgKey = 'yugioh',
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final bool isFavorite;
  final String userNotes;
  final List<SideboardMatchup> matchups;
  final String tag;
  final String tcgKey;

  SideboardDeck copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    bool? isFavorite,
    String? userNotes,
    List<SideboardMatchup>? matchups,
    String? tag,
    String? tcgKey,
  }) {
    return SideboardDeck(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      isFavorite: isFavorite ?? this.isFavorite,
      userNotes: userNotes ?? this.userNotes,
      matchups: matchups ?? this.matchups,
      tag: tag ?? this.tag,
      tcgKey: tcgKey ?? this.tcgKey,
    );
  }

  Map<String, Object> toJson() {
    return <String, Object>{
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'isFavorite': isFavorite,
      'userNotes': userNotes,
      'matchups': matchups
          .map((SideboardMatchup matchup) => matchup.toJson())
          .toList(growable: false),
      'tag': tag,
      'tcgKey': tcgKey,
    };
  }

  factory SideboardDeck.fromJson(Map<String, dynamic> json) {
    final String id = (json['id'] as String?)?.trim().isNotEmpty == true
        ? json['id'] as String
        : DateTime.now().microsecondsSinceEpoch.toString();
    final String name = (json['name'] as String?)?.trim().isNotEmpty == true
        ? json['name'] as String
        : 'Deck';
    final DateTime createdAt =
        DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
        DateTime.now();
    final bool isFavorite = json['isFavorite'] == true;
    final String userNotes = (json['userNotes'] as String?) ?? '';
    final String tag = ((json['tag'] as String?) ?? '').trim();
    final String tcgKey = _normalizeTcgKey(json['tcgKey'] as String?);
    final Object? rawMatchups = json['matchups'];
    final List<SideboardMatchup> parsedMatchups = rawMatchups is List
        ? rawMatchups
              .whereType<Map>()
              .map(
                (Map item) =>
                    SideboardMatchup.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList(growable: false)
        : const <SideboardMatchup>[];

    return SideboardDeck(
      id: id,
      name: name,
      createdAt: createdAt,
      isFavorite: isFavorite,
      userNotes: userNotes,
      matchups: parsedMatchups,
      tag: tag,
      tcgKey: tcgKey,
    );
  }
}

@immutable
class SideboardBookResult {
  const SideboardBookResult({required this.decks, required this.records});

  final List<SideboardDeck> decks;
  final List<GameRecord> records;
}

@immutable
class SideboardDeckEditResult {
  const SideboardDeckEditResult({required this.deck, required this.records});

  final SideboardDeck deck;
  final List<GameRecord> records;
}

const List<String> _supportedGameStages = <String>['G1', 'G2', 'G3'];
const List<String> _supportedMatchResults = <String>['Win', 'Loss', 'Draw'];
const String _historyExportSchema = 'TCG_LIFE_COUNTER_HISTORY_V1';

enum SupportedTcg { yugioh, mtg, riftbound, lorcana }

const List<SupportedTcg> _supportedTcgAlphabeticalOrder = <SupportedTcg>[
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
}

enum DuelRuleSet { yugioh, mtg }

String _formatDateTime(DateTime date) {
  final DateTime local = date.toLocal();
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${twoDigits(local.day)}/${twoDigits(local.month)}/${local.year} ${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _premiumKey = 'premium_unlocked_v1';
  static const String _settingsKey = 'app_settings_v1';
  static const String _recordsKey = 'game_records_v1';
  static const String _sideboardDecksKey = 'sideboard_decks_v1';
  static const String _lastDeckByTcgKey = 'last_selected_deck_by_tcg_v1';

  bool _isLoading = true;
  bool _premiumUnlocked = false;
  AppSettings _settings = AppSettings.defaults();
  List<GameRecord> _gameRecords = <GameRecord>[];
  List<SideboardDeck> _sideboardDecks = <SideboardDeck>[];
  Map<String, String> _lastDeckByTcg = <String, String>{};
  SupportedTcg _selectedGame = SupportedTcg.yugioh;

  String get _selectedTcgKey => _selectedGame.storageKey;
  bool get _isImplementedGame =>
      _selectedGame != SupportedTcg.riftbound &&
      _selectedGame != SupportedTcg.lorcana;

  List<GameRecord> _recordsForSelectedGame() {
    return _gameRecords
        .where((GameRecord record) => record.tcgKey == _selectedTcgKey)
        .toList(growable: false);
  }

  List<SideboardDeck> _decksForSelectedGame() {
    return _sideboardDecks
        .where((SideboardDeck deck) => deck.tcgKey == _selectedTcgKey)
        .toList(growable: false);
  }

  SideboardDeck? _findDeckByNameForSelectedGame(String rawName) {
    final String normalized = rawName.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    for (final SideboardDeck deck in _decksForSelectedGame()) {
      if (deck.name.trim().toLowerCase() == normalized) {
        return deck;
      }
    }
    return null;
  }

  String _defaultDeckNameForSelectedGame() {
    final String stored = (_lastDeckByTcg[_selectedTcgKey] ?? '').trim();
    if (stored.isEmpty) {
      return '';
    }
    final SideboardDeck? linked = _findDeckByNameForSelectedGame(stored);
    return linked?.name ?? '';
  }

  Map<String, String> _decodeLastDeckByTcg(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return <String, String>{};
    }
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return <String, String>{};
      }
      final Map<String, String> parsed = <String, String>{};
      for (final MapEntry<dynamic, dynamic> entry in decoded.entries) {
        final String key = entry.key is String ? entry.key as String : '';
        final String value = entry.value is String ? entry.value as String : '';
        final String normalizedKey = _normalizeTcgKey(
          key,
          fallback: SupportedTcg.yugioh.storageKey,
        );
        parsed[normalizedKey] = value.trim();
      }
      return parsed;
    } catch (_) {
      return <String, String>{};
    }
  }

  List<GameRecord> _mergeRecordsForGame(
    List<GameRecord> updatedRecords,
    String tcgKey,
  ) {
    final List<GameRecord> untouched = _gameRecords
        .where((GameRecord record) => record.tcgKey != tcgKey)
        .toList(growable: false);
    final List<GameRecord> updatedScoped = updatedRecords
        .map((GameRecord record) => record.copyWith(tcgKey: tcgKey))
        .toList(growable: false);
    final List<GameRecord> merged = <GameRecord>[
      ...untouched,
      ...updatedScoped,
    ];
    merged.sort((GameRecord a, GameRecord b) {
      return b.createdAt.compareTo(a.createdAt);
    });
    return merged;
  }

  List<SideboardDeck> _mergeDecksForGame(
    List<SideboardDeck> updatedDecks,
    String tcgKey,
  ) {
    final List<SideboardDeck> untouched = _sideboardDecks
        .where((SideboardDeck deck) => deck.tcgKey != tcgKey)
        .toList(growable: false);
    final List<SideboardDeck> updatedScoped = updatedDecks
        .map((SideboardDeck deck) => deck.copyWith(tcgKey: tcgKey))
        .toList(growable: false);
    return <SideboardDeck>[...untouched, ...updatedScoped];
  }

  List<SideboardDeck> _migrateDeckTcgUsingLinkedRecords(
    List<SideboardDeck> decks,
    List<GameRecord> records,
  ) {
    final Map<String, Set<String>> tcgByDeckId = <String, Set<String>>{};
    for (final GameRecord record in records) {
      final String deckId = record.deckId.trim();
      if (deckId.isEmpty) {
        continue;
      }
      tcgByDeckId.putIfAbsent(deckId, () => <String>{}).add(record.tcgKey);
    }

    return decks
        .map((SideboardDeck deck) {
          final Set<String>? linkedTcgs = tcgByDeckId[deck.id];
          if (linkedTcgs == null || linkedTcgs.length != 1) {
            return deck;
          }
          final String inferredTcg = linkedTcgs.first;
          if (inferredTcg == deck.tcgKey) {
            return deck;
          }
          return deck.copyWith(tcgKey: inferredTcg);
        })
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _loadStoredData();
  }

  Future<void> _loadStoredData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool premiumUnlocked = prefs.getBool(_premiumKey) ?? false;
    final AppSettings settings = _decodeSettings(prefs.getString(_settingsKey));
    final List<GameRecord> records = _decodeRecords(
      prefs.getString(_recordsKey),
    );
    final List<SideboardDeck> sideboardDecks =
        _migrateDeckTcgUsingLinkedRecords(
          _decodeSideboardDecks(prefs.getString(_sideboardDecksKey)),
          records,
        );
    final Map<String, String> lastDeckByTcg = _decodeLastDeckByTcg(
      prefs.getString(_lastDeckByTcgKey),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _premiumUnlocked = premiumUnlocked;
      _settings = settings;
      _selectedGame = SupportedTcgX.fromStorageKey(settings.startupTcgKey);
      _gameRecords = records;
      _sideboardDecks = sideboardDecks;
      _lastDeckByTcg = lastDeckByTcg;
      _isLoading = false;
    });
  }

  AppSettings _decodeSettings(String? rawSettings) {
    if (rawSettings == null || rawSettings.isEmpty) {
      return AppSettings.defaults();
    }

    try {
      final dynamic decoded = jsonDecode(rawSettings);
      if (decoded is Map) {
        return AppSettings.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      return AppSettings.defaults();
    }

    return AppSettings.defaults();
  }

  List<GameRecord> _decodeRecords(String? rawRecords) {
    if (rawRecords == null || rawRecords.isEmpty) {
      return <GameRecord>[];
    }

    try {
      final dynamic decoded = jsonDecode(rawRecords);
      if (decoded is! List<dynamic>) {
        return <GameRecord>[];
      }

      final List<GameRecord> parsed = <GameRecord>[];
      for (final dynamic entry in decoded) {
        if (entry is Map) {
          parsed.add(GameRecord.fromJson(Map<String, dynamic>.from(entry)));
        }
      }
      parsed.sort((GameRecord a, GameRecord b) {
        return b.createdAt.compareTo(a.createdAt);
      });
      return parsed;
    } catch (_) {
      return <GameRecord>[];
    }
  }

  List<SideboardDeck> _decodeSideboardDecks(String? rawDecks) {
    if (rawDecks == null || rawDecks.isEmpty) {
      return <SideboardDeck>[];
    }

    try {
      final dynamic decoded = jsonDecode(rawDecks);
      if (decoded is! List<dynamic>) {
        return <SideboardDeck>[];
      }

      final List<SideboardDeck> parsed = <SideboardDeck>[];
      for (final dynamic entry in decoded) {
        if (entry is Map) {
          parsed.add(SideboardDeck.fromJson(Map<String, dynamic>.from(entry)));
        }
      }
      return parsed;
    } catch (_) {
      return <SideboardDeck>[];
    }
  }

  Future<void> _persistState() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumKey, _premiumUnlocked);
    await prefs.setString(_settingsKey, jsonEncode(_settings.toJson()));
    await prefs.setString(
      _recordsKey,
      jsonEncode(
        _gameRecords
            .map((GameRecord record) => record.toJson())
            .toList(growable: false),
      ),
    );
    await prefs.setString(
      _sideboardDecksKey,
      jsonEncode(
        _sideboardDecks
            .map((SideboardDeck deck) => deck.toJson())
            .toList(growable: false),
      ),
    );
    await prefs.setString(_lastDeckByTcgKey, jsonEncode(_lastDeckByTcg));
  }

  Future<bool> _ensurePremiumAccess({required String featureName}) async {
    if (_premiumUnlocked) {
      return true;
    }

    final bool? unlocked = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Upgrade to Pro'),
          content: Text(
            '$featureName is available only in Pro.\n\nAdd your real price later in App Store. For now you can test it with a demo unlock.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Buy Pro (demo)'),
            ),
          ],
        );
      },
    );

    if (unlocked != true) {
      return false;
    }

    setState(() {
      _premiumUnlocked = true;
    });
    await _persistState();
    return true;
  }

  Future<void> _startDuel() async {
    late final Widget duelScreen;
    String duelTitlePrefix = 'Duel';
    final String selectedTcgKey = _selectedTcgKey;
    final List<SideboardDeck> availableDecks = _decksForSelectedGame();
    final List<String> availableDeckNames = availableDecks
        .map((SideboardDeck deck) => deck.name)
        .toList(growable: false);
    final String defaultDeckName = _defaultDeckNameForSelectedGame();

    if (_selectedGame == SupportedTcg.yugioh) {
      duelScreen = DuelScreen(
        settings: _settings,
        availableDeckNames: availableDeckNames,
        availableDecks: availableDecks,
        initialDeckName: defaultDeckName,
      );
    } else if (_selectedGame == SupportedTcg.mtg) {
      final MtgDuelSetupResult? setupResult = await Navigator.of(context)
          .push<MtgDuelSetupResult>(
            MaterialPageRoute<MtgDuelSetupResult>(
              builder: (_) => MtgDuelSetupScreen(settings: _settings),
            ),
          );
      if (setupResult == null || !mounted) {
        return;
      }

      duelScreen = MtgDuelScreen(
        settings: _settings,
        playerCount: setupResult.playerCount,
        initialLifePoints: setupResult.initialLifePoints,
        layoutMode: setupResult.layoutMode,
        availableDeckNames: availableDeckNames,
        availableDecks: availableDecks,
        initialDeckName: defaultDeckName,
      );
      duelTitlePrefix = 'MTG Duel';
    } else {
      return;
    }

    GameRecord? createdRecord;

    if (_premiumUnlocked) {
      final DateTime now = DateTime.now();
      createdRecord = GameRecord(
        id: now.microsecondsSinceEpoch.toString(),
        title: '$duelTitlePrefix ${_gameRecords.length + 1}',
        createdAt: now,
        gameStage: 'G1',
        notes: '',
        lifePointHistory: const <String>[],
        tcgKey: selectedTcgKey,
        playerOneName: _settings.playerOneName,
        playerTwoName: _settings.playerTwoName,
      );
      setState(() {
        _gameRecords = <GameRecord>[createdRecord!, ..._gameRecords];
      });
      await _persistState();
    }

    if (!mounted) {
      return;
    }

    final DuelResultPayload? duelResult = await Navigator.of(context)
        .push<DuelResultPayload>(
          MaterialPageRoute<DuelResultPayload>(builder: (_) => duelScreen),
        );

    final String latestDeckName = duelResult?.deckName.trim() ?? '';
    if (duelResult != null) {
      setState(() {
        _lastDeckByTcg[selectedTcgKey] = latestDeckName;
      });
    }

    if (createdRecord == null) {
      if (duelResult != null) {
        await _persistState();
      }
      return;
    }
    if (duelResult == null || !duelResult.shouldSave) {
      setState(() {
        _gameRecords = _gameRecords
            .where((GameRecord record) => record.id != createdRecord!.id)
            .toList(growable: false);
      });
      await _persistState();
      return;
    }

    final String rawDeckName = latestDeckName;
    final SideboardDeck? selectedDeck = _findDeckByNameForSelectedGame(
      rawDeckName,
    );
    final String resolvedDeckId = selectedDeck?.id ?? '';
    final String resolvedDeckName = selectedDeck?.name ?? rawDeckName;

    setState(() {
      _gameRecords = _gameRecords
          .map((GameRecord record) {
            if (record.id != createdRecord!.id) {
              return record;
            }
            return record.copyWith(
              lifePointHistory: List<String>.from(duelResult.lifePointHistory),
              gameStage: duelResult.gameStage,
              matchResult: duelResult.matchResult,
              opponentName: duelResult.opponentName,
              deckId: resolvedDeckId,
              deckName: resolvedDeckName,
            );
          })
          .toList(growable: false);
    });
    await _persistState();
  }

  Future<void> _openGameHistory() async {
    final bool allowed = await _ensurePremiumAccess(
      featureName: 'Game History',
    );
    if (!allowed || !mounted) {
      return;
    }

    final String tcgKey = _selectedTcgKey;
    final List<GameRecord> scopedRecords = _recordsForSelectedGame();
    final List<SideboardDeck> scopedDecks = _decksForSelectedGame();

    final List<GameRecord>? updatedRecords = await Navigator.of(context)
        .push<List<GameRecord>>(
          MaterialPageRoute<List<GameRecord>>(
            builder: (_) => GameHistoryScreen(
              records: scopedRecords,
              decks: scopedDecks,
              tcg: _selectedGame,
            ),
          ),
        );

    if (updatedRecords == null) {
      return;
    }

    setState(() {
      _gameRecords = _mergeRecordsForGame(updatedRecords, tcgKey);
    });
    await _persistState();
  }

  Future<void> _openCustomize() async {
    final bool allowed = await _ensurePremiumAccess(
      featureName: 'App customization',
    );
    if (!allowed || !mounted) {
      return;
    }

    final AppSettings? updatedSettings = await Navigator.of(context)
        .push<AppSettings>(
          MaterialPageRoute<AppSettings>(
            builder: (_) => CustomizeScreen(initialSettings: _settings),
          ),
        );

    if (updatedSettings == null) {
      return;
    }

    setState(() {
      _settings = updatedSettings;
      _selectedGame = SupportedTcgX.fromStorageKey(
        updatedSettings.startupTcgKey,
      );
    });
    await _persistState();
  }

  Future<void> _openSideboardBook() async {
    final bool allowed = await _ensurePremiumAccess(
      featureName: "Deck's Utility",
    );
    if (!allowed || !mounted) {
      return;
    }

    final String tcgKey = _selectedTcgKey;
    final List<SideboardDeck> scopedDecks = _decksForSelectedGame();
    final List<GameRecord> scopedRecords = _recordsForSelectedGame();

    final SideboardBookResult? result = await Navigator.of(context)
        .push<SideboardBookResult>(
          MaterialPageRoute<SideboardBookResult>(
            builder: (_) => SideboardDeckListScreen(
              decks: scopedDecks,
              records: scopedRecords,
              settings: _settings,
              tcg: _selectedGame,
            ),
          ),
        );

    if (result == null) {
      return;
    }

    setState(() {
      _sideboardDecks = _mergeDecksForGame(result.decks, tcgKey);
      _gameRecords = _mergeRecordsForGame(result.records, tcgKey);
    });
    await _persistState();
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings activeSettings = _settings;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              activeSettings.backgroundStartColor,
              activeSettings.backgroundEndColor,
            ],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(),
                      const Text(
                        'TCG Life Counter',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<SupportedTcg>(
                            value: _selectedGame,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF241C1C),
                            style: const TextStyle(color: Colors.white),
                            iconEnabledColor: Colors.white,
                            items: _supportedTcgAlphabeticalOrder
                                .map(
                                  (SupportedTcg game) =>
                                      DropdownMenuItem<SupportedTcg>(
                                        value: game,
                                        child: Text(game.label),
                                      ),
                                )
                                .toList(growable: false),
                            onChanged: (SupportedTcg? value) {
                              if (value == null || value == _selectedGame) {
                                return;
                              }
                              setState(() {
                                _selectedGame = value;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_isImplementedGame) ...[
                        const Spacer(),
                        _ModeButton(
                          icon: Icons.splitscreen,
                          title: "Let's Duel",
                          subtitle: 'Top and bottom players',
                          backgroundColor: activeSettings.buttonColor,
                          onPressed: _startDuel,
                        ),
                        const SizedBox(height: 12),
                        _ModeButton(
                          icon: Icons.history_rounded,
                          title: 'Game History',
                          subtitle: _premiumUnlocked
                              ? 'Date, G1/G2/G3, notes'
                              : 'Premium feature',
                          backgroundColor: activeSettings.buttonColor,
                          onPressed: _openGameHistory,
                          locked: !_premiumUnlocked,
                        ),
                        const SizedBox(height: 12),
                        _ModeButton(
                          icon: Icons.menu_book_rounded,
                          title: "Deck's Utility",
                          subtitle: _premiumUnlocked
                              ? 'Decks, Sideboard and Plans'
                              : 'Premium feature',
                          backgroundColor: activeSettings.buttonColor,
                          onPressed: _openSideboardBook,
                          locked: !_premiumUnlocked,
                        ),
                        const SizedBox(height: 12),
                        _ModeButton(
                          icon: Icons.tune_rounded,
                          title: 'Customize App',
                          subtitle: _premiumUnlocked
                              ? 'Names and colors'
                              : 'Premium feature',
                          backgroundColor: activeSettings.buttonColor,
                          onPressed: _openCustomize,
                          locked: !_premiumUnlocked,
                        ),
                        const Spacer(),
                      ] else ...[
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: const Text(
                            "Coming soon! Contact me if you're interested.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Spacer(),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.backgroundColor,
    required this.onPressed,
    this.locked = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color backgroundColor;
  final VoidCallback onPressed;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (locked) ...[
                const Icon(Icons.workspace_premium_outlined, size: 18),
                const SizedBox(width: 8),
              ],
              const Icon(Icons.arrow_forward_ios_rounded, size: 18),
            ],
          ),
        ],
      ),
    );
  }
}

@immutable
class MtgDuelSetupResult {
  const MtgDuelSetupResult({
    required this.playerCount,
    required this.initialLifePoints,
    required this.layoutMode,
  });

  final int playerCount;
  final int initialLifePoints;
  final MtgDuelLayoutMode layoutMode;
}

enum MtgDuelLayoutMode { standard, tableMode }

extension MtgDuelLayoutModeX on MtgDuelLayoutMode {
  String get label {
    switch (this) {
      case MtgDuelLayoutMode.standard:
        return 'Standard';
      case MtgDuelLayoutMode.tableMode:
        return 'Table Mode';
    }
  }

  String get subtitle {
    switch (this) {
      case MtgDuelLayoutMode.standard:
        return 'Opposite sides';
      case MtgDuelLayoutMode.tableMode:
        return 'Around the table';
    }
  }
}

typedef _MtgLayoutRowSpec = ({List<int?> slots, int flex});

MtgDuelLayoutMode _effectiveMtgLayoutMode({
  required int playerCount,
  required MtgDuelLayoutMode layoutMode,
}) {
  return playerCount == 2 ? MtgDuelLayoutMode.tableMode : layoutMode;
}

int _mtgQuarterTurnsForPlayer({
  required int playerCount,
  required MtgDuelLayoutMode layoutMode,
  required int playerIndex,
}) {
  final MtgDuelLayoutMode effectiveMode = _effectiveMtgLayoutMode(
    playerCount: playerCount,
    layoutMode: layoutMode,
  );

  if (effectiveMode == MtgDuelLayoutMode.standard) {
    if (playerCount == 3) {
      if (playerIndex == 1) {
        return 1;
      }
      return 3;
    }
    switch (playerCount) {
      case 4:
        return playerIndex <= 1 ? 1 : 3;
      case 5:
      case 6:
        return playerIndex <= 2 ? 1 : 3;
      case 2:
      default:
        return playerIndex == 0 ? 0 : 2;
    }
  }

  switch (playerCount) {
    case 2:
      return playerIndex == 0 ? 0 : 2;
    case 3:
      if (playerIndex == 0) {
        return 0;
      }
      return playerIndex == 1 ? 1 : 3;
    case 4:
      if (playerIndex == 0) {
        return 0;
      }
      if (playerIndex == 1) {
        return 1;
      }
      if (playerIndex == 2) {
        return 2;
      }
      return 3;
    case 5:
      if (playerIndex == 0) {
        return 0;
      }
      if (playerIndex == 1 || playerIndex == 2) {
        return 1;
      }
      if (playerIndex == 3) {
        return 2;
      }
      return 3;
    case 6:
      if (playerIndex == 0) {
        return 0;
      }
      if (playerIndex == 1 || playerIndex == 2) {
        return 1;
      }
      if (playerIndex == 3) {
        return 2;
      }
      if (playerIndex == 4 || playerIndex == 5) {
        return 3;
      }
      return 2;
    default:
      return 0;
  }
}

List<_MtgLayoutRowSpec> _mtgLayoutRows({
  required int playerCount,
  required MtgDuelLayoutMode layoutMode,
}) {
  final MtgDuelLayoutMode effectiveMode = _effectiveMtgLayoutMode(
    playerCount: playerCount,
    layoutMode: layoutMode,
  );

  if (effectiveMode == MtgDuelLayoutMode.standard) {
    switch (playerCount) {
      case 3:
        return <_MtgLayoutRowSpec>[
          (slots: <int?>[1, 2], flex: 48),
          (slots: <int?>[null, 0, null], flex: 52),
        ];
      case 4:
        return <_MtgLayoutRowSpec>[
          (slots: <int?>[1, 3], flex: 50),
          (slots: <int?>[0, 2], flex: 50),
        ];
      case 5:
        return <_MtgLayoutRowSpec>[
          (slots: <int?>[2, null, 4], flex: 33),
          (slots: <int?>[1, null, 3], flex: 33),
          (slots: <int?>[0, null, null], flex: 34),
        ];
      case 6:
        return <_MtgLayoutRowSpec>[
          (slots: <int?>[2, null, 5], flex: 33),
          (slots: <int?>[1, null, 4], flex: 33),
          (slots: <int?>[0, null, 3], flex: 34),
        ];
      case 2:
      default:
        return <_MtgLayoutRowSpec>[
          (slots: <int?>[1], flex: 50),
          (slots: <int?>[0], flex: 50),
        ];
    }
  }

  switch (playerCount) {
    case 3:
      return <_MtgLayoutRowSpec>[
        (slots: <int?>[1, 2], flex: 60),
        (slots: <int?>[0], flex: 40),
      ];
    case 4:
      return <_MtgLayoutRowSpec>[
        (slots: <int?>[2], flex: 26),
        (slots: <int?>[1, null, 3], flex: 48),
        (slots: <int?>[0], flex: 26),
      ];
    case 5:
      return <_MtgLayoutRowSpec>[
        (slots: <int?>[null, 3, null], flex: 18),
        (slots: <int?>[1, null, 4], flex: 22),
        (slots: <int?>[2, null, null], flex: 21),
        (slots: <int?>[null, 0, null], flex: 21),
      ];
    case 6:
      return <_MtgLayoutRowSpec>[
        (slots: <int?>[null, 3, null], flex: 22),
        (slots: <int?>[1, null, 4], flex: 28),
        (slots: <int?>[2, null, 5], flex: 28),
        (slots: <int?>[null, 0, null], flex: 22),
      ];
    case 2:
    default:
      return <_MtgLayoutRowSpec>[
        (slots: <int?>[1], flex: 50),
        (slots: <int?>[0], flex: 50),
      ];
  }
}

List<int> _slotFlexesForSlots(List<int?> slots) {
  if (slots.length <= 1) {
    return const <int>[1];
  }
  if (slots.length == 2) {
    return const <int>[1, 1];
  }

  final bool left = slots[0] != null;
  final bool center = slots[1] != null;
  final bool right = slots[2] != null;

  if (left && !center && right) {
    return const <int>[7, 1, 7];
  }
  if (!left && center && !right) {
    return const <int>[1, 8, 1];
  }
  if (left && !center && !right) {
    return const <int>[7, 1, 7];
  }
  if (!left && !center && right) {
    return const <int>[7, 1, 7];
  }
  if (!left && center && right) {
    return const <int>[1, 6, 6];
  }
  if (left && center && !right) {
    return const <int>[6, 6, 1];
  }
  return const <int>[1, 1, 1];
}

class MtgDuelSetupScreen extends StatefulWidget {
  const MtgDuelSetupScreen({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<MtgDuelSetupScreen> createState() => _MtgDuelSetupScreenState();
}

class _MtgDuelSetupScreenState extends State<MtgDuelSetupScreen> {
  int _playerCount = 2;
  int _initialLifePoints = 20;
  MtgDuelLayoutMode _layoutMode = MtgDuelLayoutMode.tableMode;

  MtgDuelLayoutMode get _effectiveLayoutMode =>
      _playerCount == 2 ? MtgDuelLayoutMode.tableMode : _layoutMode;

  void _startDuel() {
    Navigator.of(context).pop(
      MtgDuelSetupResult(
        playerCount: _playerCount,
        initialLifePoints: _initialLifePoints,
        layoutMode: _effectiveLayoutMode,
      ),
    );
  }

  Widget _buildChoiceCard({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
    required Color accentColor,
    double? width = 128,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? accentColor.withValues(alpha: 0.24)
                : const Color(0xFF1C1A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? accentColor
                  : Colors.white.withValues(alpha: 0.14),
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullWidthChoiceRows<T>({
    required List<T> values,
    required Widget Function(T value) itemBuilder,
    int maxColumns = 3,
    double spacing = 10,
  }) {
    final List<Widget> rows = <Widget>[];
    for (int start = 0; start < values.length; start += maxColumns) {
      final int end = min(start + maxColumns, values.length);
      final List<T> chunk = values.sublist(start, end);
      rows.add(
        Row(
          children: [
            for (int index = 0; index < chunk.length; index += 1) ...[
              Expanded(child: itemBuilder(chunk[index])),
              if (index < chunk.length - 1) SizedBox(width: spacing),
            ],
          ],
        ),
      );
      if (end < values.length) {
        rows.add(SizedBox(height: spacing));
      }
    }
    return Column(children: rows);
  }

  Widget _buildLayoutPreviewTile({
    required String label,
    required int quarterTurns,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFF171717),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: RotatedBox(
          quarterTurns: quarterTurns,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.expand_less_rounded,
                  size: 12,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _previewQuarterTurnsForPlayer(int playerIndex) {
    return _mtgQuarterTurnsForPlayer(
      playerCount: _playerCount,
      layoutMode: _effectiveLayoutMode,
      playerIndex: playerIndex,
    );
  }

  List<_MtgLayoutRowSpec> _previewRows() {
    return _mtgLayoutRows(
      playerCount: _playerCount,
      layoutMode: _effectiveLayoutMode,
    );
  }

  Widget _buildPreviewRow(List<int?> slots) {
    final List<int> slotFlexes = _slotFlexesForSlots(slots);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int index = 0; index < slots.length; index += 1) ...[
          if (index > 0) const SizedBox(width: 4),
          Flexible(
            flex: slotFlexes[index],
            child: Builder(
              builder: (BuildContext context) {
                final int? playerIndex = slots[index];
                if (playerIndex == null) {
                  return const SizedBox.shrink();
                }
                return _buildLayoutPreviewTile(
                  label: 'P${playerIndex + 1}',
                  quarterTurns: _previewQuarterTurnsForPlayer(playerIndex),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLayoutPreview() {
    if (_effectiveLayoutMode == MtgDuelLayoutMode.standard &&
        _playerCount == 3) {
      return _buildThreePlayerStandardPreview();
    }
    if (_effectiveLayoutMode == MtgDuelLayoutMode.standard &&
        _playerCount == 5) {
      return _buildFivePlayerStandardPreview();
    }
    if (_effectiveLayoutMode == MtgDuelLayoutMode.standard &&
        _playerCount == 6) {
      return _buildSixPlayerStandardPreview();
    }
    if (_effectiveLayoutMode == MtgDuelLayoutMode.tableMode &&
        _playerCount == 4) {
      return _buildFourPlayerTablePreview();
    }
    if (_effectiveLayoutMode == MtgDuelLayoutMode.tableMode &&
        _playerCount == 5) {
      return _buildFivePlayerTablePreview();
    }
    if (_effectiveLayoutMode == MtgDuelLayoutMode.tableMode &&
        _playerCount == 6) {
      return _buildSixPlayerTablePreview();
    }

    final List<_MtgLayoutRowSpec> rows = _previewRows();
    final double previewHeight = switch (rows.length) {
      2 => 120,
      3 => 144,
      4 => 172,
      5 => 198,
      _ => 132,
    };

    return Container(
      height: previewHeight,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          for (final _MtgLayoutRowSpec row in rows)
            Expanded(flex: row.flex, child: _buildPreviewRow(row.slots)),
        ],
      ),
    );
  }

  Widget _buildThreePlayerStandardPreview() {
    return Container(
      height: 156,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildLayoutPreviewTile(
              label: 'P2',
              quarterTurns: _previewQuarterTurnsForPlayer(1),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _buildLayoutPreviewTile(
                    label: 'P3',
                    quarterTurns: _previewQuarterTurnsForPlayer(2),
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: _buildLayoutPreviewTile(
                    label: 'P1',
                    quarterTurns: _previewQuarterTurnsForPlayer(0),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFourPlayerTablePreview() {
    return Container(
      height: 164,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Expanded(flex: 26, child: _buildPreviewRow(const <int?>[2])),
          const SizedBox(height: 4),
          Expanded(
            flex: 48,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildLayoutPreviewTile(
                    label: 'P2',
                    quarterTurns: _previewQuarterTurnsForPlayer(1),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      widthFactor: 1,
                      heightFactor: 0.94,
                      alignment: Alignment.bottomCenter,
                      child: _buildLayoutPreviewTile(
                        label: 'P4',
                        quarterTurns: _previewQuarterTurnsForPlayer(3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(flex: 26, child: _buildPreviewRow(const <int?>[0])),
        ],
      ),
    );
  }

  Widget _buildFivePlayerStandardPreview() {
    return Container(
      height: 188,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _buildLayoutPreviewTile(
                    label: 'P3',
                    quarterTurns: _previewQuarterTurnsForPlayer(2),
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: _buildLayoutPreviewTile(
                    label: 'P2',
                    quarterTurns: _previewQuarterTurnsForPlayer(1),
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: _buildLayoutPreviewTile(
                    label: 'P1',
                    quarterTurns: _previewQuarterTurnsForPlayer(0),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _buildLayoutPreviewTile(
                    label: 'P5',
                    quarterTurns: _previewQuarterTurnsForPlayer(4),
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: _buildLayoutPreviewTile(
                    label: 'P4',
                    quarterTurns: _previewQuarterTurnsForPlayer(3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFivePlayerTablePreview() {
    return Container(
      height: 188,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Expanded(
            flex: 22,
            child: _buildPreviewRow(const <int?>[null, 3, null]),
          ),
          const SizedBox(height: 4),
          Expanded(
            flex: 56,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: _buildLayoutPreviewTile(
                          label: 'P2',
                          quarterTurns: _previewQuarterTurnsForPlayer(1),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: _buildLayoutPreviewTile(
                          label: 'P3',
                          quarterTurns: _previewQuarterTurnsForPlayer(2),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildLayoutPreviewTile(
                    label: 'P5',
                    quarterTurns: _previewQuarterTurnsForPlayer(4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            flex: 22,
            child: _buildPreviewRow(const <int?>[null, 0, null]),
          ),
        ],
      ),
    );
  }

  Widget _buildSixPlayerStandardPreview() {
    return Container(
      height: 188,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _buildLayoutPreviewTile(
                    label: 'P3',
                    quarterTurns: _previewQuarterTurnsForPlayer(2),
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: _buildLayoutPreviewTile(
                    label: 'P2',
                    quarterTurns: _previewQuarterTurnsForPlayer(1),
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: _buildLayoutPreviewTile(
                    label: 'P1',
                    quarterTurns: _previewQuarterTurnsForPlayer(0),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _buildLayoutPreviewTile(
                    label: 'P6',
                    quarterTurns: _previewQuarterTurnsForPlayer(5),
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: _buildLayoutPreviewTile(
                    label: 'P5',
                    quarterTurns: _previewQuarterTurnsForPlayer(4),
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: _buildLayoutPreviewTile(
                    label: 'P4',
                    quarterTurns: _previewQuarterTurnsForPlayer(3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSixPlayerTablePreview() {
    return Container(
      height: 196,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Expanded(flex: 24, child: _buildPreviewRow(const <int?>[3])),
          const SizedBox(height: 4),
          Expanded(
            flex: 52,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: _buildLayoutPreviewTile(
                          label: 'P2',
                          quarterTurns: _previewQuarterTurnsForPlayer(1),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: _buildLayoutPreviewTile(
                          label: 'P3',
                          quarterTurns: _previewQuarterTurnsForPlayer(2),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: _buildLayoutPreviewTile(
                          label: 'P5',
                          quarterTurns: _previewQuarterTurnsForPlayer(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: _buildLayoutPreviewTile(
                          label: 'P6',
                          quarterTurns: _previewQuarterTurnsForPlayer(5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(flex: 24, child: _buildPreviewRow(const <int?>[0])),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MTG Duel Setup'),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Number of players',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildFullWidthChoiceRows<int>(
                    values: const <int>[2, 3, 4, 5, 6],
                    maxColumns: 3,
                    itemBuilder: (int count) {
                      return _buildChoiceCard(
                        title: '$count Players',
                        subtitle: count <= 2 ? 'Classic setup' : 'Multiplayer',
                        selected: _playerCount == count,
                        onTap: () {
                          setState(() {
                            _playerCount = count;
                            if (count == 2) {
                              _layoutMode = MtgDuelLayoutMode.tableMode;
                            }
                          });
                        },
                        accentColor: const Color(0xFF5FB06A),
                        width: null,
                      );
                    },
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Starting life points',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildFullWidthChoiceRows<int>(
                    values: const <int>[20, 25, 40],
                    maxColumns: 3,
                    itemBuilder: (int lifePoints) {
                      return _buildChoiceCard(
                        title: '$lifePoints LP',
                        subtitle: lifePoints == 40
                            ? 'Commander-style'
                            : 'Standard setup',
                        selected: _initialLifePoints == lifePoints,
                        onTap: () {
                          setState(() {
                            _initialLifePoints = lifePoints;
                          });
                        },
                        accentColor: const Color(0xFF4C81D9),
                        width: null,
                      );
                    },
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Counter layout',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_playerCount == 2)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1A1A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: const Text(
                        'For 2 players only Table Mode is available.',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    )
                  else
                    _buildFullWidthChoiceRows<MtgDuelLayoutMode>(
                      values: MtgDuelLayoutMode.values,
                      maxColumns: 2,
                      itemBuilder: (MtgDuelLayoutMode mode) {
                        return _buildChoiceCard(
                          title: mode.label,
                          subtitle: mode.subtitle,
                          selected: _layoutMode == mode,
                          onTap: () {
                            setState(() {
                              _layoutMode = mode;
                            });
                          },
                          accentColor: const Color(0xFFE49F43),
                          width: null,
                        );
                      },
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'Preview',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildLayoutPreview(),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: FilledButton(
                onPressed: _startDuel,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: widget.settings.buttonColor,
                ),
                child: Text(
                  'Start MTG Game',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _MtgResourceCounter { white, blue, black, red, green, colorless, storm }

extension _MtgResourceCounterX on _MtgResourceCounter {
  String get label {
    switch (this) {
      case _MtgResourceCounter.white:
        return 'White mana';
      case _MtgResourceCounter.blue:
        return 'Blue mana';
      case _MtgResourceCounter.black:
        return 'Black mana';
      case _MtgResourceCounter.red:
        return 'Red mana';
      case _MtgResourceCounter.green:
        return 'Green mana';
      case _MtgResourceCounter.colorless:
        return 'Colorless mana';
      case _MtgResourceCounter.storm:
        return 'Storm count';
    }
  }

  Color get accentColor {
    switch (this) {
      case _MtgResourceCounter.white:
        return const Color(0xFFF3F1E8);
      case _MtgResourceCounter.blue:
        return const Color(0xFF4C81D9);
      case _MtgResourceCounter.black:
        return const Color(0xFF232323);
      case _MtgResourceCounter.red:
        return const Color(0xFFD94C4C);
      case _MtgResourceCounter.green:
        return const Color(0xFF3FA55A);
      case _MtgResourceCounter.colorless:
        return const Color(0xFF9B9B9B);
      case _MtgResourceCounter.storm:
        return const Color(0xFFE6A23C);
    }
  }
}

enum _MtgStatusCounter { poison, experience }

extension _MtgStatusCounterX on _MtgStatusCounter {
  String get label {
    switch (this) {
      case _MtgStatusCounter.poison:
        return 'Poison counters (\u03A6)';
      case _MtgStatusCounter.experience:
        return 'Experience counters';
    }
  }
}

class MtgDuelScreen extends StatefulWidget {
  const MtgDuelScreen({
    super.key,
    required this.settings,
    required this.playerCount,
    required this.initialLifePoints,
    required this.layoutMode,
    this.availableDeckNames = const <String>[],
    this.availableDecks = const <SideboardDeck>[],
    this.initialDeckName = '',
  });

  final AppSettings settings;
  final int playerCount;
  final int initialLifePoints;
  final MtgDuelLayoutMode layoutMode;
  final List<String> availableDeckNames;
  final List<SideboardDeck> availableDecks;
  final String initialDeckName;

  @override
  State<MtgDuelScreen> createState() => _MtgDuelScreenState();
}

class _MtgDuelScreenState extends State<MtgDuelScreen> {
  static const Duration _aggregationWindow = Duration(seconds: 2);

  final Random _random = Random();

  late final List<int> _lifePoints;
  late final List<int> _pendingDeltas;
  late final List<Timer?> _pendingTimers;
  late final List<int?> _diceValues;
  late final List<Map<_MtgResourceCounter, int>> _resourceCounters;
  late final List<Map<_MtgStatusCounter, int>> _statusCounters;
  late final List<List<int>> _commanderDamageReceived;

  bool _isRollingDice = false;
  Timer? _diceRollTimer;
  int _diceRollTicks = 0;

  late final List<String> _historyEntries;
  late final List<TwoPlayerLifeEvent> _twoPlayerLifeEvents;
  late final List<String> _playerNames;

  String _opponentName = '';
  String _selectedGameStage = 'G1';
  String _deckInUse = '';
  int _bo3Wins = 0;
  int _bo3Losses = 0;
  String _lastCompletedOpponentName = '';

  bool get _isMultiplayer => widget.playerCount >= 3;

  MtgDuelLayoutMode get _effectiveLayoutMode => _effectiveMtgLayoutMode(
    playerCount: widget.playerCount,
    layoutMode: widget.layoutMode,
  );

  bool get _isTableMode => _effectiveLayoutMode == MtgDuelLayoutMode.tableMode;

  int _quarterTurnsForPlayer(int playerIndex) {
    return _mtgQuarterTurnsForPlayer(
      playerCount: widget.playerCount,
      layoutMode: _effectiveLayoutMode,
      playerIndex: playerIndex,
    );
  }

  Offset _beginOffsetForQuarterTurns(int quarterTurns) {
    switch (quarterTurns % 4) {
      case 1:
        return const Offset(-1, 0);
      case 2:
        return const Offset(0, -1);
      case 3:
        return const Offset(1, 0);
      default:
        return const Offset(0, 1);
    }
  }

  Alignment _alignmentForQuarterTurns(int quarterTurns) {
    switch (quarterTurns % 4) {
      case 1:
        return Alignment.centerLeft;
      case 2:
        return Alignment.topCenter;
      case 3:
        return Alignment.centerRight;
      default:
        return Alignment.bottomCenter;
    }
  }

  String _playerName(int playerIndex) {
    if (widget.playerCount == 2 && playerIndex == 1) {
      final String opponent = _opponentName.trim();
      if (opponent.isNotEmpty) {
        return opponent;
      }
    }
    return _playerNames[playerIndex];
  }

  String _defaultPlayerName(int playerIndex) {
    if (playerIndex == 0) {
      final String name = widget.settings.playerOneName.trim();
      return name.isEmpty ? 'Player 1' : name;
    }
    if (playerIndex == 1) {
      final String name = widget.settings.playerTwoName.trim();
      return name.isEmpty ? 'Player 2' : name;
    }
    return 'Player ${playerIndex + 1}';
  }

  String _sanitizePlayerName(String value, int playerIndex) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return _defaultPlayerName(playerIndex);
    }
    return trimmed;
  }

  String _resolveInitialDeckName() {
    final String normalizedInitial = widget.initialDeckName
        .trim()
        .toLowerCase();
    if (normalizedInitial.isEmpty) {
      return '';
    }
    for (final String raw in widget.availableDeckNames) {
      final String trimmed = raw.trim();
      if (trimmed.toLowerCase() == normalizedInitial) {
        return trimmed;
      }
    }
    for (final SideboardDeck deck in widget.availableDecks) {
      final String trimmed = deck.name.trim();
      if (trimmed.toLowerCase() == normalizedInitial) {
        return trimmed;
      }
    }
    return '';
  }

  SideboardDeck? _selectedDeckForGuide() {
    final String normalizedDeck = _deckInUse.trim().toLowerCase();
    if (normalizedDeck.isEmpty) {
      return null;
    }
    for (final SideboardDeck deck in widget.availableDecks) {
      if (deck.name.trim().toLowerCase() == normalizedDeck) {
        return deck;
      }
    }
    return null;
  }

  String _formatSideboardEntries(List<SideboardCardEntry> entries) {
    if (entries.isEmpty) {
      return '-';
    }
    return entries
        .map((SideboardCardEntry entry) {
          final String name = entry.name.trim().isEmpty
              ? 'Unnamed card'
              : entry.name.trim();
          final int copies = entry.copies.clamp(1, 99).toInt();
          return '$copies x $name';
        })
        .join(', ');
  }

  Future<void> _openSideboardGuideDialog() async {
    final SideboardDeck? deck = _selectedDeckForGuide();
    if (deck == null) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        final bool hasMatchups = deck.matchups.isNotEmpty;
        return AlertDialog(
          title: Text('${deck.name} - Sideboard Guide'),
          content: SizedBox(
            width: double.maxFinite,
            child: hasMatchups
                ? SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (
                          int index = 0;
                          index < deck.matchups.length;
                          index += 1
                        ) ...[
                          if (index > 0) const SizedBox(height: 12),
                          Text(
                            deck.matchups[index].name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Side In: ${_formatSideboardEntries(deck.matchups[index].sideIn)}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Side Out: ${_formatSideboardEntries(deck.matchups[index].sideOut)}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : const Text('No matchup plans saved for this deck yet.'),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _registerCurrentGameResultForBo3() {
    if (widget.playerCount != 2) {
      return;
    }
    if (_lifePoints[0] == _lifePoints[1]) {
      return;
    }
    if (_lifePoints[0] > _lifePoints[1]) {
      _bo3Wins += 1;
    } else {
      _bo3Losses += 1;
    }
  }

  void _registerDeclaredGameResultForBo3(String result) {
    if (widget.playerCount != 2) {
      return;
    }
    if (result == 'Win') {
      _bo3Wins += 1;
      return;
    }
    if (result == 'Loss') {
      _bo3Losses += 1;
    }
  }

  void _advanceBo3AfterRestart({String? declaredResult}) {
    if (widget.playerCount != 2) {
      return;
    }

    final String currentStage = _selectedGameStage;
    if (!_supportedGameStages.contains(currentStage)) {
      _selectedGameStage = 'G1';
      _bo3Wins = 0;
      _bo3Losses = 0;
      return;
    }

    final String explicitResult = (declaredResult ?? '').trim();
    if (explicitResult.isEmpty) {
      _registerCurrentGameResultForBo3();
    } else {
      _registerDeclaredGameResultForBo3(explicitResult);
    }

    String nextStage = 'G1';
    if (currentStage == 'G1') {
      nextStage = 'G2';
    } else if (currentStage == 'G2') {
      final bool matchClosed = _bo3Wins >= 2 || _bo3Losses >= 2;
      nextStage = matchClosed ? 'G1' : 'G3';
    } else {
      nextStage = 'G1';
    }

    _selectedGameStage = nextStage;
    if (nextStage == 'G1') {
      final String completedOpponent = _opponentName.trim();
      if (completedOpponent.isNotEmpty) {
        _lastCompletedOpponentName = completedOpponent;
      }
      _bo3Wins = 0;
      _bo3Losses = 0;
      _opponentName = '';
    }
  }

  List<String> _deckOptionsForDetails() {
    final List<String> options = <String>[];
    for (final String raw in widget.availableDeckNames) {
      final String trimmed = raw.trim();
      if (trimmed.isEmpty || options.contains(trimmed)) {
        continue;
      }
      options.add(trimmed);
    }
    final String current = _deckInUse.trim();
    if (current.isNotEmpty && !options.contains(current)) {
      options.add(current);
    }
    return options;
  }

  @override
  void initState() {
    super.initState();
    unawaited(WakelockPlus.enable());
    _deckInUse = _resolveInitialDeckName();
    _playerNames = List<String>.generate(
      widget.playerCount,
      (int index) => _defaultPlayerName(index),
    );
    _lifePoints = List<int>.filled(
      widget.playerCount,
      widget.initialLifePoints,
    );
    _pendingDeltas = List<int>.filled(widget.playerCount, 0);
    _pendingTimers = List<Timer?>.filled(widget.playerCount, null);
    _diceValues = List<int?>.filled(widget.playerCount, null);
    _resourceCounters = List<Map<_MtgResourceCounter, int>>.generate(
      widget.playerCount,
      (_) => <_MtgResourceCounter, int>{
        for (final _MtgResourceCounter counter in _MtgResourceCounter.values)
          counter: 0,
      },
    );
    _statusCounters = List<Map<_MtgStatusCounter, int>>.generate(
      widget.playerCount,
      (_) => <_MtgStatusCounter, int>{
        for (final _MtgStatusCounter counter in _MtgStatusCounter.values)
          counter: 0,
      },
    );
    _commanderDamageReceived = List<List<int>>.generate(
      widget.playerCount,
      (_) => List<int>.filled(widget.playerCount, 0),
    );
    _historyEntries = List<String>.generate(
      widget.playerCount,
      (int index) => '${_playerName(index)}: ${widget.initialLifePoints}',
    );
    _twoPlayerLifeEvents = <TwoPlayerLifeEvent>[];
  }

  String _formatSigned(int value) {
    return value > 0 ? '+$value' : '$value';
  }

  ({
    Alignment alignment,
    Offset beginOffset,
    int quarterTurns,
    double widthFactor,
    double heightFactor,
  })
  _placementForPlayer(int playerIndex) {
    final int quarterTurns = _quarterTurnsForPlayer(playerIndex);
    final bool longSide = quarterTurns == 1 || quarterTurns == 3;
    return (
      alignment: _alignmentForQuarterTurns(quarterTurns),
      beginOffset: _beginOffsetForQuarterTurns(quarterTurns),
      quarterTurns: quarterTurns,
      widthFactor: longSide ? 0.72 : 0.96,
      heightFactor: longSide ? 0.94 : 0.58,
    );
  }

  void _cancelPendingTimer(int playerIndex) {
    _pendingTimers[playerIndex]?.cancel();
    _pendingTimers[playerIndex] = null;
  }

  void _startPendingTimer(int playerIndex) {
    _cancelPendingTimer(playerIndex);
    _pendingTimers[playerIndex] = Timer(_aggregationWindow, () {
      _commitPendingDelta(playerIndex);
    });
  }

  void _commitPendingDelta(int playerIndex) {
    if (!mounted) {
      return;
    }
    final int pending = _pendingDeltas[playerIndex];
    if (pending == 0) {
      return;
    }
    final int currentLp = _lifePoints[playerIndex];
    setState(() {
      if (widget.playerCount == 2 && playerIndex < 2) {
        _twoPlayerLifeEvents.add(
          TwoPlayerLifeEvent(
            player: playerIndex + 1,
            delta: pending,
            resultingLife: currentLp,
          ),
        );
      }
      _historyEntries.add(
        '${_playerName(playerIndex)}: ${_formatSigned(pending)} = $currentLp',
      );
      _pendingDeltas[playerIndex] = 0;
    });
  }

  void _applySignedDelta({required int playerIndex, required int delta}) {
    final int currentLp = _lifePoints[playerIndex];
    final int nextLp = max(0, currentLp + delta);
    final int effectiveDelta = nextLp - currentLp;
    if (effectiveDelta == 0) {
      return;
    }

    setState(() {
      _lifePoints[playerIndex] = nextLp;
      _pendingDeltas[playerIndex] += effectiveDelta;
    });
    _startPendingTimer(playerIndex);
  }

  List<String> _historySnapshotWithPending() {
    if (widget.playerCount == 2) {
      final List<TwoPlayerLifeEvent> events = List<TwoPlayerLifeEvent>.from(
        _twoPlayerLifeEvents,
      );
      for (int index = 0; index < 2; index += 1) {
        final int pending = _pendingDeltas[index];
        if (pending == 0) {
          continue;
        }
        events.add(
          TwoPlayerLifeEvent(
            player: index + 1,
            delta: pending,
            resultingLife: _lifePoints[index],
          ),
        );
      }
      return _buildTwoPlayerHistoryTable(
        playerOneName: _playerName(0),
        playerTwoName: _playerName(1),
        initialPlayerOneLife: widget.initialLifePoints,
        initialPlayerTwoLife: widget.initialLifePoints,
        events: events,
      );
    }

    final List<String> snapshot = List<String>.from(_historyEntries);
    for (int index = 0; index < widget.playerCount; index += 1) {
      final int pending = _pendingDeltas[index];
      if (pending == 0) {
        continue;
      }
      snapshot.add(
        '${_playerName(index)}: ${_formatSigned(pending)} = ${_lifePoints[index]}',
      );
    }
    return snapshot;
  }

  void _closeWithHistory({String matchResult = '', bool shouldSave = true}) {
    _diceRollTimer?.cancel();
    for (int index = 0; index < widget.playerCount; index += 1) {
      _cancelPendingTimer(index);
    }
    final String trimmedOpponent = _opponentName.trim();
    final String opponentForHistory = trimmedOpponent.isNotEmpty
        ? trimmedOpponent
        : (matchResult.trim().isNotEmpty && _selectedGameStage == 'G1'
              ? _lastCompletedOpponentName.trim()
              : '');
    Navigator.of(context).pop(
      DuelResultPayload(
        lifePointHistory: _historySnapshotWithPending(),
        gameStage: _selectedGameStage,
        opponentName: opponentForHistory,
        deckName: _deckInUse,
        matchResult: matchResult,
        shouldSave: shouldSave,
      ),
    );
  }

  Future<void> _openHistoryForPlayer(int playerIndex) async {
    final List<String> historySnapshot = _historySnapshotWithPending();
    final placement = _placementForPlayer(playerIndex);

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close history',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (BuildContext context, _, _) {
        return SafeArea(
          child: RotatedBox(
            quarterTurns: placement.quarterTurns,
            child: Material(
              color: const Color(0xFF141414),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'LP History',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.08,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF101010),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: _buildLifeHistoryView(
                          lines: historySnapshot,
                          dividerColor: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> _,
            Widget child,
          ) {
            final Animation<Offset> offsetAnimation =
                Tween<Offset>(
                  begin: placement.beginOffset,
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                );

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: offsetAnimation, child: child),
            );
          },
    );
  }

  Map<_MtgResourceCounter, int> _resourceCountersForPlayer(int playerIndex) {
    return _resourceCounters[playerIndex];
  }

  Map<_MtgStatusCounter, int> _statusCountersForPlayer(int playerIndex) {
    return _statusCounters[playerIndex];
  }

  int _poisonCountersForPlayer(int playerIndex) {
    return _statusCountersForPlayer(playerIndex)[_MtgStatusCounter.poison] ?? 0;
  }

  int _experienceCountersForPlayer(int playerIndex) {
    return _statusCountersForPlayer(
          playerIndex,
        )[_MtgStatusCounter.experience] ??
        0;
  }

  int _commanderDamageFromPlayer({
    required int receiverIndex,
    required int sourceIndex,
  }) {
    return _commanderDamageReceived[receiverIndex][sourceIndex];
  }

  int _commanderDamageTotalForPlayer(int playerIndex) {
    final List<int> values = _commanderDamageReceived[playerIndex];
    int total = 0;
    for (int index = 0; index < values.length; index += 1) {
      if (index == playerIndex) {
        continue;
      }
      total += values[index];
    }
    return total;
  }

  void _changeCommanderDamage({
    required int receiverIndex,
    required int sourceIndex,
    required int delta,
  }) {
    if (receiverIndex == sourceIndex) {
      return;
    }

    final int current = _commanderDamageFromPlayer(
      receiverIndex: receiverIndex,
      sourceIndex: sourceIndex,
    );
    final int next = max(0, current + delta);
    final int effective = next - current;
    if (effective == 0) {
      return;
    }

    setState(() {
      _commanderDamageReceived[receiverIndex][sourceIndex] = next;
    });
    _applySignedDelta(playerIndex: receiverIndex, delta: -effective);
  }

  void _changeMtgResourceCounter({
    required int playerIndex,
    required _MtgResourceCounter counter,
    required int delta,
  }) {
    final Map<_MtgResourceCounter, int> counters = _resourceCountersForPlayer(
      playerIndex,
    );
    final int current = counters[counter] ?? 0;
    final int next = max(0, current + delta);
    if (next == current) {
      return;
    }
    setState(() {
      counters[counter] = next;
    });
  }

  void _changeMtgStatusCounter({
    required int playerIndex,
    required _MtgStatusCounter counter,
    required int delta,
  }) {
    final Map<_MtgStatusCounter, int> counters = _statusCountersForPlayer(
      playerIndex,
    );
    final int current = counters[counter] ?? 0;
    final int next = max(0, current + delta);
    if (next == current) {
      return;
    }
    setState(() {
      counters[counter] = next;
    });
  }

  Future<void> _openMtgCountersPanel({
    required int playerIndex,
    required String title,
    required Widget Function(StateSetter setModalState) contentBuilder,
  }) async {
    final placement = _placementForPlayer(playerIndex);

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close counters',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (BuildContext context, _, _) {
        return SafeArea(
          child: RotatedBox(
            quarterTurns: placement.quarterTurns,
            child: Material(
              color: const Color(0xFF141414),
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setModalState) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close_rounded),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.08,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(child: contentBuilder(setModalState)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
      transitionBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> _,
            Widget child,
          ) {
            final Animation<Offset> offsetAnimation =
                Tween<Offset>(
                  begin: placement.beginOffset,
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                );

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: offsetAnimation, child: child),
            );
          },
    );
  }

  Widget _buildMtgCounterRow({
    required Widget label,
    required int value,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
    bool compact = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: compact ? 6 : 8),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Expanded(child: label),
          IconButton(
            onPressed: onDecrement,
            icon: const Icon(Icons.remove_rounded),
            style: IconButton.styleFrom(
              minimumSize: Size.square(compact ? 30 : 32),
              backgroundColor: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 32,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: compact ? 15 : 16,
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: onIncrement,
            icon: const Icon(Icons.add_rounded),
            style: IconButton.styleFrom(
              minimumSize: Size.square(compact ? 30 : 32),
              backgroundColor: Colors.white.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMtgResourceCountersForPlayer(int playerIndex) async {
    await _openMtgCountersPanel(
      playerIndex: playerIndex,
      title: '${_playerName(playerIndex)} - Mana & Storm',
      contentBuilder: (StateSetter setModalState) {
        final Map<_MtgResourceCounter, int> counters =
            _resourceCountersForPlayer(playerIndex);
        return Column(
          children: [
            for (final _MtgResourceCounter counter
                in _MtgResourceCounter.values)
              Expanded(
                child: _buildMtgCounterRow(
                  compact: true,
                  label: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: counter.accentColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          counter.label,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  value: counters[counter] ?? 0,
                  onDecrement: () {
                    _changeMtgResourceCounter(
                      playerIndex: playerIndex,
                      counter: counter,
                      delta: -1,
                    );
                    setModalState(() {});
                  },
                  onIncrement: () {
                    _changeMtgResourceCounter(
                      playerIndex: playerIndex,
                      counter: counter,
                      delta: 1,
                    );
                    setModalState(() {});
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _openMtgStatusCountersForPlayer(int playerIndex) async {
    await _openMtgCountersPanel(
      playerIndex: playerIndex,
      title: '${_playerName(playerIndex)} - Poison & Experience',
      contentBuilder: (StateSetter setModalState) {
        final Map<_MtgStatusCounter, int> counters = _statusCountersForPlayer(
          playerIndex,
        );
        return Column(
          children: [
            for (final _MtgStatusCounter counter in _MtgStatusCounter.values)
              _buildMtgCounterRow(
                label: Row(
                  children: [
                    if (counter == _MtgStatusCounter.poison) ...[
                      Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1D5F2A),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          '\u03A6',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        counter.label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                value: counters[counter] ?? 0,
                onDecrement: () {
                  _changeMtgStatusCounter(
                    playerIndex: playerIndex,
                    counter: counter,
                    delta: -1,
                  );
                  setModalState(() {});
                },
                onIncrement: () {
                  _changeMtgStatusCounter(
                    playerIndex: playerIndex,
                    counter: counter,
                    delta: 1,
                  );
                  setModalState(() {});
                },
              ),
            const Spacer(),
          ],
        );
      },
    );
  }

  Future<void> _openCommanderDamageForPlayer(int playerIndex) async {
    await _openMtgCountersPanel(
      playerIndex: playerIndex,
      title: '${_playerName(playerIndex)} - Commander Damage',
      contentBuilder: (StateSetter setModalState) {
        final List<int> opponents = List<int>.generate(
          widget.playerCount,
          (int index) => index,
        ).where((int index) => index != playerIndex).toList(growable: false);

        if (opponents.isEmpty) {
          return const Center(
            child: Text(
              'No opponents in this match.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          );
        }

        return ListView(
          children: [
            for (final int sourceIndex in opponents)
              _buildMtgCounterRow(
                label: Row(
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      size: 18,
                      color: const Color(0xFFFF7A7A),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'From ${_playerName(sourceIndex)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                value: _commanderDamageFromPlayer(
                  receiverIndex: playerIndex,
                  sourceIndex: sourceIndex,
                ),
                onDecrement: () {
                  _changeCommanderDamage(
                    receiverIndex: playerIndex,
                    sourceIndex: sourceIndex,
                    delta: -1,
                  );
                  setModalState(() {});
                },
                onIncrement: () {
                  _changeCommanderDamage(
                    receiverIndex: playerIndex,
                    sourceIndex: sourceIndex,
                    delta: 1,
                  );
                  setModalState(() {});
                },
              ),
          ],
        );
      },
    );
  }

  Future<void> _openMatchDetailsEditor() async {
    final TextEditingController opponentController = TextEditingController(
      text: _opponentName,
    );
    final List<TextEditingController> playerNameControllers =
        List<TextEditingController>.generate(
          widget.playerCount,
          (int index) => TextEditingController(text: _playerName(index)),
        );
    String stage = _selectedGameStage;
    final List<String> deckOptions = _deckOptionsForDetails();
    String selectedDeck = _deckInUse.trim();
    if (selectedDeck.isNotEmpty && !deckOptions.contains(selectedDeck)) {
      selectedDeck = '';
    }

    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Match details'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isMultiplayer) ...[
                      TextField(
                        controller: opponentController,
                        decoration: const InputDecoration(
                          labelText: 'Opponent name',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    DropdownButtonFormField<String>(
                      initialValue: stage,
                      decoration: const InputDecoration(
                        labelText: 'Game',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _supportedGameStages
                          .map((String item) {
                            return DropdownMenuItem<String>(
                              value: item,
                              child: Text(item),
                            );
                          })
                          .toList(growable: false),
                      onChanged: (String? value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() {
                          stage = value;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedDeck,
                      decoration: const InputDecoration(
                        labelText: 'Deck in use',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: <DropdownMenuItem<String>>[
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('No deck'),
                        ),
                        ...deckOptions.map((String deckName) {
                          return DropdownMenuItem<String>(
                            value: deckName,
                            child: Text(deckName),
                          );
                        }),
                      ],
                      onChanged: (String? value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() {
                          selectedDeck = value;
                        });
                      },
                    ),
                    if (_isMultiplayer) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Player names',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (
                        int playerIndex = 0;
                        playerIndex < widget.playerCount;
                        playerIndex += 1
                      ) ...[
                        TextField(
                          controller: playerNameControllers[playerIndex],
                          decoration: InputDecoration(
                            labelText: 'Player ${playerIndex + 1} name',
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        if (playerIndex != widget.playerCount - 1)
                          const SizedBox(height: 8),
                      ],
                    ],
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (shouldSave != true) {
      opponentController.dispose();
      for (final TextEditingController controller in playerNameControllers) {
        controller.dispose();
      }
      return;
    }

    setState(() {
      _opponentName = opponentController.text.trim();
      if (_opponentName.isNotEmpty) {
        _lastCompletedOpponentName = _opponentName;
      }
      _deckInUse = selectedDeck.trim();
      _selectedGameStage = stage;
      if (widget.playerCount == 2 && stage == 'G1') {
        _bo3Wins = 0;
        _bo3Losses = 0;
      }
      if (_isMultiplayer) {
        for (
          int playerIndex = 0;
          playerIndex < widget.playerCount;
          playerIndex += 1
        ) {
          _playerNames[playerIndex] = _sanitizePlayerName(
            playerNameControllers[playerIndex].text,
            playerIndex,
          );
        }
      }
    });
    opponentController.dispose();
    for (final TextEditingController controller in playerNameControllers) {
      controller.dispose();
    }
  }

  void _rollDice() {
    if (_isRollingDice) {
      return;
    }
    const int totalTicks = 12;
    const Duration tickDuration = Duration(milliseconds: 85);
    _diceRollTimer?.cancel();
    setState(() {
      _isRollingDice = true;
      _diceRollTicks = 0;
      for (int index = 0; index < widget.playerCount; index += 1) {
        _diceValues[index] = _random.nextInt(6) + 1;
      }
    });

    _diceRollTimer = Timer.periodic(tickDuration, (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        for (int index = 0; index < widget.playerCount; index += 1) {
          _diceValues[index] = _random.nextInt(6) + 1;
        }
        _diceRollTicks += 1;
        if (_diceRollTicks >= totalTicks) {
          _isRollingDice = false;
          timer.cancel();
          _diceRollTimer = null;
        }
      });
    });
  }

  Future<void> _confirmReset({bool fromHome = false}) async {
    const Color resetColor = Color(0xFF232323);
    const Color winColor = Color(0xFF163825);
    const Color lossColor = Color(0xFF4A1E1E);
    const Color drawColor = Color(0xFF4D4220);
    final bool canOpenSideboardGuide = _selectedDeckForGuide() != null;

    final String? action = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('End or reset match'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.tonal(
                onPressed: canOpenSideboardGuide
                    ? () => Navigator.of(context).pop('sideboard')
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: widget.settings.buttonColor,
                ),
                child: const Text('Sideboard Guide'),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () => Navigator.of(context).pop('reset'),
                style: FilledButton.styleFrom(backgroundColor: resetColor),
                child: const Text('Reset without saving'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.of(context).pop('Win'),
                style: FilledButton.styleFrom(backgroundColor: winColor),
                child: const Text('Win'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.of(context).pop('Loss'),
                style: FilledButton.styleFrom(backgroundColor: lossColor),
                child: const Text('Loss'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.of(context).pop('Draw'),
                style: FilledButton.styleFrom(backgroundColor: drawColor),
                child: const Text('Draw'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
    if (action == null || !mounted) {
      return;
    }
    if (action == 'sideboard') {
      await _openSideboardGuideDialog();
      return;
    }
    if (action == 'Win' || action == 'Loss' || action == 'Draw') {
      if (fromHome || widget.playerCount != 2) {
        _closeWithHistory(matchResult: action);
        return;
      }

      _diceRollTimer?.cancel();
      _diceRollTimer = null;
      for (int index = 0; index < widget.playerCount; index += 1) {
        _cancelPendingTimer(index);
      }
      setState(() {
        _advanceBo3AfterRestart(declaredResult: action);
        for (int index = 0; index < widget.playerCount; index += 1) {
          _lifePoints[index] = widget.initialLifePoints;
          _pendingDeltas[index] = 0;
          _diceValues[index] = null;
          for (final _MtgResourceCounter counter
              in _MtgResourceCounter.values) {
            _resourceCounters[index][counter] = 0;
          }
          for (final _MtgStatusCounter counter in _MtgStatusCounter.values) {
            _statusCounters[index][counter] = 0;
          }
          for (
            int sourceIndex = 0;
            sourceIndex < widget.playerCount;
            sourceIndex += 1
          ) {
            _commanderDamageReceived[index][sourceIndex] = 0;
          }
        }
        _isRollingDice = false;
        _diceRollTicks = 0;
        _twoPlayerLifeEvents.clear();
        _historyEntries
          ..clear()
          ..addAll(
            List<String>.generate(
              widget.playerCount,
              (int index) =>
                  '${_playerName(index)}: ${widget.initialLifePoints}',
            ),
          );
      });
      return;
    }
    if (action != 'reset') {
      return;
    }
    if (fromHome) {
      _closeWithHistory(shouldSave: false);
      return;
    }

    _diceRollTimer?.cancel();
    _diceRollTimer = null;
    for (int index = 0; index < widget.playerCount; index += 1) {
      _cancelPendingTimer(index);
    }
    setState(() {
      _advanceBo3AfterRestart();
      for (int index = 0; index < widget.playerCount; index += 1) {
        _lifePoints[index] = widget.initialLifePoints;
        _pendingDeltas[index] = 0;
        _diceValues[index] = null;
        for (final _MtgResourceCounter counter in _MtgResourceCounter.values) {
          _resourceCounters[index][counter] = 0;
        }
        for (final _MtgStatusCounter counter in _MtgStatusCounter.values) {
          _statusCounters[index][counter] = 0;
        }
        for (
          int sourceIndex = 0;
          sourceIndex < widget.playerCount;
          sourceIndex += 1
        ) {
          _commanderDamageReceived[index][sourceIndex] = 0;
        }
      }
      _isRollingDice = false;
      _diceRollTicks = 0;
      _twoPlayerLifeEvents.clear();
      _historyEntries
        ..clear()
        ..addAll(
          List<String>.generate(
            widget.playerCount,
            (int index) => '${_playerName(index)}: ${widget.initialLifePoints}',
          ),
        );
    });
  }

  List<Alignment> _diePipAlignments(int value) {
    switch (value) {
      case 1:
        return const <Alignment>[Alignment.center];
      case 2:
        return const <Alignment>[Alignment.topLeft, Alignment.bottomRight];
      case 3:
        return const <Alignment>[
          Alignment.topLeft,
          Alignment.center,
          Alignment.bottomRight,
        ];
      case 4:
        return const <Alignment>[
          Alignment.topLeft,
          Alignment.topRight,
          Alignment.bottomLeft,
          Alignment.bottomRight,
        ];
      case 5:
        return const <Alignment>[
          Alignment.topLeft,
          Alignment.topRight,
          Alignment.center,
          Alignment.bottomLeft,
          Alignment.bottomRight,
        ];
      default:
        return const <Alignment>[
          Alignment.topLeft,
          Alignment.centerLeft,
          Alignment.bottomLeft,
          Alignment.topRight,
          Alignment.centerRight,
          Alignment.bottomRight,
        ];
    }
  }

  Widget _buildDieFace(
    int value, {
    required bool compact,
    required bool isRolling,
  }) {
    final double size = compact ? 22 : 28;
    final double pipSize = compact ? 3.1 : 3.8;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isRolling ? const Color(0xFFFFE9B3) : const Color(0xFFEEEDED),
        borderRadius: BorderRadius.circular(compact ? 6 : 8),
        border: Border.all(
          color: isRolling ? const Color(0xFFE7C061) : const Color(0xFFB0AFAF),
          width: isRolling ? 1.6 : 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 3 : 4),
        child: Stack(
          children: [
            for (final Alignment align in _diePipAlignments(value))
              Align(
                alignment: align,
                child: Container(
                  width: pipSize,
                  height: pipSize,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A1A1A),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingDeltaBadge({
    required int playerIndex,
    required bool compact,
  }) {
    final int value = _pendingDeltas[playerIndex];
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 140),
      child: value == 0
          ? const SizedBox.shrink(key: ValueKey<String>('empty-delta'))
          : Container(
              key: ValueKey<String>('pending-$playerIndex-$value'),
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 6 : 8,
                vertical: compact ? 2 : 3,
              ),
              decoration: BoxDecoration(
                color: value > 0
                    ? const Color(0xFF245D32)
                    : const Color(0xFF6A2323),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _formatSigned(value),
                style: TextStyle(
                  fontSize: compact ? 10 : 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
    );
  }

  Widget _buildInlineLpTapHint({
    required bool isPositive,
    required bool compact,
  }) {
    return Container(
      width: compact ? 24 : 30,
      height: compact ? 24 : 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: widget.settings.buttonColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Icon(
        isPositive ? Icons.add_rounded : Icons.remove_rounded,
        size: compact ? 16 : 19,
        weight: 700,
      ),
    );
  }

  Widget _buildPanelActionButton({
    required String tooltip,
    required Widget icon,
    required VoidCallback onPressed,
    required bool compact,
    double? side,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: icon,
      style: IconButton.styleFrom(
        backgroundColor: widget.settings.buttonColor,
        minimumSize: Size.square(side ?? (compact ? 26 : 30)),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildLabeledPanelAction({
    required String label,
    required String tooltip,
    required Widget icon,
    required VoidCallback onPressed,
    required bool compact,
    double? side,
    double? slotWidth,
  }) {
    final double labelSize = compact ? 8.5 : 9.5;
    final Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPanelActionButton(
          tooltip: tooltip,
          icon: icon,
          onPressed: onPressed,
          compact: compact,
          side: side,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: labelSize,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.82),
            height: 1.0,
          ),
        ),
      ],
    );

    if (slotWidth == null) {
      return content;
    }

    return SizedBox(width: slotWidth, child: content);
  }

  Widget _playerPanel({
    required int playerIndex,
    required bool compact,
    required bool longSide,
  }) {
    final int? dieValue = _diceValues[playerIndex];
    final int lifePoints = _lifePoints[playerIndex];
    final int poisonCounters = _poisonCountersForPlayer(playerIndex);
    final int experienceCounters = _experienceCountersForPlayer(playerIndex);
    final int commanderDamage = _commanderDamageTotalForPlayer(playerIndex);
    final bool dense = compact || longSide;
    final bool useEqualShortSideActionSlots =
        !longSide && widget.playerCount == 2;
    final double? actionSlotWidth = useEqualShortSideActionSlots ? 58 : null;
    final bool tight = longSide && widget.playerCount >= 4;
    final bool ultraTight = longSide && widget.playerCount >= 5;
    final double actionSide = longSide
        ? (ultraTight ? 26 : (tight ? 29 : 33))
        : (dense ? 27 : 30);
    final double actionIconSize = longSide
        ? (ultraTight ? 16 : (tight ? 18 : 20))
        : (dense ? 15 : 16);
    final String panelPlayerName = ultraTight
        ? 'P${playerIndex + 1}'
        : _playerName(playerIndex).toUpperCase();
    final String lpOwnerLabel = _playerName(playerIndex);
    final double lpHorizontalPadding = longSide
        ? (ultraTight ? 12 : (tight ? 14 : 18))
        : (dense ? 22 : 16);
    final String historyLabel = ultraTight ? 'Hist' : 'History';
    final String manaLabel = ultraTight ? 'Mana' : 'Mana';
    final String statusLabel = ultraTight ? 'Cntr' : 'Counters';
    final String commanderLabel = ultraTight ? 'Cmd' : 'Commander';
    final List<String> statusFragments = <String>[
      if (poisonCounters > 0) 'Poison $poisonCounters',
      if (experienceCounters > 0) 'Exp $experienceCounters',
      if (commanderDamage > 0) 'Cmd $commanderDamage',
    ];

    final Widget historyButton = _buildLabeledPanelAction(
      label: historyLabel,
      tooltip: 'Open history',
      onPressed: () => _openHistoryForPlayer(playerIndex),
      compact: dense,
      side: actionSide,
      slotWidth: actionSlotWidth,
      icon: Icon(Icons.format_list_bulleted_rounded, size: actionIconSize),
    );
    final Widget manaButton = _buildLabeledPanelAction(
      label: manaLabel,
      tooltip: 'Open mana and storm counters',
      onPressed: () => _openMtgResourceCountersForPlayer(playerIndex),
      compact: dense,
      side: actionSide,
      slotWidth: actionSlotWidth,
      icon: Icon(Icons.blur_circular_rounded, size: actionIconSize),
    );
    final Widget statusButton = _buildLabeledPanelAction(
      label: statusLabel,
      tooltip: 'Open poison and experience counters',
      onPressed: () => _openMtgStatusCountersForPlayer(playerIndex),
      compact: dense,
      side: actionSide,
      slotWidth: actionSlotWidth,
      icon: Text(
        '\u03A6',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: actionIconSize - 1,
        ),
      ),
    );
    final Widget commanderButton = _buildLabeledPanelAction(
      label: commanderLabel,
      tooltip: 'Open commander damage counters',
      onPressed: () => _openCommanderDamageForPlayer(playerIndex),
      compact: dense,
      side: actionSide,
      slotWidth: actionSlotWidth,
      icon: Icon(Icons.local_fire_department_rounded, size: actionIconSize),
    );
    final Widget panelHeader = longSide
        ? Align(
            alignment: Alignment.centerLeft,
            child: Text(
              panelPlayerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.86),
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                fontSize: dense ? 11 : 13,
              ),
            ),
          )
        : Row(
            children: [
              Expanded(
                child: Text(
                  panelPlayerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    fontSize: dense ? 11 : 13,
                  ),
                ),
              ),
              SizedBox(width: dense ? 4 : 6),
              historyButton,
              SizedBox(width: dense ? 4 : 6),
              manaButton,
              SizedBox(width: dense ? 4 : 6),
              statusButton,
              SizedBox(width: dense ? 4 : 6),
              commanderButton,
            ],
          );

    Widget? statusInfo;
    if (!longSide &&
        (poisonCounters > 0 || experienceCounters > 0 || commanderDamage > 0)) {
      statusInfo = Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            if (poisonCounters > 0)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: dense ? 9 : 11,
                  vertical: dense ? 3 : 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF6A2323),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFFF8A8A)),
                ),
                child: Text(
                  'Poison: $poisonCounters',
                  style: TextStyle(
                    color: const Color(0xFFFFA3A3),
                    fontWeight: FontWeight.w700,
                    fontSize: dense ? 11 : 13,
                  ),
                ),
              ),
            if (experienceCounters > 0)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: dense ? 9 : 11,
                  vertical: dense ? 3 : 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF234A6A),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFF7AC7FF)),
                ),
                child: Text(
                  'Exp: $experienceCounters',
                  style: TextStyle(
                    color: const Color(0xFFBEE8FF),
                    fontWeight: FontWeight.w700,
                    fontSize: dense ? 11 : 13,
                  ),
                ),
              ),
            if (commanderDamage > 0)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: dense ? 9 : 11,
                  vertical: dense ? 3 : 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF5A1E1E),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFFF7575)),
                ),
                child: Text(
                  'Commander: $commanderDamage',
                  style: TextStyle(
                    color: const Color(0xFFFFA9A9),
                    fontWeight: FontWeight.w700,
                    fontSize: dense ? 11 : 13,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    final Widget lpCard = Stack(
      children: [
        Align(
          alignment: Alignment.center,
          child: Container(
            width: double.infinity,
            height: longSide ? double.infinity : null,
            padding: EdgeInsets.symmetric(
              horizontal: dense ? 8 : 12,
              vertical: dense ? 5 : 8,
            ),
            decoration: BoxDecoration(
              color: widget.settings.lifePointsBackgroundColor,
              borderRadius: BorderRadius.circular(longSide ? 8 : 14),
              border: Border.all(
                color: Colors.white.withValues(alpha: longSide ? 0.07 : 0.12),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(longSide ? 8 : 12),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Row(
                      children: [
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _applySignedDelta(
                                playerIndex: playerIndex,
                                delta: -1,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _applySignedDelta(
                                playerIndex: playerIndex,
                                delta: 1,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: EdgeInsets.only(left: dense ? 5 : 8),
                                child: _buildInlineLpTapHint(
                                  isPositive: false,
                                  compact: dense,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: EdgeInsets.only(right: dense ? 5 : 8),
                                child: _buildInlineLpTapHint(
                                  isPositive: true,
                                  compact: dense,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: lpHorizontalPadding,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '$lifePoints',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: longSide ? 320 : 360,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: dieValue != null ? (dense ? 28 : 34) : (dense ? 2 : 4),
          child: _buildPendingDeltaBadge(
            playerIndex: playerIndex,
            compact: dense,
          ),
        ),
        if (dieValue != null)
          Positioned(
            right: 0,
            top: dense ? 0 : 2,
            child: _buildDieFace(
              dieValue,
              compact: true,
              isRolling: _isRollingDice,
            ),
          ),
        if (longSide && statusFragments.isNotEmpty)
          Positioned(
            left: dense ? 6 : 8,
            top: dense ? 4 : 6,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: dense ? 8 : 10,
                vertical: dense ? 3 : 4,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Text(
                statusFragments.join(' • '),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: ultraTight ? 11 : 13,
                ),
              ),
            ),
          ),
        if (longSide)
          Positioned(
            right: dense ? 6 : 8,
            bottom: dense ? 4 : 6,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: ultraTight ? 78 : 128),
              child: Text(
                lpOwnerLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontWeight: FontWeight.w700,
                  fontSize: ultraTight ? 9 : 11,
                ),
              ),
            ),
          ),
      ],
    );

    final Widget? quickTenControls = (longSide || widget.playerCount > 2)
        ? null
        : Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: () =>
                      _applySignedDelta(playerIndex: playerIndex, delta: -10),
                  style: FilledButton.styleFrom(
                    backgroundColor: widget.settings.buttonColor,
                    minimumSize: const Size.fromHeight(34),
                  ),
                  child: const Text(
                    '-10',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: () =>
                      _applySignedDelta(playerIndex: playerIndex, delta: 10),
                  style: FilledButton.styleFrom(
                    backgroundColor: widget.settings.buttonColor,
                    minimumSize: const Size.fromHeight(34),
                  ),
                  child: const Text(
                    '+10',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ),
              ),
            ],
          );

    if (longSide) {
      final double actionGap = ultraTight ? 3 : (tight ? 4 : 6);
      final List<Widget> actionRail = <Widget>[
        historyButton,
        SizedBox(height: actionGap),
        manaButton,
        SizedBox(height: actionGap),
        statusButton,
        SizedBox(height: actionGap),
        commanderButton,
      ];
      final BorderRadius railRadius = BorderRadius.circular(
        ultraTight ? 8 : 12,
      );

      return Padding(
        padding: EdgeInsets.all(ultraTight ? 1 : 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: lpCard),
            SizedBox(width: ultraTight ? 2 : 4),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: ultraTight ? 1 : 2,
                vertical: ultraTight ? 4 : 6,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: railRadius,
                border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: actionRail,
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: EdgeInsets.all(longSide ? (ultraTight ? 2 : 3) : (dense ? 6 : 8)),
      padding: EdgeInsets.all(
        longSide ? (ultraTight ? 4 : 6) : (dense ? 6 : 8),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF221818),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          panelHeader,
          if (statusInfo != null) ...[
            SizedBox(height: ultraTight ? 2 : (dense ? 4 : 6)),
            statusInfo,
          ],
          SizedBox(height: dense ? 2 : 4),
          Expanded(child: lpCard),
          if (quickTenControls != null) ...[
            SizedBox(height: dense ? 2 : 4),
            quickTenControls,
          ],
        ],
      ),
    );
  }

  Widget _buildCenterControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Card(
        color: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              const double spacing = 8;
              const int buttonsCount = 4;
              final double buttonWidth =
                  ((constraints.maxWidth - spacing * (buttonsCount - 1)) /
                          buttonsCount)
                      .clamp(54.0, 78.0);
              final double controlsWidth =
                  buttonWidth * buttonsCount + spacing * (buttonsCount - 1);

              Widget controlButton({
                required VoidCallback? onPressed,
                required Widget icon,
              }) {
                return SizedBox(
                  width: buttonWidth,
                  child: FilledButton.tonal(
                    onPressed: onPressed,
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.settings.buttonColor,
                      minimumSize: const Size.fromHeight(46),
                      padding: EdgeInsets.zero,
                    ),
                    child: Center(child: icon),
                  ),
                );
              }

              return Center(
                child: SizedBox(
                  width: controlsWidth,
                  child: Row(
                    children: [
                      controlButton(
                        onPressed: () => _confirmReset(fromHome: true),
                        icon: const Icon(Icons.home_outlined, size: 28),
                      ),
                      const SizedBox(width: spacing),
                      controlButton(
                        onPressed: _confirmReset,
                        icon: const Icon(Icons.restart_alt, size: 28),
                      ),
                      const SizedBox(width: spacing),
                      controlButton(
                        onPressed: _openMatchDetailsEditor,
                        icon: const Icon(Icons.edit_outlined, size: 28),
                      ),
                      const SizedBox(width: spacing),
                      controlButton(
                        onPressed: _isRollingDice ? null : _rollDice,
                        icon: const Icon(Icons.casino_outlined, size: 28),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerRow({
    required List<int?> slots,
    bool forceCompact = false,
  }) {
    final int activePlayers = slots.whereType<int>().length;
    final List<int> slotFlexes = _slotFlexesForSlots(slots);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int index = 0; index < slots.length; index += 1) ...[
          if (index > 0) const SizedBox(width: 4),
          Flexible(
            flex: slotFlexes[index],
            child: Builder(
              builder: (BuildContext context) {
                final int? playerIndex = slots[index];
                if (playerIndex == null) {
                  return const SizedBox.shrink();
                }

                final int quarterTurns = _quarterTurnsForPlayer(playerIndex);
                final bool longSide = quarterTurns == 1 || quarterTurns == 3;
                final bool compact =
                    forceCompact ||
                    longSide ||
                    activePlayers > 1 ||
                    widget.playerCount >= 5;

                Widget panel = _playerPanel(
                  playerIndex: playerIndex,
                  compact: compact,
                  longSide: longSide,
                );
                if (quarterTurns != 0) {
                  panel = RotatedBox(quarterTurns: quarterTurns, child: panel);
                }
                return panel;
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPlayerPanelSlot({
    required int playerIndex,
    required int quarterTurns,
    required bool longSide,
    bool forceCompact = false,
  }) {
    final bool compact = forceCompact || longSide || widget.playerCount >= 5;
    Widget panel = _playerPanel(
      playerIndex: playerIndex,
      compact: compact,
      longSide: longSide,
    );
    if (quarterTurns != 0) {
      panel = RotatedBox(quarterTurns: quarterTurns, child: panel);
    }
    return panel;
  }

  Widget _buildThreePlayerStandardLayout() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
        child: Stack(
          children: [
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: _buildPlayerPanelSlot(
                      playerIndex: 1,
                      quarterTurns: 1,
                      longSide: true,
                      forceCompact: true,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: _buildPlayerPanelSlot(
                            playerIndex: 2,
                            quarterTurns: 3,
                            longSide: true,
                            forceCompact: true,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: _buildPlayerPanelSlot(
                            playerIndex: 0,
                            quarterTurns: 3,
                            longSide: true,
                            forceCompact: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.center,
              child: _buildLongSideControlsLauncher(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiplayerRowsLayout({required List<_MtgLayoutRowSpec> rows}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
        child: Stack(
          children: [
            Column(
              children: [
                for (final _MtgLayoutRowSpec row in rows)
                  Expanded(
                    flex: row.flex,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: _buildPlayerRow(slots: row.slots),
                    ),
                  ),
              ],
            ),
            Align(
              alignment: Alignment.center,
              child: _buildLongSideControlsLauncher(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStandardMultiplayerLayout() {
    if (widget.playerCount == 3) {
      return _buildThreePlayerStandardLayout();
    }
    if (widget.playerCount == 5) {
      return _buildFivePlayerStandardLayout();
    }
    if (widget.playerCount == 6) {
      return _buildSixPlayerStandardLayout();
    }

    return _buildMultiplayerRowsLayout(
      rows: _mtgLayoutRows(
        playerCount: widget.playerCount,
        layoutMode: MtgDuelLayoutMode.standard,
      ),
    );
  }

  Widget _buildFivePlayerStandardLayout() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Column(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: _buildPlayerPanelSlot(
                              playerIndex: 2,
                              quarterTurns: _quarterTurnsForPlayer(2),
                              longSide: true,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: _buildPlayerPanelSlot(
                              playerIndex: 1,
                              quarterTurns: _quarterTurnsForPlayer(1),
                              longSide: true,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: _buildPlayerPanelSlot(
                              playerIndex: 0,
                              quarterTurns: _quarterTurnsForPlayer(0),
                              longSide: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Column(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: _buildPlayerPanelSlot(
                              playerIndex: 4,
                              quarterTurns: _quarterTurnsForPlayer(4),
                              longSide: true,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: _buildPlayerPanelSlot(
                              playerIndex: 3,
                              quarterTurns: _quarterTurnsForPlayer(3),
                              longSide: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.center,
              child: _buildLongSideControlsLauncher(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSixPlayerStandardLayout() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Column(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: _buildPlayerPanelSlot(
                              playerIndex: 2,
                              quarterTurns: _quarterTurnsForPlayer(2),
                              longSide: true,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: _buildPlayerPanelSlot(
                              playerIndex: 1,
                              quarterTurns: _quarterTurnsForPlayer(1),
                              longSide: true,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: _buildPlayerPanelSlot(
                              playerIndex: 0,
                              quarterTurns: _quarterTurnsForPlayer(0),
                              longSide: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Column(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: _buildPlayerPanelSlot(
                              playerIndex: 5,
                              quarterTurns: _quarterTurnsForPlayer(5),
                              longSide: true,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: _buildPlayerPanelSlot(
                              playerIndex: 4,
                              quarterTurns: _quarterTurnsForPlayer(4),
                              longSide: true,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: _buildPlayerPanelSlot(
                              playerIndex: 3,
                              quarterTurns: _quarterTurnsForPlayer(3),
                              longSide: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.center,
              child: _buildLongSideControlsLauncher(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFourPlayerTableLayout() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  flex: 26,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: _buildPlayerRow(slots: const <int?>[2]),
                  ),
                ),
                Expanded(
                  flex: 48,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: _buildPlayerPanelSlot(
                              playerIndex: 1,
                              quarterTurns: _quarterTurnsForPlayer(1),
                              longSide: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                widthFactor: 1,
                                heightFactor: 0.94,
                                alignment: Alignment.bottomCenter,
                                child: _buildPlayerPanelSlot(
                                  playerIndex: 3,
                                  quarterTurns: _quarterTurnsForPlayer(3),
                                  longSide: true,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 26,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: _buildPlayerRow(slots: const <int?>[0]),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.center,
              child: _buildLongSideControlsLauncher(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFivePlayerTableLayout() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  flex: 22,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: _buildPlayerRow(slots: const <int?>[3]),
                  ),
                ),
                Expanded(
                  flex: 56,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 9,
                          child: Column(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 1,
                                  ),
                                  child: _buildPlayerPanelSlot(
                                    playerIndex: 1,
                                    quarterTurns: _quarterTurnsForPlayer(1),
                                    longSide: true,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 1,
                                  ),
                                  child: _buildPlayerPanelSlot(
                                    playerIndex: 2,
                                    quarterTurns: _quarterTurnsForPlayer(2),
                                    longSide: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          flex: 10,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: Align(
                              alignment: Alignment.center,
                              child: _buildPlayerPanelSlot(
                                playerIndex: 4,
                                quarterTurns: _quarterTurnsForPlayer(4),
                                longSide: true,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 22,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: _buildPlayerRow(slots: const <int?>[0]),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.center,
              child: _buildLongSideControlsLauncher(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableMultiplayerLayout() {
    if (widget.playerCount == 4) {
      return _buildFourPlayerTableLayout();
    }
    if (widget.playerCount == 5) {
      return _buildFivePlayerTableLayout();
    }
    if (widget.playerCount == 6) {
      return _buildSixPlayerTableLayout();
    }
    return _buildMultiplayerRowsLayout(
      rows: _mtgLayoutRows(
        playerCount: widget.playerCount,
        layoutMode: MtgDuelLayoutMode.tableMode,
      ),
    );
  }

  Widget _buildSixPlayerTableLayout() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  flex: 24,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: _buildPlayerRow(slots: const <int?>[3]),
                  ),
                ),
                Expanded(
                  flex: 52,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 1,
                                  ),
                                  child: _buildPlayerPanelSlot(
                                    playerIndex: 1,
                                    quarterTurns: _quarterTurnsForPlayer(1),
                                    longSide: true,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 1,
                                  ),
                                  child: _buildPlayerPanelSlot(
                                    playerIndex: 2,
                                    quarterTurns: _quarterTurnsForPlayer(2),
                                    longSide: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 1,
                                  ),
                                  child: _buildPlayerPanelSlot(
                                    playerIndex: 4,
                                    quarterTurns: _quarterTurnsForPlayer(4),
                                    longSide: true,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 1,
                                  ),
                                  child: _buildPlayerPanelSlot(
                                    playerIndex: 5,
                                    quarterTurns: _quarterTurnsForPlayer(5),
                                    longSide: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 24,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: _buildPlayerRow(slots: const <int?>[0]),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.center,
              child: _buildLongSideControlsLauncher(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTwoPlayerTableLayout() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
            child: _buildPlayerRow(slots: const <int?>[1]),
          ),
        ),
        _buildCenterControls(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
            child: _buildPlayerRow(slots: const <int?>[0]),
          ),
        ),
      ],
    );
  }

  Future<void> _openLongSideControlsMenu() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        Widget menuButton({
          required String label,
          required IconData icon,
          required VoidCallback onPressed,
        }) {
          return FilledButton.tonal(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: widget.settings.buttonColor,
              minimumSize: const Size(164, 44),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          );
        }

        return Dialog(
          backgroundColor: const Color(0xFF181818),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 40,
            vertical: 24,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                menuButton(
                  label: 'Home',
                  icon: Icons.home_outlined,
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _confirmReset(fromHome: true);
                  },
                ),
                const SizedBox(height: 8),
                menuButton(
                  label: 'Reset',
                  icon: Icons.restart_alt,
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _confirmReset();
                  },
                ),
                const SizedBox(height: 8),
                menuButton(
                  label: 'Details',
                  icon: Icons.edit_outlined,
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _openMatchDetailsEditor();
                  },
                ),
                const SizedBox(height: 8),
                menuButton(
                  label: 'Dice',
                  icon: Icons.casino_outlined,
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _rollDice();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLongSideControlsLauncher() {
    return SizedBox(
      width: 48,
      child: FilledButton.tonal(
        onPressed: _openLongSideControlsMenu,
        style: FilledButton.styleFrom(
          backgroundColor: widget.settings.buttonColor,
          minimumSize: const Size(48, 52),
          padding: EdgeInsets.zero,
        ),
        child: const Icon(Icons.home_outlined, size: 26),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color duelMiddle =
        Color.lerp(
          widget.settings.backgroundStartColor,
          widget.settings.backgroundEndColor,
          0.45,
        ) ??
        widget.settings.backgroundStartColor;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        _closeWithHistory();
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                widget.settings.backgroundStartColor,
                duelMiddle,
                widget.settings.backgroundEndColor,
              ],
            ),
          ),
          child: SafeArea(
            child: _isMultiplayer
                ? Column(
                    children: [
                      _isTableMode
                          ? _buildTableMultiplayerLayout()
                          : _buildStandardMultiplayerLayout(),
                    ],
                  )
                : _buildTwoPlayerTableLayout(),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    unawaited(WakelockPlus.disable());
    _diceRollTimer?.cancel();
    for (int index = 0; index < _pendingTimers.length; index += 1) {
      _pendingTimers[index]?.cancel();
    }
    super.dispose();
  }
}

class DuelScreen extends StatefulWidget {
  const DuelScreen({
    super.key,
    required this.settings,
    this.ruleset = DuelRuleSet.yugioh,
    this.initialLifePoints = 8000,
    this.availableDeckNames = const <String>[],
    this.availableDecks = const <SideboardDeck>[],
    this.initialDeckName = '',
  });

  final AppSettings settings;
  final DuelRuleSet ruleset;
  final int initialLifePoints;
  final List<String> availableDeckNames;
  final List<SideboardDeck> availableDecks;
  final String initialDeckName;

  @override
  State<DuelScreen> createState() => _DuelScreenState();
}

class _DuelScreenState extends State<DuelScreen> {
  static const Duration _aggregationWindow = Duration(seconds: 2);

  final Random _random = Random();

  late int _playerOneLp;
  late int _playerTwoLp;

  bool _isRollingDice = false;

  int? _playerOneDie;
  int? _playerTwoDie;

  int _playerOnePendingDelta = 0;
  int _playerTwoPendingDelta = 0;

  Timer? _diceRollTimer;
  int _diceRollTicks = 0;
  Timer? _playerOnePendingTimer;
  Timer? _playerTwoPendingTimer;

  late final Map<_MtgResourceCounter, int> _playerOneResourceCounters;
  late final Map<_MtgResourceCounter, int> _playerTwoResourceCounters;
  late final Map<_MtgStatusCounter, int> _playerOneStatusCounters;
  late final Map<_MtgStatusCounter, int> _playerTwoStatusCounters;

  late final List<TwoPlayerLifeEvent> _twoPlayerLifeEvents;

  String _opponentName = '';
  String _selectedGameStage = 'G1';
  String _deckInUse = '';
  int _bo3Wins = 0;
  int _bo3Losses = 0;
  String _lastCompletedOpponentName = '';

  bool get _isMtgRules => widget.ruleset == DuelRuleSet.mtg;

  String _playerName(int player) {
    if (player == 2) {
      final String opponent = _opponentName.trim();
      if (opponent.isNotEmpty) {
        return opponent;
      }
    }
    return player == 1
        ? widget.settings.playerOneName
        : widget.settings.playerTwoName;
  }

  String _resolveInitialDeckName() {
    final String normalizedInitial = widget.initialDeckName
        .trim()
        .toLowerCase();
    if (normalizedInitial.isEmpty) {
      return '';
    }
    for (final String raw in widget.availableDeckNames) {
      final String trimmed = raw.trim();
      if (trimmed.toLowerCase() == normalizedInitial) {
        return trimmed;
      }
    }
    for (final SideboardDeck deck in widget.availableDecks) {
      final String trimmed = deck.name.trim();
      if (trimmed.toLowerCase() == normalizedInitial) {
        return trimmed;
      }
    }
    return '';
  }

  SideboardDeck? _selectedDeckForGuide() {
    final String normalizedDeck = _deckInUse.trim().toLowerCase();
    if (normalizedDeck.isEmpty) {
      return null;
    }
    for (final SideboardDeck deck in widget.availableDecks) {
      if (deck.name.trim().toLowerCase() == normalizedDeck) {
        return deck;
      }
    }
    return null;
  }

  String _formatSideboardEntries(List<SideboardCardEntry> entries) {
    if (entries.isEmpty) {
      return '-';
    }
    return entries
        .map((SideboardCardEntry entry) {
          final String name = entry.name.trim().isEmpty
              ? 'Unnamed card'
              : entry.name.trim();
          final int copies = entry.copies.clamp(1, 99).toInt();
          return '$copies x $name';
        })
        .join(', ');
  }

  Future<void> _openSideboardGuideDialog() async {
    final SideboardDeck? deck = _selectedDeckForGuide();
    if (deck == null) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        final bool hasMatchups = deck.matchups.isNotEmpty;
        return AlertDialog(
          title: Text('${deck.name} - Sideboard Guide'),
          content: SizedBox(
            width: double.maxFinite,
            child: hasMatchups
                ? SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (
                          int index = 0;
                          index < deck.matchups.length;
                          index += 1
                        ) ...[
                          if (index > 0) const SizedBox(height: 12),
                          Text(
                            deck.matchups[index].name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Side In: ${_formatSideboardEntries(deck.matchups[index].sideIn)}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Side Out: ${_formatSideboardEntries(deck.matchups[index].sideOut)}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : const Text('No matchup plans saved for this deck yet.'),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _registerCurrentGameResultForBo3() {
    if (_playerOneLp == _playerTwoLp) {
      return;
    }
    if (_playerOneLp > _playerTwoLp) {
      _bo3Wins += 1;
    } else {
      _bo3Losses += 1;
    }
  }

  void _registerDeclaredGameResultForBo3(String result) {
    if (result == 'Win') {
      _bo3Wins += 1;
      return;
    }
    if (result == 'Loss') {
      _bo3Losses += 1;
    }
  }

  void _advanceBo3AfterRestart({String? declaredResult}) {
    final String currentStage = _selectedGameStage;
    if (!_supportedGameStages.contains(currentStage)) {
      _selectedGameStage = 'G1';
      _bo3Wins = 0;
      _bo3Losses = 0;
      return;
    }

    final String explicitResult = (declaredResult ?? '').trim();
    if (explicitResult.isEmpty) {
      _registerCurrentGameResultForBo3();
    } else {
      _registerDeclaredGameResultForBo3(explicitResult);
    }

    String nextStage = 'G1';
    if (currentStage == 'G1') {
      nextStage = 'G2';
    } else if (currentStage == 'G2') {
      final bool matchClosed = _bo3Wins >= 2 || _bo3Losses >= 2;
      nextStage = matchClosed ? 'G1' : 'G3';
    } else {
      nextStage = 'G1';
    }

    _selectedGameStage = nextStage;
    if (nextStage == 'G1') {
      final String completedOpponent = _opponentName.trim();
      if (completedOpponent.isNotEmpty) {
        _lastCompletedOpponentName = completedOpponent;
      }
      _bo3Wins = 0;
      _bo3Losses = 0;
      _opponentName = '';
    }
  }

  List<String> _deckOptionsForDetails() {
    final List<String> options = <String>[];
    for (final String raw in widget.availableDeckNames) {
      final String trimmed = raw.trim();
      if (trimmed.isEmpty || options.contains(trimmed)) {
        continue;
      }
      options.add(trimmed);
    }
    final String current = _deckInUse.trim();
    if (current.isNotEmpty && !options.contains(current)) {
      options.add(current);
    }
    return options;
  }

  @override
  void initState() {
    super.initState();
    unawaited(WakelockPlus.enable());
    _deckInUse = _resolveInitialDeckName();
    _playerOneLp = widget.initialLifePoints;
    _playerTwoLp = widget.initialLifePoints;
    _playerOneResourceCounters = {
      for (final _MtgResourceCounter counter in _MtgResourceCounter.values)
        counter: 0,
    };
    _playerTwoResourceCounters = {
      for (final _MtgResourceCounter counter in _MtgResourceCounter.values)
        counter: 0,
    };
    _playerOneStatusCounters = {
      for (final _MtgStatusCounter counter in _MtgStatusCounter.values)
        counter: 0,
    };
    _playerTwoStatusCounters = {
      for (final _MtgStatusCounter counter in _MtgStatusCounter.values)
        counter: 0,
    };
    _twoPlayerLifeEvents = <TwoPlayerLifeEvent>[];
  }

  String _formatSigned(int value) {
    return value > 0 ? '+$value' : '$value';
  }

  ({
    Alignment alignment,
    Offset beginOffset,
    double widthFactor,
    double heightFactor,
    int quarterTurns,
  })
  _calculatorPlacementFor(int player) {
    if (player == 1) {
      return (
        alignment: Alignment.bottomCenter,
        beginOffset: const Offset(0, 1),
        widthFactor: 0.96,
        heightFactor: 0.54,
        quarterTurns: 0,
      );
    }

    return (
      alignment: Alignment.topCenter,
      beginOffset: const Offset(0, -1),
      widthFactor: 0.96,
      heightFactor: 0.54,
      quarterTurns: 2,
    );
  }

  void _cancelPendingTimer(int player) {
    if (player == 1) {
      _playerOnePendingTimer?.cancel();
      _playerOnePendingTimer = null;
      return;
    }
    _playerTwoPendingTimer?.cancel();
    _playerTwoPendingTimer = null;
  }

  void _startPendingTimer(int player) {
    _cancelPendingTimer(player);

    final Timer timer = Timer(_aggregationWindow, () {
      _commitPendingDelta(player);
    });

    if (player == 1) {
      _playerOnePendingTimer = timer;
      return;
    }
    _playerTwoPendingTimer = timer;
  }

  void _commitPendingDelta(int player) {
    if (!mounted) {
      return;
    }

    final int pending = player == 1
        ? _playerOnePendingDelta
        : _playerTwoPendingDelta;
    if (pending == 0) {
      return;
    }

    final int currentLp = player == 1 ? _playerOneLp : _playerTwoLp;
    setState(() {
      _twoPlayerLifeEvents.add(
        TwoPlayerLifeEvent(
          player: player,
          delta: pending,
          resultingLife: currentLp,
        ),
      );
      if (player == 1) {
        _playerOnePendingDelta = 0;
      } else {
        _playerTwoPendingDelta = 0;
      }
    });
  }

  void _applySignedDelta({required int player, required int delta}) {
    final int currentLp = player == 1 ? _playerOneLp : _playerTwoLp;
    final int nextLp = max(0, currentLp + delta);
    final int effectiveDelta = nextLp - currentLp;

    if (effectiveDelta == 0) {
      return;
    }

    setState(() {
      if (player == 1) {
        _playerOneLp = nextLp;
        _playerOnePendingDelta += effectiveDelta;
      } else {
        _playerTwoLp = nextLp;
        _playerTwoPendingDelta += effectiveDelta;
      }
    });

    _startPendingTimer(player);
  }

  void _changeLp({
    required int player,
    required int amount,
    required bool addMode,
  }) {
    final bool add = addMode;
    final int signedDelta = add ? amount : -amount;
    _applySignedDelta(player: player, delta: signedDelta);
  }

  void _applyScaleAction({required int player, required bool addMode}) {
    final bool add = addMode;
    final int currentLp = player == 1 ? _playerOneLp : _playerTwoLp;
    final int nextLp = add ? currentLp * 2 : currentLp ~/ 2;
    final int signedDelta = nextLp - currentLp;
    _applySignedDelta(player: player, delta: signedDelta);
  }

  Map<_MtgResourceCounter, int> _resourceCountersForPlayer(int player) {
    return player == 1
        ? _playerOneResourceCounters
        : _playerTwoResourceCounters;
  }

  Map<_MtgStatusCounter, int> _statusCountersForPlayer(int player) {
    return player == 1 ? _playerOneStatusCounters : _playerTwoStatusCounters;
  }

  int _poisonCountersForPlayer(int player) {
    return _statusCountersForPlayer(player)[_MtgStatusCounter.poison] ?? 0;
  }

  int _experienceCountersForPlayer(int player) {
    return _statusCountersForPlayer(player)[_MtgStatusCounter.experience] ?? 0;
  }

  void _changeMtgResourceCounter({
    required int player,
    required _MtgResourceCounter counter,
    required int delta,
  }) {
    final Map<_MtgResourceCounter, int> counters = _resourceCountersForPlayer(
      player,
    );
    final int current = counters[counter] ?? 0;
    final int next = max(0, current + delta);
    if (next == current) {
      return;
    }
    setState(() {
      counters[counter] = next;
    });
  }

  void _changeMtgStatusCounter({
    required int player,
    required _MtgStatusCounter counter,
    required int delta,
  }) {
    final Map<_MtgStatusCounter, int> counters = _statusCountersForPlayer(
      player,
    );
    final int current = counters[counter] ?? 0;
    final int next = max(0, current + delta);
    if (next == current) {
      return;
    }
    setState(() {
      counters[counter] = next;
    });
  }

  Future<void> _openMtgCountersPanel({
    required int player,
    required String title,
    required Widget Function(StateSetter setModalState) contentBuilder,
  }) async {
    final placement = _calculatorPlacementFor(player);

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close counters',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (BuildContext context, _, _) {
        return SafeArea(
          child: RotatedBox(
            quarterTurns: placement.quarterTurns,
            child: Material(
              color: const Color(0xFF141414),
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setModalState) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close_rounded),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.08,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(child: contentBuilder(setModalState)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
      transitionBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> _,
            Widget child,
          ) {
            final Animation<Offset> offsetAnimation =
                Tween<Offset>(
                  begin: placement.beginOffset,
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                );

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: offsetAnimation, child: child),
            );
          },
    );
  }

  Widget _buildMtgCounterRow({
    required Widget label,
    required int value,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
    bool compact = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: compact ? 6 : 8),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Expanded(child: label),
          IconButton(
            onPressed: onDecrement,
            icon: const Icon(Icons.remove_rounded),
            style: IconButton.styleFrom(
              minimumSize: Size.square(compact ? 30 : 32),
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 32,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: compact ? 15 : 16,
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: onIncrement,
            icon: const Icon(Icons.add_rounded),
            style: IconButton.styleFrom(
              minimumSize: Size.square(compact ? 30 : 32),
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMtgResourceCountersForPlayer(int player) async {
    if (!_isMtgRules) {
      return;
    }

    await _openMtgCountersPanel(
      player: player,
      title: '${_playerName(player)} - Mana & Storm',
      contentBuilder: (StateSetter setModalState) {
        final Map<_MtgResourceCounter, int> counters =
            _resourceCountersForPlayer(player);
        return Column(
          children: [
            for (final _MtgResourceCounter counter
                in _MtgResourceCounter.values)
              Expanded(
                child: _buildMtgCounterRow(
                  compact: true,
                  label: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: counter.accentColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          counter.label,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  value: counters[counter] ?? 0,
                  onDecrement: () {
                    _changeMtgResourceCounter(
                      player: player,
                      counter: counter,
                      delta: -1,
                    );
                    setModalState(() {});
                  },
                  onIncrement: () {
                    _changeMtgResourceCounter(
                      player: player,
                      counter: counter,
                      delta: 1,
                    );
                    setModalState(() {});
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _openMtgStatusCountersForPlayer(int player) async {
    if (!_isMtgRules) {
      return;
    }

    await _openMtgCountersPanel(
      player: player,
      title: '${_playerName(player)} - Poison & Experience',
      contentBuilder: (StateSetter setModalState) {
        final Map<_MtgStatusCounter, int> counters = _statusCountersForPlayer(
          player,
        );
        return Column(
          children: [
            for (final _MtgStatusCounter counter in _MtgStatusCounter.values)
              _buildMtgCounterRow(
                label: Row(
                  children: [
                    if (counter == _MtgStatusCounter.poison) ...[
                      Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1D5F2A),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          '\u03A6',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        counter.label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                value: counters[counter] ?? 0,
                onDecrement: () {
                  _changeMtgStatusCounter(
                    player: player,
                    counter: counter,
                    delta: -1,
                  );
                  setModalState(() {});
                },
                onIncrement: () {
                  _changeMtgStatusCounter(
                    player: player,
                    counter: counter,
                    delta: 1,
                  );
                  setModalState(() {});
                },
              ),
            const Spacer(),
          ],
        );
      },
    );
  }

  Future<void> _openHistoryForPlayer(int player) async {
    final List<String> historySnapshot = _historySnapshotWithPending();
    final placement = _calculatorPlacementFor(player);

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close history',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (BuildContext context, _, _) {
        return SafeArea(
          child: RotatedBox(
            quarterTurns: placement.quarterTurns,
            child: Material(
              color: const Color(0xFF141414),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'LP History',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.08,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF101010),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: _buildLifeHistoryView(
                          lines: historySnapshot,
                          dividerColor: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> _,
            Widget child,
          ) {
            final Animation<Offset> offsetAnimation =
                Tween<Offset>(
                  begin: placement.beginOffset,
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                );

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: offsetAnimation, child: child),
            );
          },
    );
  }

  List<String> _historySnapshotWithPending() {
    final List<TwoPlayerLifeEvent> events = List<TwoPlayerLifeEvent>.from(
      _twoPlayerLifeEvents,
    );
    if (_playerOnePendingDelta != 0) {
      events.add(
        TwoPlayerLifeEvent(
          player: 1,
          delta: _playerOnePendingDelta,
          resultingLife: _playerOneLp,
        ),
      );
    }
    if (_playerTwoPendingDelta != 0) {
      events.add(
        TwoPlayerLifeEvent(
          player: 2,
          delta: _playerTwoPendingDelta,
          resultingLife: _playerTwoLp,
        ),
      );
    }
    return _buildTwoPlayerHistoryTable(
      playerOneName: _playerName(1),
      playerTwoName: _playerName(2),
      initialPlayerOneLife: widget.initialLifePoints,
      initialPlayerTwoLife: widget.initialLifePoints,
      events: events,
    );
  }

  void _closeWithHistory({String matchResult = '', bool shouldSave = true}) {
    _diceRollTimer?.cancel();
    _cancelPendingTimer(1);
    _cancelPendingTimer(2);
    final String trimmedOpponent = _opponentName.trim();
    final String opponentForHistory = trimmedOpponent.isNotEmpty
        ? trimmedOpponent
        : (matchResult.trim().isNotEmpty && _selectedGameStage == 'G1'
              ? _lastCompletedOpponentName.trim()
              : '');
    Navigator.of(context).pop(
      DuelResultPayload(
        lifePointHistory: _historySnapshotWithPending(),
        gameStage: _selectedGameStage,
        opponentName: opponentForHistory,
        deckName: _deckInUse,
        matchResult: matchResult,
        shouldSave: shouldSave,
      ),
    );
  }

  Future<void> _openCalculatorForPlayer(int player) async {
    String customInput = '';
    bool isAddMode = false;
    final placement = _calculatorPlacementFor(player);

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close calculator',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (BuildContext context, _, _) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Align(
              alignment: placement.alignment,
              child: FractionallySizedBox(
                widthFactor: placement.widthFactor,
                heightFactor: placement.heightFactor,
                child: StatefulBuilder(
                  builder: (BuildContext context, StateSetter setModalState) {
                    final String sign = isAddMode ? '+' : '-';

                    void appendDigit(String digit) {
                      setModalState(() {
                        if (customInput.length >= 5) {
                          return;
                        }
                        if (customInput == '0') {
                          customInput = digit;
                          return;
                        }
                        customInput += digit;
                      });
                    }

                    void clearInput() {
                      setModalState(() {
                        customInput = '';
                      });
                    }

                    void applyInput() {
                      final int value = int.tryParse(customInput) ?? 0;
                      if (value == 0) {
                        return;
                      }
                      _changeLp(
                        player: player,
                        amount: value,
                        addMode: isAddMode,
                      );
                      Navigator.of(context).pop();
                    }

                    return RotatedBox(
                      quarterTurns: placement.quarterTurns,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: double.infinity),
                        child: Material(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${_playerName(player)} calculator',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    FilledButton.tonal(
                                      onPressed: () {
                                        setModalState(() {
                                          isAddMode = !isAddMode;
                                        });
                                      },
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            widget.settings.buttonColor,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 8,
                                        ),
                                      ),
                                      child: Text(
                                        '+/- ($sign)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0E0E0E),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.12,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    '$sign ${customInput.isEmpty ? '0' : customInput}',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: LayoutBuilder(
                                    builder:
                                        (
                                          BuildContext context,
                                          BoxConstraints constraints,
                                        ) {
                                          const double spacing = 8;
                                          final double gridWidth = max(
                                            0,
                                            constraints.maxWidth - spacing * 2,
                                          );
                                          final double gridHeight = max(
                                            0,
                                            constraints.maxHeight - spacing * 3,
                                          );
                                          final double tileWidth =
                                              gridWidth / 3;
                                          final double tileHeight = max(
                                            44,
                                            gridHeight / 4,
                                          );
                                          final double aspectRatio =
                                              tileHeight == 0
                                              ? 1
                                              : tileWidth / tileHeight;

                                          return GridView.count(
                                            padding: EdgeInsets.zero,
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            crossAxisCount: 3,
                                            crossAxisSpacing: spacing,
                                            mainAxisSpacing: spacing,
                                            childAspectRatio: aspectRatio,
                                            children: [
                                              for (final String key in [
                                                '1',
                                                '2',
                                                '3',
                                                '4',
                                                '5',
                                                '6',
                                                '7',
                                                '8',
                                                '9',
                                                'C',
                                                '0',
                                                '=',
                                              ])
                                                FilledButton.tonal(
                                                  onPressed: () {
                                                    if (key == 'C') {
                                                      clearInput();
                                                      return;
                                                    }
                                                    if (key == '=') {
                                                      applyInput();
                                                      return;
                                                    }
                                                    appendDigit(key);
                                                  },
                                                  style: FilledButton.styleFrom(
                                                    backgroundColor: key == '='
                                                        ? const Color(
                                                            0xFFB71C1C,
                                                          )
                                                        : widget
                                                              .settings
                                                              .buttonColor,
                                                    foregroundColor: key == '='
                                                        ? Colors.white
                                                        : null,
                                                    padding: EdgeInsets.zero,
                                                  ),
                                                  child: Text(
                                                    key,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          );
                                        },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> _,
            Widget child,
          ) {
            final Animation<Offset> offsetAnimation =
                Tween<Offset>(
                  begin: placement.beginOffset,
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                );

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: offsetAnimation, child: child),
            );
          },
    );
  }

  Future<void> _openMatchDetailsEditor() async {
    final TextEditingController opponentController = TextEditingController(
      text: _opponentName,
    );
    String stage = _selectedGameStage;
    final List<String> deckOptions = _deckOptionsForDetails();
    String selectedDeck = _deckInUse.trim();
    if (selectedDeck.isNotEmpty && !deckOptions.contains(selectedDeck)) {
      selectedDeck = '';
    }

    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Match details'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: opponentController,
                      decoration: const InputDecoration(
                        labelText: 'Opponent name',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: stage,
                      decoration: const InputDecoration(
                        labelText: 'Game',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _supportedGameStages
                          .map((String item) {
                            return DropdownMenuItem<String>(
                              value: item,
                              child: Text(item),
                            );
                          })
                          .toList(growable: false),
                      onChanged: (String? value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() {
                          stage = value;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedDeck,
                      decoration: const InputDecoration(
                        labelText: 'Deck in use',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: <DropdownMenuItem<String>>[
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('No deck'),
                        ),
                        ...deckOptions.map((String deckName) {
                          return DropdownMenuItem<String>(
                            value: deckName,
                            child: Text(deckName),
                          );
                        }),
                      ],
                      onChanged: (String? value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() {
                          selectedDeck = value;
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (shouldSave != true) {
      opponentController.dispose();
      return;
    }

    setState(() {
      _opponentName = opponentController.text.trim();
      if (_opponentName.isNotEmpty) {
        _lastCompletedOpponentName = _opponentName;
      }
      _deckInUse = selectedDeck.trim();
      _selectedGameStage = stage;
      if (stage == 'G1') {
        _bo3Wins = 0;
        _bo3Losses = 0;
      }
    });
    opponentController.dispose();
  }

  Future<void> _confirmReset({bool fromHome = false}) async {
    const Color resetColor = Color(0xFF232323);
    const Color winColor = Color(0xFF163825);
    const Color lossColor = Color(0xFF4A1E1E);
    const Color drawColor = Color(0xFF4D4220);
    final bool canOpenSideboardGuide = _selectedDeckForGuide() != null;

    final String? action = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('End or reset match'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.tonal(
                onPressed: canOpenSideboardGuide
                    ? () => Navigator.of(context).pop('sideboard')
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: widget.settings.buttonColor,
                ),
                child: const Text('Sideboard Guide'),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () => Navigator.of(context).pop('reset'),
                style: FilledButton.styleFrom(backgroundColor: resetColor),
                child: const Text('Reset without saving'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.of(context).pop('Win'),
                style: FilledButton.styleFrom(backgroundColor: winColor),
                child: const Text('Win'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.of(context).pop('Loss'),
                style: FilledButton.styleFrom(backgroundColor: lossColor),
                child: const Text('Loss'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.of(context).pop('Draw'),
                style: FilledButton.styleFrom(backgroundColor: drawColor),
                child: const Text('Draw'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (action == null || !mounted) {
      return;
    }
    if (action == 'sideboard') {
      await _openSideboardGuideDialog();
      return;
    }
    if (action == 'Win' || action == 'Loss' || action == 'Draw') {
      if (fromHome) {
        _closeWithHistory(matchResult: action);
        return;
      }

      _diceRollTimer?.cancel();
      _diceRollTimer = null;
      _cancelPendingTimer(1);
      _cancelPendingTimer(2);

      setState(() {
        _advanceBo3AfterRestart(declaredResult: action);
        _playerOneLp = widget.initialLifePoints;
        _playerTwoLp = widget.initialLifePoints;
        _playerOneDie = null;
        _playerTwoDie = null;
        _isRollingDice = false;
        _diceRollTicks = 0;
        _playerOnePendingDelta = 0;
        _playerTwoPendingDelta = 0;
        for (final _MtgResourceCounter counter in _MtgResourceCounter.values) {
          _playerOneResourceCounters[counter] = 0;
          _playerTwoResourceCounters[counter] = 0;
        }
        for (final _MtgStatusCounter counter in _MtgStatusCounter.values) {
          _playerOneStatusCounters[counter] = 0;
          _playerTwoStatusCounters[counter] = 0;
        }
        _twoPlayerLifeEvents.clear();
      });
      return;
    }
    if (action != 'reset') {
      return;
    }
    if (fromHome) {
      _closeWithHistory(shouldSave: false);
      return;
    }

    _diceRollTimer?.cancel();
    _diceRollTimer = null;
    _cancelPendingTimer(1);
    _cancelPendingTimer(2);

    setState(() {
      _advanceBo3AfterRestart();
      _playerOneLp = widget.initialLifePoints;
      _playerTwoLp = widget.initialLifePoints;
      _playerOneDie = null;
      _playerTwoDie = null;
      _isRollingDice = false;
      _diceRollTicks = 0;
      _playerOnePendingDelta = 0;
      _playerTwoPendingDelta = 0;
      for (final _MtgResourceCounter counter in _MtgResourceCounter.values) {
        _playerOneResourceCounters[counter] = 0;
        _playerTwoResourceCounters[counter] = 0;
      }
      for (final _MtgStatusCounter counter in _MtgStatusCounter.values) {
        _playerOneStatusCounters[counter] = 0;
        _playerTwoStatusCounters[counter] = 0;
      }
      _twoPlayerLifeEvents.clear();
    });
  }

  void _rollDice() {
    if (_isRollingDice) {
      return;
    }

    const int totalTicks = 12;
    const Duration tickDuration = Duration(milliseconds: 85);

    _diceRollTimer?.cancel();
    setState(() {
      _isRollingDice = true;
      _diceRollTicks = 0;
      _playerOneDie = _random.nextInt(6) + 1;
      _playerTwoDie = _random.nextInt(6) + 1;
    });

    _diceRollTimer = Timer.periodic(tickDuration, (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _playerOneDie = _random.nextInt(6) + 1;
        _playerTwoDie = _random.nextInt(6) + 1;
        _diceRollTicks += 1;

        if (_diceRollTicks >= totalTicks) {
          _isRollingDice = false;
          timer.cancel();
          _diceRollTimer = null;
        }
      });
    });
  }

  List<Alignment> _diePipAlignments(int value) {
    switch (value) {
      case 1:
        return const [Alignment.center];
      case 2:
        return const [Alignment.topLeft, Alignment.bottomRight];
      case 3:
        return const [
          Alignment.topLeft,
          Alignment.center,
          Alignment.bottomRight,
        ];
      case 4:
        return const [
          Alignment.topLeft,
          Alignment.topRight,
          Alignment.bottomLeft,
          Alignment.bottomRight,
        ];
      case 5:
        return const [
          Alignment.topLeft,
          Alignment.topRight,
          Alignment.center,
          Alignment.bottomLeft,
          Alignment.bottomRight,
        ];
      default:
        return const [
          Alignment.topLeft,
          Alignment.centerLeft,
          Alignment.bottomLeft,
          Alignment.topRight,
          Alignment.centerRight,
          Alignment.bottomRight,
        ];
    }
  }

  Widget _buildDieFace(
    int value, {
    required bool compact,
    required bool isRolling,
  }) {
    final double size = compact ? 24 : 30;
    final double pipSize = compact ? 3.3 : 4.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isRolling ? const Color(0xFFFFE9B3) : const Color(0xFFEEEDED),
        borderRadius: BorderRadius.circular(compact ? 6 : 8),
        border: Border.all(
          color: isRolling ? const Color(0xFFE7C061) : const Color(0xFFB0AFAF),
          width: isRolling ? 1.6 : 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 3 : 4),
        child: Stack(
          children: [
            for (final Alignment align in _diePipAlignments(value))
              Align(
                alignment: align,
                child: Container(
                  width: pipSize,
                  height: pipSize,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A1A1A),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingDeltaBadge({required int player, required bool compact}) {
    final int value = player == 1
        ? _playerOnePendingDelta
        : _playerTwoPendingDelta;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 140),
      transitionBuilder: (Widget child, Animation<double> animation) {
        final Animation<Offset> offset = Tween<Offset>(
          begin: const Offset(0, -0.2),
          end: Offset.zero,
        ).animate(animation);

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: value == 0
          ? const SizedBox.shrink(key: ValueKey<String>('empty-delta'))
          : Container(
              key: ValueKey<int>(value),
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 6 : 8,
                vertical: compact ? 2 : 3,
              ),
              decoration: BoxDecoration(
                color: value > 0
                    ? const Color(0xFF245D32)
                    : const Color(0xFF6A2323),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _formatSigned(value),
                style: TextStyle(
                  fontSize: compact ? 10 : 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
    );
  }

  Widget _buildQuickButton(int player, int delta, {bool compact = false}) {
    final bool isPositive = delta > 0;
    final double compactHeight = _isMtgRules ? 38 : 32;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FilledButton.tonal(
          onPressed: () => _applySignedDelta(player: player, delta: delta),
          style: FilledButton.styleFrom(
            minimumSize: Size.fromHeight(compact ? compactHeight : 46),
            backgroundColor: widget.settings.buttonColor,
          ),
          child: Text(
            '${isPositive ? '+' : ''}$delta',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: compact ? 13 : 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignedQuickButton(
    int player,
    int delta, {
    bool compact = false,
  }) {
    final bool isPositive = delta > 0;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FilledButton.tonal(
          onPressed: () => _applySignedDelta(player: player, delta: delta),
          style: FilledButton.styleFrom(
            minimumSize: Size.fromHeight(compact ? 34 : 40),
            backgroundColor: widget.settings.buttonColor,
          ),
          child: Text(
            '${isPositive ? '+' : ''}$delta',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: compact ? 13 : 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScaleButton(
    int player, {
    required bool addMode,
    bool compact = false,
  }) {
    final String label = addMode ? 'x2' : '1/2';
    final double compactHeight = _isMtgRules ? 38 : 32;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FilledButton.tonal(
          onPressed: () => _applyScaleAction(player: player, addMode: addMode),
          style: FilledButton.styleFrom(
            minimumSize: Size.fromHeight(compact ? compactHeight : 46),
            backgroundColor: widget.settings.buttonColor,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: compact ? 13 : 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInlineLpTapHint({
    required bool isPositive,
    required bool compact,
  }) {
    return Container(
      width: compact ? 28 : 32,
      height: compact ? 28 : 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: widget.settings.buttonColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        isPositive ? '+' : '-',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: compact ? 16 : 18,
        ),
      ),
    );
  }

  Widget _playerPanel({
    required int player,
    required int lifePoints,
    bool compact = false,
  }) {
    final bool isYugiohRules = !_isMtgRules;
    final bool isYugiohCompact = isYugiohRules && compact;
    final int? dieValue = player == 1 ? _playerOneDie : _playerTwoDie;
    final int poisonCounters = _isMtgRules
        ? _poisonCountersForPlayer(player)
        : 0;
    final int experienceCounters = _isMtgRules
        ? _experienceCountersForPlayer(player)
        : 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: EdgeInsets.fromLTRB(
        compact ? 8 : 10,
        isYugiohRules ? (compact ? 4 : 8) : 10,
        compact ? 8 : 10,
        isYugiohCompact ? 4 : (compact ? 6 : 10),
      ),
      padding: EdgeInsets.fromLTRB(
        compact ? 10 : 14,
        isYugiohRules ? (compact ? 6 : 10) : (compact ? 10 : 14),
        compact ? 10 : 14,
        isYugiohCompact ? 6 : (compact ? 8 : 12),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF221818),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _playerName(player).toUpperCase(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.86),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      fontSize: compact ? 12 : 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Open history',
                    onPressed: () => _openHistoryForPlayer(player),
                    icon: Icon(
                      Icons.format_list_bulleted_rounded,
                      size: compact ? 16 : 18,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: widget.settings.buttonColor,
                      foregroundColor: Colors.white,
                      minimumSize: Size.square(compact ? 28 : 30),
                    ),
                  ),
                  if (_isMtgRules) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Open mana and storm counters',
                      onPressed: () =>
                          _openMtgResourceCountersForPlayer(player),
                      icon: Icon(
                        Icons.blur_circular_rounded,
                        size: compact ? 16 : 18,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: widget.settings.buttonColor,
                        foregroundColor: Colors.white,
                        minimumSize: Size.square(compact ? 28 : 30),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Open poison and experience counters',
                      onPressed: () => _openMtgStatusCountersForPlayer(player),
                      icon: Text(
                        '\u03A6',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: compact ? 13 : 15,
                        ),
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: widget.settings.buttonColor,
                        foregroundColor: Colors.white,
                        minimumSize: Size.square(compact ? 28 : 30),
                      ),
                    ),
                  ],
                ],
              ),
              const Spacer(),
              if (dieValue != null) ...[
                _buildDieFace(
                  dieValue,
                  compact: compact,
                  isRolling: _isRollingDice,
                ),
                const SizedBox(width: 6),
              ],
              IconButton(
                tooltip: 'Open calculator',
                onPressed: () => _openCalculatorForPlayer(player),
                icon: Icon(Icons.calculate_outlined, size: compact ? 18 : 20),
                style: IconButton.styleFrom(
                  backgroundColor: widget.settings.buttonColor,
                  foregroundColor: Colors.white,
                  minimumSize: Size.square(compact ? 30 : 34),
                ),
              ),
            ],
          ),
          if (_isMtgRules &&
              (poisonCounters > 0 || experienceCounters > 0)) ...[
            SizedBox(height: compact ? 4 : 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (poisonCounters > 0)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 8 : 10,
                        vertical: compact ? 3 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6A2323),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFFF8A8A)),
                      ),
                      child: Text(
                        'Poison counter: $poisonCounters',
                        style: TextStyle(
                          color: const Color(0xFFFFA3A3),
                          fontWeight: FontWeight.w700,
                          fontSize: compact ? 11 : 12,
                        ),
                      ),
                    ),
                  if (experienceCounters > 0)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 8 : 10,
                        vertical: compact ? 3 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF234A6A),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFF7AC7FF)),
                      ),
                      child: Text(
                        'Experience counter: $experienceCounters',
                        style: TextStyle(
                          color: const Color(0xFFBEE8FF),
                          fontWeight: FontWeight.w700,
                          fontSize: compact ? 11 : 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          SizedBox(height: compact ? (isYugiohRules ? 1 : 6) : 10),
          SizedBox(
            height: compact ? (isYugiohRules ? 146 : 96) : 126,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 10 : 12,
                      vertical: compact ? 6 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: widget.settings.lifePointsBackgroundColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: _isMtgRules
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () => _applySignedDelta(
                                              player: player,
                                              delta: -1,
                                            ),
                                            splashColor: Colors.white
                                                .withValues(alpha: 0.08),
                                            highlightColor: Colors.white
                                                .withValues(alpha: 0.03),
                                            child: const SizedBox.expand(),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () => _applySignedDelta(
                                              player: player,
                                              delta: 1,
                                            ),
                                            splashColor: Colors.white
                                                .withValues(alpha: 0.08),
                                            highlightColor: Colors.white
                                                .withValues(alpha: 0.03),
                                            child: const SizedBox.expand(),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Padding(
                                              padding: EdgeInsets.only(
                                                left: compact ? 6 : 8,
                                              ),
                                              child: _buildInlineLpTapHint(
                                                isPositive: false,
                                                compact: compact,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Align(
                                            alignment: Alignment.centerRight,
                                            child: Padding(
                                              padding: EdgeInsets.only(
                                                right: compact ? 6 : 8,
                                              ),
                                              child: _buildInlineLpTapHint(
                                                isPositive: true,
                                                compact: compact,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: Center(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: compact ? 44 : 52,
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            '$lifePoints',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: compact ? 52 : 70,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () => _applySignedDelta(
                                              player: player,
                                              delta: -100,
                                            ),
                                            splashColor: Colors.white
                                                .withValues(alpha: 0.08),
                                            highlightColor: Colors.white
                                                .withValues(alpha: 0.03),
                                            child: const SizedBox.expand(),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () => _applySignedDelta(
                                              player: player,
                                              delta: 100,
                                            ),
                                            splashColor: Colors.white
                                                .withValues(alpha: 0.08),
                                            highlightColor: Colors.white
                                                .withValues(alpha: 0.03),
                                            child: const SizedBox.expand(),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Padding(
                                              padding: EdgeInsets.only(
                                                left: compact ? 8 : 10,
                                              ),
                                              child: Text(
                                                '-100',
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.72),
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: compact ? 10 : 11,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Align(
                                            alignment: Alignment.centerRight,
                                            child: Padding(
                                              padding: EdgeInsets.only(
                                                right: compact ? 8 : 10,
                                              ),
                                              child: Text(
                                                '+100',
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.72),
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: compact ? 10 : 11,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: Center(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: compact ? 42 : 50,
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            '$lifePoints',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 320,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: compact ? 2 : 4,
                  child: _buildPendingDeltaBadge(
                    player: player,
                    compact: compact,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: compact ? (isYugiohRules ? 2 : 6) : 10),
          if (_isMtgRules) ...[
            Row(
              children: [
                _buildSignedQuickButton(player, -10, compact: compact),
                _buildSignedQuickButton(player, 10, compact: compact),
              ],
            ),
          ] else ...[
            Row(
              children: [
                _buildQuickButton(player, -1000, compact: compact),
                _buildQuickButton(player, -100, compact: compact),
                _buildScaleButton(player, addMode: false, compact: compact),
              ],
            ),
            SizedBox(height: isYugiohCompact ? 3 : (compact ? 6 : 8)),
            Row(
              children: [
                _buildQuickButton(player, 1000, compact: compact),
                _buildQuickButton(player, 100, compact: compact),
                _buildScaleButton(player, addMode: true, compact: compact),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _centerControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Card(
        color: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              const double spacing = 8;
              const int buttonsCount = 4;
              final double buttonWidth =
                  ((constraints.maxWidth - spacing * (buttonsCount - 1)) /
                          buttonsCount)
                      .clamp(48.0, 70.0);
              final double controlsWidth =
                  buttonWidth * buttonsCount + spacing * (buttonsCount - 1);

              Widget controlButton({
                required VoidCallback? onPressed,
                required Widget child,
                Color? backgroundColor,
              }) {
                return SizedBox(
                  width: buttonWidth,
                  child: FilledButton.tonal(
                    onPressed: onPressed,
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          backgroundColor ?? widget.settings.buttonColor,
                      minimumSize: const Size.fromHeight(46),
                      padding: EdgeInsets.zero,
                    ),
                    child: Center(child: child),
                  ),
                );
              }

              return Center(
                child: SizedBox(
                  width: controlsWidth,
                  child: Row(
                    children: [
                      controlButton(
                        onPressed: () => _confirmReset(fromHome: true),
                        child: const Icon(Icons.home_outlined, size: 30),
                      ),
                      const SizedBox(width: spacing),
                      controlButton(
                        onPressed: _confirmReset,
                        child: const Icon(Icons.restart_alt, size: 30),
                      ),
                      const SizedBox(width: spacing),
                      controlButton(
                        onPressed: _openMatchDetailsEditor,
                        child: const Icon(Icons.edit_outlined, size: 30),
                      ),
                      const SizedBox(width: spacing),
                      controlButton(
                        onPressed: _isRollingDice ? null : _rollDice,
                        child: const Icon(Icons.casino_outlined, size: 30),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _splitLayout() {
    final bool forceCompact = !_isMtgRules;
    return Column(
      children: [
        Expanded(
          child: RotatedBox(
            quarterTurns: 2,
            child: _playerPanel(
              player: 2,
              lifePoints: _playerTwoLp,
              compact: forceCompact,
            ),
          ),
        ),
        _centerControls(),
        Expanded(
          child: _playerPanel(
            player: 1,
            lifePoints: _playerOneLp,
            compact: forceCompact,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color duelMiddle =
        Color.lerp(
          widget.settings.backgroundStartColor,
          widget.settings.backgroundEndColor,
          0.45,
        ) ??
        widget.settings.backgroundStartColor;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        _closeWithHistory();
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                widget.settings.backgroundStartColor,
                duelMiddle,
                widget.settings.backgroundEndColor,
              ],
            ),
          ),
          child: SafeArea(child: _splitLayout()),
        ),
      ),
    );
  }

  @override
  void dispose() {
    unawaited(WakelockPlus.disable());
    _diceRollTimer?.cancel();
    _playerOnePendingTimer?.cancel();
    _playerTwoPendingTimer?.cancel();
    super.dispose();
  }
}

class GameHistoryScreen extends StatefulWidget {
  const GameHistoryScreen({
    super.key,
    required this.records,
    required this.decks,
    required this.tcg,
  });

  final List<GameRecord> records;
  final List<SideboardDeck> decks;
  final SupportedTcg tcg;

  @override
  State<GameHistoryScreen> createState() => _GameHistoryScreenState();
}

class _GameHistoryScreenState extends State<GameHistoryScreen> {
  late List<GameRecord> _records;

  @override
  void initState() {
    super.initState();
    _records = List<GameRecord>.from(widget.records);
    _records.sort((GameRecord a, GameRecord b) {
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  void _closeWithResult() {
    Navigator.of(context).pop(_records);
  }

  Future<String?> _promptText({
    required String title,
    required String initialValue,
    required String hintText,
    int maxLines = 1,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return _TextPromptDialog(
          title: title,
          initialValue: initialValue,
          hintText: hintText,
          maxLines: maxLines,
        );
      },
    );
  }

  void _updateRecord(GameRecord updatedRecord) {
    final int index = _records.indexWhere(
      (GameRecord record) => record.id == updatedRecord.id,
    );
    if (index < 0) {
      return;
    }
    setState(() {
      _records[index] = updatedRecord;
    });
  }

  SideboardDeck? _deckById(String deckId) {
    if (deckId.isEmpty) {
      return null;
    }
    for (final SideboardDeck deck in widget.decks) {
      if (deck.id == deckId) {
        return deck;
      }
    }
    return null;
  }

  String _resolvedDeckName(GameRecord record) {
    final SideboardDeck? linkedDeck = _deckById(record.deckId);
    if (linkedDeck != null) {
      return linkedDeck.name;
    }
    return record.deckName.trim();
  }

  String _resolvedDeckId(GameRecord record) {
    final String currentId = record.deckId.trim();
    if (currentId.isNotEmpty && _deckById(currentId) != null) {
      return currentId;
    }
    final String normalizedDeckName = record.deckName.trim().toLowerCase();
    if (normalizedDeckName.isEmpty) {
      return '';
    }
    for (final SideboardDeck deck in widget.decks) {
      if (deck.name.trim().toLowerCase() == normalizedDeckName) {
        return deck.id;
      }
    }
    return '';
  }

  String _selectedMatchResult(GameRecord record) {
    return _supportedMatchResults.contains(record.matchResult)
        ? record.matchResult
        : '';
  }

  Color _matchResultBackgroundColor(String result) {
    if (result == 'Win') {
      return const Color(0xFF245D32);
    }
    if (result == 'Loss') {
      return const Color(0xFF6A2323);
    }
    if (result == 'Draw') {
      return const Color(0xFF665825);
    }
    return const Color(0xFF2B2424);
  }

  Color _matchResultTextColor(String result) {
    if (result == 'Win') {
      return const Color(0xFFB8FFCC);
    }
    if (result == 'Loss') {
      return const Color(0xFFFFC4C4);
    }
    if (result == 'Draw') {
      return const Color(0xFFFFEEAA);
    }
    return Colors.white.withValues(alpha: 0.86);
  }

  Future<void> _editMatchDetails(GameRecord record) async {
    final TextEditingController opponentController = TextEditingController(
      text: record.opponentName,
    );
    String selectedDeckId = _resolvedDeckId(record);
    String stage = _supportedGameStages.contains(record.gameStage)
        ? record.gameStage
        : 'G1';
    String result = _selectedMatchResult(record);

    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Match details'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: opponentController,
                      decoration: const InputDecoration(
                        labelText: 'Opponent',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedDeckId,
                      decoration: const InputDecoration(
                        labelText: 'Deck',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: <DropdownMenuItem<String>>[
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('No deck'),
                        ),
                        ...widget.decks.map((SideboardDeck deck) {
                          return DropdownMenuItem<String>(
                            value: deck.id,
                            child: Text(
                              deck.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                      onChanged: (String? nextValue) {
                        setDialogState(() {
                          selectedDeckId = (nextValue ?? '').trim();
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: stage,
                      decoration: const InputDecoration(
                        labelText: 'Game',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _supportedGameStages
                          .map((String item) {
                            return DropdownMenuItem<String>(
                              value: item,
                              child: Text(item),
                            );
                          })
                          .toList(growable: false),
                      onChanged: (String? nextValue) {
                        if (nextValue == null) {
                          return;
                        }
                        setDialogState(() {
                          stage = nextValue;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: result.isEmpty ? null : result,
                      decoration: const InputDecoration(
                        labelText: 'Result',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: <DropdownMenuItem<String>>[
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('No result'),
                        ),
                        ..._supportedMatchResults.map((String item) {
                          return DropdownMenuItem<String>(
                            value: item,
                            child: Text(item),
                          );
                        }),
                      ],
                      onChanged: (String? nextValue) {
                        setDialogState(() {
                          result = (nextValue ?? '').trim();
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (shouldSave != true) {
      opponentController.dispose();
      return;
    }

    final SideboardDeck? selectedDeck = _deckById(selectedDeckId);

    _updateRecord(
      record.copyWith(
        opponentName: opponentController.text.trim(),
        deckId: selectedDeck?.id ?? '',
        deckName: selectedDeck?.name ?? '',
        gameStage: stage,
        matchResult: result,
      ),
    );
    opponentController.dispose();
  }

  String _buildHistoryExportText() {
    final List<Map<String, Object>> serializedRecords = _records
        .map((GameRecord record) {
          return record
              .copyWith(
                tcgKey: widget.tcg.storageKey,
                deckName: _resolvedDeckName(record),
              )
              .toJson();
        })
        .toList(growable: false);

    final Map<String, Object> payload = <String, Object>{
      'schema': _historyExportSchema,
      'exportedAt': DateTime.now().toIso8601String(),
      'tcg': widget.tcg.storageKey,
      'records': serializedRecords,
    };

    return '$_historyExportSchema\n'
        '${const JsonEncoder.withIndent('  ').convert(payload)}';
  }

  List<GameRecord> _parseHistoryImportText(String rawText) {
    String payloadText = rawText.trim();
    if (payloadText.isEmpty) {
      throw const FormatException('Empty input');
    }

    if (payloadText.startsWith(_historyExportSchema)) {
      payloadText = payloadText.substring(_historyExportSchema.length).trim();
    }

    final dynamic decoded = jsonDecode(payloadText);
    if (decoded is! Map) {
      throw const FormatException('Invalid history payload');
    }
    final Map<String, dynamic> payload = Map<String, dynamic>.from(decoded);
    final Object? rawRecords = payload['records'];
    if (rawRecords is! List) {
      throw const FormatException('Missing records list');
    }

    final List<GameRecord> imported = <GameRecord>[];
    for (final Object? entry in rawRecords) {
      if (entry is! Map) {
        continue;
      }
      final GameRecord parsed = GameRecord.fromJson(
        Map<String, dynamic>.from(entry),
      );
      imported.add(parsed.copyWith(tcgKey: widget.tcg.storageKey));
    }
    imported.sort((GameRecord a, GameRecord b) {
      return b.createdAt.compareTo(a.createdAt);
    });
    return imported;
  }

  Future<void> _exportHistoryTxt() async {
    final String exportText = _buildHistoryExportText();
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Export History (.txt)'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(
                exportText,
                style: const TextStyle(height: 1.35, fontFamily: 'monospace'),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: exportText));
                if (!context.mounted) {
                  return;
                }
                Navigator.of(context).pop();
                if (!mounted) {
                  return;
                }
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'History text copied. Save it as a .txt file.',
                    ),
                  ),
                );
              },
              child: const Text('Copy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _importHistoryTxt() async {
    final TextEditingController textController = TextEditingController();
    final bool? shouldImport = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Import History (.txt)'),
          content: SizedBox(
            width: double.maxFinite,
            child: TextField(
              controller: textController,
              maxLines: 14,
              minLines: 8,
              decoration: const InputDecoration(
                hintText: 'Paste exported .txt content here',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Import'),
            ),
          ],
        );
      },
    );

    final String rawInput = textController.text.trim();
    textController.dispose();
    if (shouldImport != true || rawInput.isEmpty) {
      return;
    }

    try {
      final List<GameRecord> imported = _parseHistoryImportText(rawInput);
      if (imported.isEmpty) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid duel records found.')),
        );
        return;
      }

      setState(() {
        final Map<String, GameRecord> mergedById = <String, GameRecord>{
          for (final GameRecord record in _records) record.id: record,
        };
        for (final GameRecord record in imported) {
          mergedById[record.id] = record;
        }
        _records = mergedById.values.toList(growable: false);
        _records.sort((GameRecord a, GameRecord b) {
          return b.createdAt.compareTo(a.createdAt);
        });
      });

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${imported.length} duel(s) imported.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Import failed. Invalid .txt history format.'),
        ),
      );
    }
  }

  Future<void> _renameRecord(GameRecord record) async {
    final String? result = await _promptText(
      title: 'Rename duel',
      initialValue: record.title,
      hintText: 'Duel name',
    );
    if (result == null) {
      return;
    }

    final String trimmed = result.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _updateRecord(record.copyWith(title: trimmed));
  }

  Future<void> _editNotes(GameRecord record) async {
    final String? result = await _promptText(
      title: 'Edit notes',
      initialValue: record.notes,
      hintText: 'Write some notes...',
      maxLines: 6,
    );
    if (result == null) {
      return;
    }
    _updateRecord(record.copyWith(notes: result.trim()));
  }

  Future<void> _deleteRecord(GameRecord record) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete duel'),
          content: Text('Delete "${record.title}" from history?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (shouldDelete != true) {
      return;
    }

    setState(() {
      _records.removeWhere((GameRecord item) => item.id == record.id);
    });
  }

  void _createManualRecord() {
    final DateTime now = DateTime.now();
    final GameRecord newRecord = GameRecord(
      id: now.microsecondsSinceEpoch.toString(),
      title: 'Duel ${_records.length + 1}',
      createdAt: now,
      gameStage: 'G1',
      notes: '',
      lifePointHistory: const <String>[],
      tcgKey: widget.tcg.storageKey,
      deckId: '',
      playerOneName: 'Player 1',
      playerTwoName: 'Player 2',
    );

    setState(() {
      _records.insert(0, newRecord);
    });
  }

  Future<void> _showLifePointHistory(GameRecord record) async {
    final bool hasHistory = record.lifePointHistory.isNotEmpty;

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${record.title} - LP History'),
          content: SizedBox(
            width: double.maxFinite,
            child: hasHistory
                ? _buildLifeHistoryView(
                    lines: record.lifePointHistory,
                    dividerColor: Colors.white.withValues(alpha: 0.14),
                  )
                : const Text('No life point history saved for this duel yet.'),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        _closeWithResult();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Game History'),
          leading: IconButton(
            onPressed: _closeWithResult,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          actions: [
            IconButton(
              tooltip: 'Import .txt',
              onPressed: _importHistoryTxt,
              icon: const Icon(Icons.upload_file_rounded),
            ),
            IconButton(
              tooltip: 'Export .txt',
              onPressed: _exportHistoryTxt,
              icon: const Icon(Icons.download_rounded),
            ),
            IconButton(
              tooltip: 'Add duel',
              onPressed: _createManualRecord,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        body: _records.isEmpty
            ? Center(
                child: Text(
                  'No duels tracked yet.\nStart a duel or create one manually.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.74)),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                itemCount: _records.length,
                itemBuilder: (BuildContext context, int index) {
                  final GameRecord record = _records[index];
                  final String dropdownValue =
                      _supportedGameStages.contains(record.gameStage)
                      ? record.gameStage
                      : 'G1';
                  final String selectedDeckId = _resolvedDeckId(record);
                  final String selectedResult = _selectedMatchResult(record);
                  final String opponentLabel =
                      record.opponentName.trim().isEmpty
                      ? '-'
                      : record.opponentName.trim();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    color: const Color(0xFF1E1B1B),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      record.title,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatDateTime(record.createdAt),
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              DropdownButton<String>(
                                value: dropdownValue,
                                items: _supportedGameStages
                                    .map((String stage) {
                                      return DropdownMenuItem<String>(
                                        value: stage,
                                        child: Text(stage),
                                      );
                                    })
                                    .toList(growable: false),
                                onChanged: (String? nextValue) {
                                  if (nextValue == null) {
                                    return;
                                  }
                                  _updateRecord(
                                    record.copyWith(gameStage: nextValue),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Opponent: $opponentLabel',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.84),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _matchResultBackgroundColor(
                                    selectedResult,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedResult.isEmpty
                                        ? null
                                        : selectedResult,
                                    hint: Text(
                                      'Result',
                                      style: TextStyle(
                                        color: _matchResultTextColor(''),
                                      ),
                                    ),
                                    dropdownColor: const Color(0xFF2B2424),
                                    style: TextStyle(
                                      color: _matchResultTextColor(
                                        selectedResult,
                                      ),
                                      fontWeight: FontWeight.w700,
                                    ),
                                    items: _supportedMatchResults
                                        .map((String result) {
                                          return DropdownMenuItem<String>(
                                            value: result,
                                            child: Text(
                                              result,
                                              style: TextStyle(
                                                color: _matchResultTextColor(
                                                  result,
                                                ),
                                              ),
                                            ),
                                          );
                                        })
                                        .toList(growable: false),
                                    onChanged: (String? nextResult) {
                                      if (nextResult == null) {
                                        return;
                                      }
                                      _updateRecord(
                                        record.copyWith(
                                          matchResult: nextResult,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: selectedDeckId,
                            decoration: const InputDecoration(
                              labelText: 'Deck',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: <DropdownMenuItem<String>>[
                              const DropdownMenuItem<String>(
                                value: '',
                                child: Text('No deck'),
                              ),
                              ...widget.decks.map((SideboardDeck deck) {
                                return DropdownMenuItem<String>(
                                  value: deck.id,
                                  child: Text(
                                    deck.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }),
                            ],
                            onChanged: (String? deckId) {
                              if (deckId == null) {
                                return;
                              }
                              final SideboardDeck? linkedDeck = _deckById(
                                deckId,
                              );
                              _updateRecord(
                                record.copyWith(
                                  deckId: deckId,
                                  deckName: linkedDeck?.name ?? '',
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 6),
                          Text(
                            record.notes.trim().isEmpty
                                ? 'No notes'
                                : record.notes,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: record.notes.trim().isEmpty
                                  ? Colors.white.withValues(alpha: 0.5)
                                  : Colors.white.withValues(alpha: 0.88),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Wrap(
                                  spacing: 2,
                                  runSpacing: 2,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => _renameRecord(record),
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 16,
                                      ),
                                      label: const Text('Rename'),
                                    ),
                                    TextButton.icon(
                                      onPressed: () => _editNotes(record),
                                      icon: const Icon(
                                        Icons.sticky_note_2_outlined,
                                        size: 16,
                                      ),
                                      label: const Text('Notes'),
                                    ),
                                    TextButton.icon(
                                      onPressed: () =>
                                          _editMatchDetails(record),
                                      icon: const Icon(
                                        Icons.edit_note_rounded,
                                        size: 16,
                                      ),
                                      label: const Text('Details'),
                                    ),
                                    TextButton.icon(
                                      onPressed: () =>
                                          _showLifePointHistory(record),
                                      icon: const Icon(
                                        Icons.format_list_bulleted_rounded,
                                        size: 16,
                                      ),
                                      label: const Text('LP History'),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Delete duel',
                                onPressed: () => _deleteRecord(record),
                                icon: const Icon(Icons.delete_outline_rounded),
                                color: const Color(0xFFFF8A8A),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

enum SideboardDeckSortMode { alphabetical, createdAt, favorites, tag }

enum SideboardMatchupSortMode { alphabetical, createdAt }

class SideboardDeckListScreen extends StatefulWidget {
  const SideboardDeckListScreen({
    super.key,
    required this.decks,
    required this.records,
    required this.settings,
    required this.tcg,
  });

  final List<SideboardDeck> decks;
  final List<GameRecord> records;
  final AppSettings settings;
  final SupportedTcg tcg;

  @override
  State<SideboardDeckListScreen> createState() =>
      _SideboardDeckListScreenState();
}

class _SideboardDeckListScreenState extends State<SideboardDeckListScreen> {
  late List<SideboardDeck> _decks;
  late List<GameRecord> _records;
  SideboardDeckSortMode _sortMode = SideboardDeckSortMode.createdAt;

  @override
  void initState() {
    super.initState();
    _decks = List<SideboardDeck>.from(widget.decks);
    _records = List<GameRecord>.from(widget.records);
  }

  void _closeWithResult() {
    Navigator.of(context).pop(
      SideboardBookResult(
        decks: List<SideboardDeck>.from(_decks),
        records: List<GameRecord>.from(_records),
      ),
    );
  }

  List<SideboardDeck> _sortedDecks() {
    final List<SideboardDeck> sorted = List<SideboardDeck>.from(_decks);
    switch (_sortMode) {
      case SideboardDeckSortMode.alphabetical:
        sorted.sort((SideboardDeck a, SideboardDeck b) {
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
      case SideboardDeckSortMode.createdAt:
        sorted.sort((SideboardDeck a, SideboardDeck b) {
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
      case SideboardDeckSortMode.favorites:
        sorted.sort((SideboardDeck a, SideboardDeck b) {
          if (a.isFavorite != b.isFavorite) {
            return a.isFavorite ? -1 : 1;
          }
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
      case SideboardDeckSortMode.tag:
        sorted.sort((SideboardDeck a, SideboardDeck b) {
          final String tagA = a.tag.trim().toLowerCase();
          final String tagB = b.tag.trim().toLowerCase();
          if (tagA.isEmpty != tagB.isEmpty) {
            return tagA.isEmpty ? 1 : -1;
          }
          final int byTag = tagA.compareTo(tagB);
          if (byTag != 0) {
            return byTag;
          }
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
    }
    return sorted;
  }

  List<String> _existingDeckTags() {
    final Set<String> uniqueTags = <String>{};
    for (final SideboardDeck deck in _decks) {
      final String tag = deck.tag.trim();
      if (tag.isEmpty) {
        continue;
      }
      uniqueTags.add(tag);
    }
    final List<String> sorted = uniqueTags.toList(growable: false);
    sorted.sort((String a, String b) {
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
    return sorted;
  }

  Future<({String name, String tag})?> _promptNewDeckData() async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController tagController = TextEditingController();
    final List<String> existingTags = _existingDeckTags();

    final bool? shouldCreate = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('New deck'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              final String selectedTag = tagController.text.trim();
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Deck name',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: tagController,
                      decoration: const InputDecoration(
                        labelText: 'Tag',
                        hintText: 'Modern, Commander, Edison...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    if (existingTags.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Existing tags',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.74),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final String tag in existingTags)
                            ChoiceChip(
                              label: Text(tag),
                              selected:
                                  selectedTag.toLowerCase() ==
                                  tag.toLowerCase(),
                              onSelected: (_) {
                                tagController.text = tag;
                                setDialogState(() {});
                              },
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (shouldCreate != true) {
      return null;
    }

    final String name = nameController.text.trim();
    final String tag = tagController.text.trim();
    if (name.isEmpty) {
      return null;
    }

    return (name: name, tag: tag);
  }

  Future<bool> _confirmAutoMatchupForTag(String tag) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Synchronize matchups'),
          content: Text(
            'Do you want to synchronize this deck with the matchup lists of all decks with the same tag?\n\nTag: $tag',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  String _normalizedMatchupName(String name) {
    return name.trim().toLowerCase();
  }

  List<SideboardMatchup> _deduplicateMatchupsByName(
    List<SideboardMatchup> matchups,
  ) {
    final Set<String> seen = <String>{};
    final List<SideboardMatchup> deduplicated = <SideboardMatchup>[];

    for (final SideboardMatchup matchup in matchups) {
      final String key = _normalizedMatchupName(matchup.name);
      if (key.isEmpty || seen.contains(key)) {
        continue;
      }
      seen.add(key);
      deduplicated.add(matchup);
    }

    return deduplicated;
  }

  List<SideboardDeck> _synchronizeTagMatchupsForNewDeck({
    required List<SideboardDeck> decks,
    required SideboardDeck newDeck,
  }) {
    final String normalizedTag = newDeck.tag.trim().toLowerCase();
    if (normalizedTag.isEmpty) {
      return List<SideboardDeck>.from(decks);
    }

    final List<SideboardDeck> updatedDecks = List<SideboardDeck>.from(decks);
    final int newDeckIndex = updatedDecks.indexWhere(
      (SideboardDeck deck) => deck.id == newDeck.id,
    );
    if (newDeckIndex < 0) {
      return updatedDecks;
    }

    final List<int> sameTagIndexes = <int>[];
    for (int index = 0; index < updatedDecks.length; index += 1) {
      if (updatedDecks[index].tag.trim().toLowerCase() == normalizedTag) {
        sameTagIndexes.add(index);
      }
    }
    if (sameTagIndexes.isEmpty) {
      return updatedDecks;
    }

    final DateTime now = DateTime.now();
    int matchupSeed = 0;

    final String newDeckName = newDeck.name.trim();
    final String newDeckNameKey = _normalizedMatchupName(newDeckName);
    final Map<String, String> inheritedNames = <String, String>{};

    void collectInheritedName(String rawName) {
      final String trimmed = rawName.trim();
      final String key = _normalizedMatchupName(trimmed);
      if (key.isEmpty || inheritedNames.containsKey(key)) {
        return;
      }
      inheritedNames[key] = trimmed;
    }

    for (final int index in sameTagIndexes) {
      final SideboardDeck deck = updatedDecks[index];
      if (deck.id != newDeck.id) {
        collectInheritedName(deck.name);
      }
      for (final SideboardMatchup matchup in deck.matchups) {
        collectInheritedName(matchup.name);
      }
    }
    collectInheritedName(newDeckName);

    final SideboardDeck currentNewDeck = updatedDecks[newDeckIndex];
    final List<SideboardMatchup> newDeckMatchups = _deduplicateMatchupsByName(
      List<SideboardMatchup>.from(currentNewDeck.matchups),
    );
    final Set<String> newDeckExistingKeys = newDeckMatchups
        .map((SideboardMatchup matchup) => _normalizedMatchupName(matchup.name))
        .toSet();

    for (final MapEntry<String, String> entry in inheritedNames.entries) {
      if (newDeckExistingKeys.contains(entry.key)) {
        continue;
      }
      matchupSeed += 1;
      newDeckMatchups.add(
        SideboardMatchup(
          id: '${now.microsecondsSinceEpoch + matchupSeed}',
          name: entry.value,
          createdAt: now,
          sideIn: const <SideboardCardEntry>[],
          sideOut: const <SideboardCardEntry>[],
        ),
      );
      newDeckExistingKeys.add(entry.key);
    }

    updatedDecks[newDeckIndex] = currentNewDeck.copyWith(
      matchups: _deduplicateMatchupsByName(newDeckMatchups),
    );

    for (final int index in sameTagIndexes) {
      final SideboardDeck deck = updatedDecks[index];
      final List<SideboardMatchup> deduplicatedCurrent =
          _deduplicateMatchupsByName(
            List<SideboardMatchup>.from(deck.matchups),
          );
      final bool alreadyContainsNewDeck = deduplicatedCurrent.any((
        SideboardMatchup matchup,
      ) {
        return _normalizedMatchupName(matchup.name) == newDeckNameKey;
      });
      if (alreadyContainsNewDeck) {
        updatedDecks[index] = deck.copyWith(matchups: deduplicatedCurrent);
        continue;
      }

      matchupSeed += 1;
      updatedDecks[index] = deck.copyWith(
        matchups: _deduplicateMatchupsByName(<SideboardMatchup>[
          SideboardMatchup(
            id: '${now.microsecondsSinceEpoch + matchupSeed}',
            name: newDeckName,
            createdAt: now,
            sideIn: const <SideboardCardEntry>[],
            sideOut: const <SideboardCardEntry>[],
          ),
          ...deduplicatedCurrent,
        ]),
      );
    }

    return updatedDecks;
  }

  Future<void> _addDeck() async {
    final ({String name, String tag})? deckData = await _promptNewDeckData();
    if (deckData == null) {
      return;
    }

    final DateTime now = DateTime.now();
    final SideboardDeck newDeck = SideboardDeck(
      id: now.microsecondsSinceEpoch.toString(),
      name: deckData.name,
      createdAt: now,
      isFavorite: false,
      userNotes: '',
      matchups: const <SideboardMatchup>[],
      tag: deckData.tag,
      tcgKey: widget.tcg.storageKey,
    );

    bool shouldAutoInsert = false;
    if (deckData.tag.trim().isNotEmpty) {
      shouldAutoInsert = await _confirmAutoMatchupForTag(deckData.tag);
    }

    setState(() {
      _decks = List<SideboardDeck>.from(_decks);
      _decks.insert(0, newDeck);
      if (shouldAutoInsert) {
        _decks = List<SideboardDeck>.from(
          _synchronizeTagMatchupsForNewDeck(decks: _decks, newDeck: newDeck),
        );
      }
    });
  }

  void _toggleFavorite(SideboardDeck deck) {
    final int index = _decks.indexWhere(
      (SideboardDeck item) => item.id == deck.id,
    );
    if (index < 0) {
      return;
    }
    setState(() {
      _decks[index] = _decks[index].copyWith(isFavorite: !deck.isFavorite);
    });
  }

  Future<void> _openDeck(SideboardDeck deck) async {
    final SideboardDeckEditResult? result = await Navigator.of(context)
        .push<SideboardDeckEditResult>(
          MaterialPageRoute<SideboardDeckEditResult>(
            builder: (_) => SideboardMatchupListScreen(
              deck: deck,
              records: _records,
              settings: widget.settings,
            ),
          ),
        );
    if (result == null) {
      return;
    }

    final int index = _decks.indexWhere(
      (SideboardDeck item) => item.id == result.deck.id,
    );
    if (index < 0) {
      return;
    }

    setState(() {
      _decks[index] = result.deck;
      _records = result.records;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<SideboardDeck> sortedDecks = _sortedDecks();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        _closeWithResult();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Deck's Utility"),
          leading: IconButton(
            onPressed: _closeWithResult,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          actions: [
            PopupMenuButton<SideboardDeckSortMode>(
              tooltip: 'Sort decks',
              onSelected: (SideboardDeckSortMode mode) {
                setState(() {
                  _sortMode = mode;
                });
              },
              itemBuilder: (BuildContext context) {
                return const <PopupMenuEntry<SideboardDeckSortMode>>[
                  PopupMenuItem<SideboardDeckSortMode>(
                    value: SideboardDeckSortMode.alphabetical,
                    child: Text('Alphabetical'),
                  ),
                  PopupMenuItem<SideboardDeckSortMode>(
                    value: SideboardDeckSortMode.createdAt,
                    child: Text('Creation Date'),
                  ),
                  PopupMenuItem<SideboardDeckSortMode>(
                    value: SideboardDeckSortMode.favorites,
                    child: Text('Favorites'),
                  ),
                  PopupMenuItem<SideboardDeckSortMode>(
                    value: SideboardDeckSortMode.tag,
                    child: Text('Tag'),
                  ),
                ];
              },
              icon: const Icon(Icons.sort_rounded),
            ),
            IconButton(
              tooltip: 'Add deck',
              onPressed: _addDeck,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        body: sortedDecks.isEmpty
            ? Center(
                child: Text(
                  'No decks yet.\nTap + to create your first deck.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.74)),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                itemCount: sortedDecks.length,
                itemBuilder: (BuildContext context, int index) {
                  final SideboardDeck deck = sortedDecks[index];
                  final int matchupCount = deck.matchups.length;
                  final String matchupLabel = matchupCount == 1
                      ? '1 matchup'
                      : '$matchupCount matchups';
                  final String trimmedTag = deck.tag.trim();
                  final String subtitleText = trimmedTag.isEmpty
                      ? matchupLabel
                      : 'Tag: $trimmedTag  •  $matchupLabel';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    color: const Color(0xFF1E1B1B),
                    child: ListTile(
                      onTap: () => _openDeck(deck),
                      title: Text(
                        deck.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          subtitleText,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _toggleFavorite(deck),
                            tooltip: 'Toggle favorite',
                            icon: Icon(
                              deck.isFavorite
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: deck.isFavorite
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.65),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class SideboardMatchupListScreen extends StatefulWidget {
  const SideboardMatchupListScreen({
    super.key,
    required this.deck,
    required this.records,
    required this.settings,
  });

  final SideboardDeck deck;
  final List<GameRecord> records;
  final AppSettings settings;

  @override
  State<SideboardMatchupListScreen> createState() =>
      _SideboardMatchupListScreenState();
}

class _SideboardMatchupListScreenState
    extends State<SideboardMatchupListScreen> {
  late List<SideboardMatchup> _matchups;
  late List<GameRecord> _records;
  late final TextEditingController _userNotesController;
  double _notesHistoryRatio = 0.42;
  double _userNotesFontSize = 14;
  bool _userNotesExpanded = true;
  bool _matchupHistoryExpanded = true;
  SideboardMatchupSortMode _matchupSortMode =
      SideboardMatchupSortMode.createdAt;

  @override
  void initState() {
    super.initState();
    _matchups = List<SideboardMatchup>.from(widget.deck.matchups);
    _records = List<GameRecord>.from(widget.records);
    _userNotesController = TextEditingController(text: widget.deck.userNotes);
  }

  @override
  void dispose() {
    _userNotesController.dispose();
    super.dispose();
  }

  void _closeWithResult() {
    Navigator.of(context).pop(
      SideboardDeckEditResult(
        deck: widget.deck.copyWith(
          matchups: _matchups,
          userNotes: _userNotesController.text.trim(),
        ),
        records: List<GameRecord>.from(_records),
      ),
    );
  }

  Future<String?> _promptText({
    required String title,
    required String hintText,
    String initialValue = '',
    int maxLines = 1,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return _TextPromptDialog(
          title: title,
          initialValue: initialValue,
          hintText: hintText,
          maxLines: maxLines,
        );
      },
    );
  }

  void _updateRecord(GameRecord updatedRecord) {
    final int index = _records.indexWhere(
      (GameRecord record) => record.id == updatedRecord.id,
    );
    if (index < 0) {
      return;
    }
    setState(() {
      _records[index] = updatedRecord;
    });
  }

  Future<void> _editRecordNotes(GameRecord record) async {
    final String? result = await _promptText(
      title: 'Edit duel notes',
      hintText: 'Write some notes...',
      initialValue: record.notes,
      maxLines: 5,
    );
    if (result == null) {
      return;
    }
    _updateRecord(record.copyWith(notes: result.trim()));
  }

  String _selectedMatchResult(GameRecord record) {
    return _supportedMatchResults.contains(record.matchResult)
        ? record.matchResult
        : '';
  }

  Color _matchResultBackgroundColor(String result) {
    if (result == 'Win') {
      return const Color(0xFF245D32);
    }
    if (result == 'Loss') {
      return const Color(0xFF6A2323);
    }
    if (result == 'Draw') {
      return const Color(0xFF665825);
    }
    return const Color(0xFF2B2424);
  }

  Color _matchResultTextColor(String result) {
    if (result == 'Win') {
      return const Color(0xFFB8FFCC);
    }
    if (result == 'Loss') {
      return const Color(0xFFFFC4C4);
    }
    if (result == 'Draw') {
      return const Color(0xFFFFEEAA);
    }
    return Colors.white.withValues(alpha: 0.86);
  }

  Future<void> _playLinkedDuel(GameRecord record) async {
    DuelResultPayload? duelResult;

    if (widget.deck.tcgKey == SupportedTcg.mtg.storageKey) {
      final MtgDuelSetupResult? setupResult = await Navigator.of(context)
          .push<MtgDuelSetupResult>(
            MaterialPageRoute<MtgDuelSetupResult>(
              builder: (_) => MtgDuelSetupScreen(settings: widget.settings),
            ),
          );
      if (setupResult == null || !mounted) {
        return;
      }
      duelResult = await Navigator.of(context).push<DuelResultPayload>(
        MaterialPageRoute<DuelResultPayload>(
          builder: (_) => MtgDuelScreen(
            settings: widget.settings,
            playerCount: setupResult.playerCount,
            initialLifePoints: setupResult.initialLifePoints,
            layoutMode: setupResult.layoutMode,
            availableDeckNames: <String>[widget.deck.name],
            availableDecks: <SideboardDeck>[widget.deck],
            initialDeckName: record.deckName.trim().isEmpty
                ? widget.deck.name
                : record.deckName.trim(),
          ),
        ),
      );
    } else {
      duelResult = await Navigator.of(context).push<DuelResultPayload>(
        MaterialPageRoute<DuelResultPayload>(
          builder: (_) => DuelScreen(
            settings: widget.settings,
            availableDeckNames: <String>[widget.deck.name],
            availableDecks: <SideboardDeck>[widget.deck],
            initialDeckName: record.deckName.trim().isEmpty
                ? widget.deck.name
                : record.deckName.trim(),
          ),
        ),
      );
    }

    if (duelResult == null || !duelResult.shouldSave) {
      return;
    }

    _updateRecord(
      record.copyWith(
        lifePointHistory: List<String>.from(duelResult.lifePointHistory),
        gameStage: duelResult.gameStage.trim().isEmpty
            ? record.gameStage
            : duelResult.gameStage,
        matchResult: duelResult.matchResult.trim().isEmpty
            ? record.matchResult
            : duelResult.matchResult,
        opponentName: duelResult.opponentName.trim().isEmpty
            ? record.opponentName
            : duelResult.opponentName,
        deckName: duelResult.deckName.trim().isEmpty
            ? record.deckName
            : duelResult.deckName,
      ),
    );
  }

  List<GameRecord> _recordsForDeck() {
    final List<GameRecord> linked = _records
        .where((GameRecord record) => record.deckId == widget.deck.id)
        .toList(growable: false);
    linked.sort((GameRecord a, GameRecord b) {
      return b.createdAt.compareTo(a.createdAt);
    });
    return linked;
  }

  Future<void> _addMatchup() async {
    final String? rawName = await _promptText(
      title: 'New matchup',
      hintText: 'Opponent deck name',
    );
    if (rawName == null) {
      return;
    }

    final String name = rawName.trim();
    if (name.isEmpty) {
      return;
    }

    final DateTime now = DateTime.now();
    setState(() {
      _matchups.insert(
        0,
        SideboardMatchup(
          id: now.microsecondsSinceEpoch.toString(),
          name: name,
          createdAt: now,
          sideIn: const <SideboardCardEntry>[],
          sideOut: const <SideboardCardEntry>[],
        ),
      );
    });
  }

  Future<void> _openMatchup(SideboardMatchup matchup) async {
    final SideboardMatchup? updatedMatchup = await Navigator.of(context)
        .push<SideboardMatchup>(
          MaterialPageRoute<SideboardMatchup>(
            builder: (_) => SideboardPlanScreen(matchup: matchup),
          ),
        );
    if (updatedMatchup == null) {
      return;
    }

    final int index = _matchups.indexWhere(
      (SideboardMatchup item) => item.id == matchup.id,
    );
    if (index < 0) {
      return;
    }

    setState(() {
      _matchups[index] = updatedMatchup;
    });
  }

  Widget _buildUserNotesCard() {
    final bool isCollapsed = !_userNotesExpanded;
    return Card(
      color: const Color(0xFF1E1B1B),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'User Notes',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const Spacer(),
                if (!isCollapsed) ...[
                  IconButton(
                    tooltip: 'Smaller text',
                    onPressed: () {
                      setState(() {
                        _userNotesFontSize = (_userNotesFontSize - 1).clamp(
                          11.0,
                          24.0,
                        );
                      });
                    },
                    icon: const Icon(Icons.text_decrease_rounded, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Larger text',
                    onPressed: () {
                      setState(() {
                        _userNotesFontSize = (_userNotesFontSize + 1).clamp(
                          11.0,
                          24.0,
                        );
                      });
                    },
                    icon: const Icon(Icons.text_increase_rounded, size: 20),
                  ),
                ],
                IconButton(
                  tooltip: isCollapsed ? 'Expand section' : 'Collapse section',
                  onPressed: () {
                    setState(() {
                      if (isCollapsed) {
                        _userNotesExpanded = true;
                        _matchupHistoryExpanded = true;
                        _notesHistoryRatio = max(_notesHistoryRatio, 0.5);
                      } else {
                        _userNotesExpanded = false;
                      }
                    });
                  },
                  icon: Icon(
                    isCollapsed
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                    size: 22,
                  ),
                ),
              ],
            ),
            if (!isCollapsed) ...[
              const SizedBox(height: 8),
              Expanded(
                child: TextField(
                  controller: _userNotesController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: TextStyle(fontSize: _userNotesFontSize, height: 1.3),
                  decoration: const InputDecoration(
                    hintText: 'Write notes for this deck...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMatchupHistoryCard() {
    final List<GameRecord> linkedRecords = _recordsForDeck();
    final bool isCollapsed = !_matchupHistoryExpanded;
    return Card(
      color: const Color(0xFF1E1B1B),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Matchup History',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const Spacer(),
                IconButton(
                  tooltip: isCollapsed ? 'Expand section' : 'Collapse section',
                  onPressed: () {
                    setState(() {
                      _matchupHistoryExpanded = !_matchupHistoryExpanded;
                    });
                  },
                  icon: Icon(
                    isCollapsed
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                    size: 22,
                  ),
                ),
              ],
            ),
            if (!isCollapsed) ...[
              const SizedBox(height: 8),
              Expanded(
                child: linkedRecords.isEmpty
                    ? Center(
                        child: Text(
                          'No linked duels yet.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.66),
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: linkedRecords.length,
                        itemBuilder: (BuildContext context, int index) {
                          final GameRecord record = linkedRecords[index];
                          final String stage =
                              _supportedGameStages.contains(record.gameStage)
                              ? record.gameStage
                              : 'G1';
                          final String selectedResult = _selectedMatchResult(
                            record,
                          );
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  record.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formatDateTime(record.createdAt),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.68),
                                  ),
                                ),
                                if (record.notes.trim().isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    record.notes,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white.withValues(
                                        alpha: 0.76,
                                      ),
                                    ),
                                  ),
                                ],
                                Row(
                                  children: [
                                    DropdownButton<String>(
                                      value: stage,
                                      items: _supportedGameStages
                                          .map((String nextStage) {
                                            return DropdownMenuItem<String>(
                                              value: nextStage,
                                              child: Text(nextStage),
                                            );
                                          })
                                          .toList(growable: false),
                                      onChanged: (String? nextStage) {
                                        if (nextStage == null) {
                                          return;
                                        }
                                        _updateRecord(
                                          record.copyWith(gameStage: nextStage),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _matchResultBackgroundColor(
                                          selectedResult,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: selectedResult.isEmpty
                                              ? null
                                              : selectedResult,
                                          hint: Text(
                                            'Result',
                                            style: TextStyle(
                                              color: _matchResultTextColor(''),
                                            ),
                                          ),
                                          dropdownColor: const Color(
                                            0xFF2B2424,
                                          ),
                                          style: TextStyle(
                                            color: _matchResultTextColor(
                                              selectedResult,
                                            ),
                                            fontWeight: FontWeight.w700,
                                          ),
                                          items: _supportedMatchResults
                                              .map((String result) {
                                                return DropdownMenuItem<String>(
                                                  value: result,
                                                  child: Text(
                                                    result,
                                                    style: TextStyle(
                                                      color:
                                                          _matchResultTextColor(
                                                            result,
                                                          ),
                                                    ),
                                                  ),
                                                );
                                              })
                                              .toList(growable: false),
                                          onChanged: (String? nextResult) {
                                            if (nextResult == null) {
                                              return;
                                            }
                                            _updateRecord(
                                              record.copyWith(
                                                matchResult: nextResult,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    FilledButton.tonalIcon(
                                      onPressed: () => _playLinkedDuel(record),
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size(0, 34),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.play_arrow_rounded,
                                        size: 18,
                                      ),
                                      label: const Text('Play'),
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      tooltip: 'Edit notes',
                                      onPressed: () => _editRecordNotes(record),
                                      icon: const Icon(
                                        Icons.sticky_note_2_outlined,
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<SideboardMatchup> _sortedMatchups() {
    final List<SideboardMatchup> sorted = List<SideboardMatchup>.from(
      _matchups,
    );
    switch (_matchupSortMode) {
      case SideboardMatchupSortMode.alphabetical:
        sorted.sort((SideboardMatchup a, SideboardMatchup b) {
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
      case SideboardMatchupSortMode.createdAt:
        sorted.sort((SideboardMatchup a, SideboardMatchup b) {
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final double bottomSectionHeight =
        (MediaQuery.of(context).size.height * 0.42)
            .clamp(220.0, 420.0)
            .toDouble();
    final List<SideboardMatchup> sortedMatchups = _sortedMatchups();
    final Widget matchupList = _matchups.isEmpty
        ? Center(
            child: Text(
              'No matchups yet.\nTap + to add one.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.74)),
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
            itemCount: sortedMatchups.length,
            itemBuilder: (BuildContext context, int index) {
              final SideboardMatchup matchup = sortedMatchups[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                color: const Color(0xFF1E1B1B),
                child: ListTile(
                  onTap: () => _openMatchup(matchup),
                  title: Text(
                    matchup.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Side In: ${matchup.sideIn.length}  •  Side Out: ${matchup.sideOut.length}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              );
            },
          );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        _closeWithResult();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.deck.name),
          leading: IconButton(
            onPressed: _closeWithResult,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          actions: [
            PopupMenuButton<SideboardMatchupSortMode>(
              tooltip: 'Sort sideboards',
              onSelected: (SideboardMatchupSortMode mode) {
                setState(() {
                  _matchupSortMode = mode;
                });
              },
              itemBuilder: (BuildContext context) {
                return const <PopupMenuEntry<SideboardMatchupSortMode>>[
                  PopupMenuItem<SideboardMatchupSortMode>(
                    value: SideboardMatchupSortMode.alphabetical,
                    child: Text('Alphabetical'),
                  ),
                  PopupMenuItem<SideboardMatchupSortMode>(
                    value: SideboardMatchupSortMode.createdAt,
                    child: Text('Creation Date'),
                  ),
                ];
              },
              icon: const Icon(Icons.sort_rounded),
            ),
            IconButton(
              tooltip: 'Add matchup',
              onPressed: _addMatchup,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            children: [
              Expanded(child: matchupList),
              const SizedBox(height: 8),
              SizedBox(
                height: bottomSectionHeight,
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    const double dragHandleHeight = 20;
                    const double collapsedSectionHeight = 64;
                    final double contentHeight = max(
                      0,
                      constraints.maxHeight - dragHandleHeight,
                    );
                    late final double topHeight;
                    late final double bottomHeight;

                    if (!_userNotesExpanded && !_matchupHistoryExpanded) {
                      topHeight = min(
                        collapsedSectionHeight,
                        contentHeight / 2,
                      );
                      bottomHeight = max(0, contentHeight - topHeight);
                    } else if (!_userNotesExpanded) {
                      topHeight = min(collapsedSectionHeight, contentHeight);
                      bottomHeight = max(0, contentHeight - topHeight);
                    } else if (!_matchupHistoryExpanded) {
                      bottomHeight = min(collapsedSectionHeight, contentHeight);
                      topHeight = max(0, contentHeight - bottomHeight);
                    } else {
                      topHeight = contentHeight * _notesHistoryRatio;
                      bottomHeight = contentHeight - topHeight;
                    }

                    return Column(
                      children: [
                        SizedBox(
                          height: topHeight,
                          child: _buildUserNotesCard(),
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragUpdate: (DragUpdateDetails details) {
                            if (contentHeight <= 0 ||
                                !_userNotesExpanded ||
                                !_matchupHistoryExpanded) {
                              return;
                            }
                            setState(() {
                              _notesHistoryRatio =
                                  (_notesHistoryRatio +
                                          (details.delta.dy / contentHeight))
                                      .clamp(0.2, 0.8);
                            });
                          },
                          child: SizedBox(
                            height: dragHandleHeight,
                            child: Center(
                              child: Container(
                                width: 60,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.32),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: bottomHeight,
                          child: _buildMatchupHistoryCard(),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SideboardPlanScreen extends StatefulWidget {
  const SideboardPlanScreen({super.key, required this.matchup});

  final SideboardMatchup matchup;

  @override
  State<SideboardPlanScreen> createState() => _SideboardPlanScreenState();
}

class _SideboardPlanScreenState extends State<SideboardPlanScreen> {
  late List<SideboardCardEntry> _sideIn;
  late List<SideboardCardEntry> _sideOut;

  @override
  void initState() {
    super.initState();
    _sideIn = List<SideboardCardEntry>.from(widget.matchup.sideIn);
    _sideOut = List<SideboardCardEntry>.from(widget.matchup.sideOut);
  }

  void _closeWithResult() {
    Navigator.of(context).pop(
      widget.matchup.copyWith(
        sideIn: List<SideboardCardEntry>.from(_sideIn),
        sideOut: List<SideboardCardEntry>.from(_sideOut),
      ),
    );
  }

  Future<String?> _promptText({
    required String title,
    required String hintText,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return _TextPromptDialog(
          title: title,
          initialValue: '',
          hintText: hintText,
          maxLines: 1,
        );
      },
    );
  }

  Future<void> _addCard({required bool sideIn}) async {
    final String? rawName = await _promptText(
      title: sideIn ? 'Add Side In card' : 'Add Side Out card',
      hintText: 'Card name',
    );
    if (rawName == null) {
      return;
    }

    final String name = rawName.trim();
    if (name.isEmpty) {
      return;
    }

    setState(() {
      if (sideIn) {
        _sideIn.add(SideboardCardEntry(name: name, copies: 1));
      } else {
        _sideOut.add(SideboardCardEntry(name: name, copies: 1));
      }
    });
  }

  void _removeCard({required bool sideIn, required int index}) {
    setState(() {
      if (sideIn) {
        _sideIn.removeAt(index);
      } else {
        _sideOut.removeAt(index);
      }
    });
  }

  void _updateCopies({
    required bool sideIn,
    required int index,
    required int copies,
  }) {
    setState(() {
      if (sideIn) {
        _sideIn[index] = _sideIn[index].copyWith(copies: copies);
      } else {
        _sideOut[index] = _sideOut[index].copyWith(copies: copies);
      }
    });
  }

  Widget _buildSection({
    required String title,
    required List<SideboardCardEntry> items,
    required bool sideIn,
  }) {
    return Expanded(
      child: Card(
        color: const Color(0xFF1E1B1B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _addCard(sideIn: sideIn),
                    tooltip: 'Add card',
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF2B2424),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Text(
                          'No cards added yet',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.62),
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (BuildContext context, int index) =>
                            Divider(
                              color: Colors.white.withValues(alpha: 0.12),
                              height: 1,
                            ),
                        itemBuilder: (BuildContext context, int index) {
                          final SideboardCardEntry item = items[index];
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            title: Text(item.name),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: item.copies,
                                    dropdownColor: const Color(0xFF2B2424),
                                    borderRadius: BorderRadius.circular(10),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    items: const <int>[1, 2, 3, 4]
                                        .map(
                                          (int value) => DropdownMenuItem<int>(
                                            value: value,
                                            child: Text('$value'),
                                          ),
                                        )
                                        .toList(growable: false),
                                    onChanged: (int? value) {
                                      if (value == null) {
                                        return;
                                      }
                                      _updateCopies(
                                        sideIn: sideIn,
                                        index: index,
                                        copies: value,
                                      );
                                    },
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Remove card',
                                  onPressed: () =>
                                      _removeCard(sideIn: sideIn, index: index),
                                  icon: const Icon(
                                    Icons.remove_circle_outline_rounded,
                                    size: 20,
                                  ),
                                  color: const Color(0xFFFF8A8A),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        _closeWithResult();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.matchup.name),
          leading: IconButton(
            onPressed: _closeWithResult,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            children: [
              _buildSection(title: 'Side In', items: _sideIn, sideIn: true),
              const SizedBox(height: 10),
              _buildSection(title: 'Side Out', items: _sideOut, sideIn: false),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.initialValue,
    required this.hintText,
    required this.maxLines,
  });

  final String title;
  final String initialValue;
  final String hintText;
  final int maxLines;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: widget.maxLines,
        textInputAction: widget.maxLines == 1
            ? TextInputAction.done
            : TextInputAction.newline,
        decoration: InputDecoration(
          hintText: widget.hintText,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class CustomizeScreen extends StatefulWidget {
  const CustomizeScreen({super.key, required this.initialSettings});

  final AppSettings initialSettings;

  @override
  State<CustomizeScreen> createState() => _CustomizeScreenState();
}

class _CustomizeScreenState extends State<CustomizeScreen> {
  static const List<Color> _palette = <Color>[
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

  late final TextEditingController _playerOneController;
  late final TextEditingController _playerTwoController;
  late final ScrollController _customizeScrollController;

  late Color _backgroundStartColor;
  late Color _backgroundEndColor;
  late Color _buttonColor;
  late Color _lifePointsBackgroundColor;
  late SupportedTcg _startupTcg;

  @override
  void initState() {
    super.initState();
    _playerOneController = TextEditingController(
      text: widget.initialSettings.playerOneName,
    );
    _playerTwoController = TextEditingController(
      text: widget.initialSettings.playerTwoName,
    );
    _backgroundStartColor = widget.initialSettings.backgroundStartColor;
    _backgroundEndColor = widget.initialSettings.backgroundEndColor;
    _buttonColor = widget.initialSettings.buttonColor;
    _lifePointsBackgroundColor =
        widget.initialSettings.lifePointsBackgroundColor;
    _startupTcg = SupportedTcgX.fromStorageKey(
      widget.initialSettings.startupTcgKey,
    );
    _customizeScrollController = ScrollController();
  }

  @override
  void dispose() {
    _playerOneController.dispose();
    _playerTwoController.dispose();
    _customizeScrollController.dispose();
    super.dispose();
  }

  AppSettings _buildSettings() {
    final String playerOneName = _playerOneController.text.trim().isEmpty
        ? 'Player 1'
        : _playerOneController.text.trim();
    final String playerTwoName = _playerTwoController.text.trim().isEmpty
        ? 'Player 2'
        : _playerTwoController.text.trim();

    return widget.initialSettings.copyWith(
      playerOneName: playerOneName,
      playerTwoName: playerTwoName,
      startupTcgKey: _startupTcg.storageKey,
      backgroundStartColor: _backgroundStartColor,
      backgroundEndColor: _backgroundEndColor,
      buttonColor: _buttonColor,
      lifePointsBackgroundColor: _lifePointsBackgroundColor,
    );
  }

  void _saveSettings() {
    Navigator.of(context).pop(_buildSettings());
  }

  Widget _buildColorPicker({
    required String label,
    required Color selectedColor,
    required ValueChanged<Color> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final Color color in _palette)
              GestureDetector(
                onTap: () => onChanged(color),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selectedColor == color
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.2),
                      width: selectedColor == color ? 2.4 : 1,
                    ),
                  ),
                  child: selectedColor == color
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color previewMiddle =
        Color.lerp(_backgroundStartColor, _backgroundEndColor, 0.45) ??
        _backgroundStartColor;
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final EdgeInsets contentPadding = EdgeInsets.fromLTRB(
      16,
      16,
      16,
      24 + mediaQuery.viewPadding.bottom + mediaQuery.viewInsets.bottom,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customize App'),
        actions: [
          FilledButton(onPressed: _saveSettings, child: const Text('Save')),
          const SizedBox(width: 12),
        ],
      ),
      body: Scrollbar(
        controller: _customizeScrollController,
        child: ListView(
          controller: _customizeScrollController,
          primary: false,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: contentPadding,
          children: [
            const Text(
              'Players',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _playerOneController,
              decoration: const InputDecoration(
                labelText: 'Player 1 name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _playerTwoController,
              decoration: const InputDecoration(
                labelText: 'Player 2 name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Startup',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<SupportedTcg>(
              initialValue: _startupTcg,
              decoration: const InputDecoration(
                labelText: 'Open app with',
                border: OutlineInputBorder(),
              ),
              items: _supportedTcgAlphabeticalOrder
                  .map(
                    (SupportedTcg game) => DropdownMenuItem<SupportedTcg>(
                      value: game,
                      child: Text(game.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (SupportedTcg? value) {
                if (value == null || value == _startupTcg) {
                  return;
                }
                setState(() {
                  _startupTcg = value;
                });
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Colors',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            _buildColorPicker(
              label: 'Background start',
              selectedColor: _backgroundStartColor,
              onChanged: (Color color) {
                setState(() {
                  _backgroundStartColor = color;
                });
              },
            ),
            const SizedBox(height: 12),
            _buildColorPicker(
              label: 'Background end',
              selectedColor: _backgroundEndColor,
              onChanged: (Color color) {
                setState(() {
                  _backgroundEndColor = color;
                });
              },
            ),
            const SizedBox(height: 12),
            _buildColorPicker(
              label: 'Button color',
              selectedColor: _buttonColor,
              onChanged: (Color color) {
                setState(() {
                  _buttonColor = color;
                });
              },
            ),
            const SizedBox(height: 12),
            _buildColorPicker(
              label: 'Life Points background',
              selectedColor: _lifePointsBackgroundColor,
              onChanged: (Color color) {
                setState(() {
                  _lifePointsBackgroundColor = color;
                });
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Preview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    _backgroundStartColor,
                    previewMiddle,
                    _backgroundEndColor,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_playerOneController.text.trim().isEmpty ? 'Player 1' : _playerOneController.text.trim()} vs ${_playerTwoController.text.trim().isEmpty ? 'Player 2' : _playerTwoController.text.trim()}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: () {},
                        style: FilledButton.styleFrom(
                          backgroundColor: _buttonColor,
                        ),
                        child: const Text('Button'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _lifePointsBackgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: const Text(
                      '8000',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
