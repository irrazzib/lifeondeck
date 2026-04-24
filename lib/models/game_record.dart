import 'dart:math';

import 'package:flutter/material.dart';

import '../core/constants.dart';
import 'sideboard.dart';

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
    this.playerCount = 2,
    this.matchId = '',
    this.matchName = '',
    this.matchFormat = '',
    this.opponentDeckId = '',
    this.opponentDeckName = '',
    this.matchTag = '',
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
  final int playerCount;
  final String matchId;
  final String matchName;
  final String matchFormat;
  final String opponentDeckId;
  final String opponentDeckName;
  final String matchTag;

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
    int? playerCount,
    String? matchId,
    String? matchName,
    String? matchFormat,
    String? opponentDeckId,
    String? opponentDeckName,
    String? matchTag,
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
      playerCount: playerCount ?? this.playerCount,
      matchId: matchId ?? this.matchId,
      matchName: matchName ?? this.matchName,
      matchFormat: matchFormat ?? this.matchFormat,
      opponentDeckId: opponentDeckId ?? this.opponentDeckId,
      opponentDeckName: opponentDeckName ?? this.opponentDeckName,
      matchTag: matchTag ?? this.matchTag,
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
      'playerCount': playerCount,
      'matchId': matchId,
      'matchName': matchName,
      'matchFormat': matchFormat,
      'opponentDeckId': opponentDeckId,
      'opponentDeckName': opponentDeckName,
      'matchTag': matchTag,
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
    final String gameStage = supportedGameStages.contains(rawGameStage)
        ? rawGameStage
        : 'G1';
    final String notes = (json['notes'] as String?) ?? '';
    final String deckId = ((json['deckId'] as String?) ?? '').trim();
    final String rawResult = ((json['matchResult'] as String?) ?? '').trim();
    final String matchResult = supportedMatchResults.contains(rawResult)
        ? rawResult
        : '';
    final String opponentName = ((json['opponentName'] as String?) ?? '')
        .trim();
    final String deckName = ((json['deckName'] as String?) ?? '').trim();
    final String playerOneName = ((json['playerOneName'] as String?) ?? '')
        .trim();
    final String playerTwoName = ((json['playerTwoName'] as String?) ?? '')
        .trim();
    final String matchId = ((json['matchId'] as String?) ?? '').trim();
    final String matchName = ((json['matchName'] as String?) ?? '').trim();
    final String matchFormat = ((json['matchFormat'] as String?) ?? '').trim();
    final String opponentDeckId = ((json['opponentDeckId'] as String?) ?? '')
        .trim();
    final String opponentDeckName =
        ((json['opponentDeckName'] as String?) ?? '').trim();
    final String matchTag = ((json['matchTag'] as String?) ?? '').trim();
    final bool hasRawTcgKey =
        json['tcgKey'] is String &&
        (json['tcgKey'] as String).trim().isNotEmpty;
    final String inferredTcgFallback = title.toLowerCase().startsWith('mtg')
        ? 'mtg'
        : 'yugioh';
    final String tcgKey = normalizeTcgKey(
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
    int parsedPlayerCount = 2;
    final Object? rawPlayerCount = json['playerCount'];
    if (rawPlayerCount is int) {
      parsedPlayerCount = rawPlayerCount;
    } else if (rawPlayerCount is String) {
      parsedPlayerCount = int.tryParse(rawPlayerCount.trim()) ?? 2;
    } else if (tcgKey == SupportedTcg.yugioh.storageKey) {
      parsedPlayerCount = 2;
    } else if (lifePointHistory.isNotEmpty) {
      if (lifePointHistory.first.contains('|')) {
        parsedPlayerCount = 2;
      } else {
        final RegExp playerPattern = RegExp(
          r'Player\s+(\d+)',
          caseSensitive: false,
        );
        int maxPlayerIndex = 0;
        for (final String line in lifePointHistory) {
          for (final RegExpMatch match in playerPattern.allMatches(line)) {
            final int? parsed = int.tryParse(match.group(1) ?? '');
            if (parsed != null && parsed > maxPlayerIndex) {
              maxPlayerIndex = parsed;
            }
          }
        }
        if (maxPlayerIndex >= 2) {
          parsedPlayerCount = maxPlayerIndex;
        }
      }
    }
    final int playerCount = parsedPlayerCount.clamp(2, 6).toInt();
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
      playerCount: playerCount,
      matchId: matchId,
      matchName: matchName,
      matchFormat: matchFormat,
      opponentDeckId: opponentDeckId,
      opponentDeckName: opponentDeckName,
      matchTag: matchTag,
    );
  }
}

@immutable
class DuelCompletedGamePayload {
  const DuelCompletedGamePayload({
    required this.lifePointHistory,
    required this.gameStage,
    required this.opponentName,
    required this.deckId,
    required this.deckName,
    required this.opponentDeckId,
    required this.opponentDeckName,
    required this.matchFormat,
    required this.matchTag,
    required this.matchId,
    required this.matchName,
    required this.matchResult,
    required this.createdAt,
  });

  final List<String> lifePointHistory;
  final String gameStage;
  final String opponentName;
  final String deckId;
  final String deckName;
  final String opponentDeckId;
  final String opponentDeckName;
  final String matchFormat;
  final String matchTag;
  final String matchId;
  final String matchName;
  final String matchResult;
  final DateTime createdAt;
}

@immutable
class DuelResultPayload {
  const DuelResultPayload({
    required this.lifePointHistory,
    required this.gameStage,
    required this.opponentName,
    required this.deckId,
    required this.deckName,
    required this.opponentDeckId,
    required this.opponentDeckName,
    required this.matchFormat,
    required this.matchTag,
    required this.matchResult,
    required this.playerCount,
    this.shouldSave = true,
    this.completedGames = const <DuelCompletedGamePayload>[],
    this.createdDecks = const <SideboardDeck>[],
    this.matchId = '',
    this.matchName = '',
  });

  final List<String> lifePointHistory;
  final String gameStage;
  final String opponentName;
  final String deckId;
  final String deckName;
  final String opponentDeckId;
  final String opponentDeckName;
  final String matchFormat;
  final String matchTag;
  final String matchResult;
  final int playerCount;
  final bool shouldSave;
  final List<DuelCompletedGamePayload> completedGames;
  final List<SideboardDeck> createdDecks;
  final String matchId;
  final String matchName;
}

typedef DuelCheckpointCallback =
    Future<void> Function(DuelResultPayload payload);

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

List<String> buildTwoPlayerHistoryTable({
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

bool looksLikeTwoPlayerHistoryTable(List<String> lines) {
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

List<(String, String)> splitTwoPlayerHistoryRows(List<String> lines) {
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

({String playerName, String content})? parseNamedLifeHistoryLine(String line) {
  final int separatorIndex = line.indexOf(':');
  if (separatorIndex <= 0) {
    return null;
  }
  final String playerName = line.substring(0, separatorIndex).trim();
  final String content = line.substring(separatorIndex + 1).trim();
  if (playerName.isEmpty || content.isEmpty) {
    return null;
  }
  return (playerName: playerName, content: content);
}

({List<String> headers, List<List<String>> rows})?
buildThreeOrFourPlayerHistoryGrid({
  required List<String> lines,
  required int playerCount,
}) {
  if (playerCount < 3 || playerCount > 4 || lines.length < playerCount) {
    return null;
  }

  final List<String> headers = List<String>.generate(
    playerCount,
    (int index) => 'P${index + 1}',
  );
  final List<String> initialRow = List<String>.filled(playerCount, '');

  for (int index = 0; index < playerCount; index += 1) {
    final ({String playerName, String content})? parsed =
        parseNamedLifeHistoryLine(lines[index]);
    if (parsed == null) {
      return null;
    }
    headers[index] = parsed.playerName;
    initialRow[index] = parsed.content;
  }

  final Map<String, int> playerIndexByName = <String, int>{
    for (int index = 0; index < headers.length; index += 1)
      headers[index].trim().toLowerCase(): index,
  };

  final List<List<String>> rows = <List<String>>[initialRow];
  for (final String line in lines.skip(playerCount)) {
    final ({String playerName, String content})? parsed =
        parseNamedLifeHistoryLine(line);
    if (parsed == null) {
      return null;
    }
    final int? playerIndex =
        playerIndexByName[parsed.playerName.trim().toLowerCase()];
    if (playerIndex == null) {
      return null;
    }
    final List<String> row = List<String>.filled(playerCount, '');
    row[playerIndex] = parsed.content;
    rows.add(row);
  }

  return (headers: headers, rows: rows);
}

Widget buildColumnarLifeHistoryView({
  required List<String> headers,
  required List<List<String>> rows,
  required Color dividerColor,
}) {
  final int playerCount = headers.length;
  final double headerFontSize = playerCount == 4 ? 11.0 : 12.2;
  final double bodyFontSize = playerCount == 4 ? 10.5 : 11.8;
  final double horizontalPadding = playerCount == 4 ? 6 : 8;
  final double minColumnWidth = playerCount == 4 ? 92 : 112;

  Widget buildGridRow(
    List<String> cells, {
    required bool isHeader,
    int? index,
  }) {
    final bool isOdd = index != null && index.isOdd;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: isHeader ? 8 : 7,
      ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int cellIndex = 0; cellIndex < cells.length; cellIndex += 1) ...[
            Expanded(
              child: Text(
                cells[cellIndex],
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: isHeader ? FontWeight.w800 : FontWeight.w500,
                  fontSize: isHeader ? headerFontSize : bodyFontSize,
                ),
              ),
            ),
            if (cellIndex < cells.length - 1)
              Container(
                width: 1,
                height: isHeader ? 24 : 20,
                color: dividerColor,
              ),
          ],
        ],
      ),
    );
  }

  return LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final double gridWidth = max(
        constraints.maxWidth,
        headers.length * minColumnWidth + (headers.length - 1),
      );
      return SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: gridWidth,
            child: Column(
              children: [
                buildGridRow(headers, isHeader: true),
                for (int index = 0; index < rows.length; index += 1)
                  buildGridRow(rows[index], isHeader: false, index: index),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget buildLifeHistoryView({
  required List<String> lines,
  required int playerCount,
  required Color dividerColor,
}) {
  if (playerCount >= 3 && playerCount <= 4) {
    final ({List<String> headers, List<List<String>> rows})? gridData =
        buildThreeOrFourPlayerHistoryGrid(
          lines: lines,
          playerCount: playerCount,
        );
    if (gridData != null) {
      return buildColumnarLifeHistoryView(
        headers: gridData.headers,
        rows: gridData.rows,
        dividerColor: dividerColor,
      );
    }
  }

  if (!looksLikeTwoPlayerHistoryTable(lines)) {
    return SingleChildScrollView(
      child: SelectableText(
        lines.join('\n'),
        style: const TextStyle(height: 1.35, fontFamily: 'monospace'),
      ),
    );
  }

  final List<(String, String)> rows = splitTwoPlayerHistoryRows(lines);
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
