import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import 'game_record.dart';

enum MatchAggregateResult { pending, win, loss, draw }

enum MatchHistorySortMode { date, name }

@immutable
class FilterOption {
  const FilterOption({required this.value, required this.label});

  final String value;
  final String label;
}

String normalizedMatchResultOrEmpty(String raw) {
  final String trimmed = raw.trim();
  return supportedMatchResults.contains(trimmed) ? trimmed : '';
}

MatchAggregateResult aggregateMatchResultFromGames(List<GameRecord> games) {
  int wins = 0;
  int losses = 0;
  int draws = 0;

  for (final GameRecord game in games) {
    switch (normalizedMatchResultOrEmpty(game.matchResult)) {
      case 'Win':
        wins += 1;
        if (wins >= 2) {
          return MatchAggregateResult.win;
        }
        break;
      case 'Loss':
        losses += 1;
        if (losses >= 2) {
          return MatchAggregateResult.loss;
        }
        break;
      case 'Draw':
        draws += 1;
        break;
      default:
        break;
    }
  }

  if (wins == 0 && losses == 0 && draws > 0) {
    return MatchAggregateResult.draw;
  }
  if (draws > 0 && wins == losses && (wins + losses) > 0) {
    return MatchAggregateResult.draw;
  }
  return MatchAggregateResult.pending;
}

String matchAggregateResultLabel(MatchAggregateResult result) {
  switch (result) {
    case MatchAggregateResult.win:
      return 'Win';
    case MatchAggregateResult.loss:
      return 'Loss';
    case MatchAggregateResult.draw:
      return 'Draw';
    case MatchAggregateResult.pending:
      return 'Pending';
  }
}

@immutable
class MatchMetadata {
  const MatchMetadata({
    required this.name,
    required this.opponentName,
    required this.deckId,
    required this.deckName,
    required this.opponentDeckId,
    required this.opponentDeckName,
    required this.format,
    required this.tag,
  });

  final String name;
  final String opponentName;
  final String deckId;
  final String deckName;
  final String opponentDeckId;
  final String opponentDeckName;
  final String format;
  final String tag;

  MatchMetadata copyWith({
    String? name,
    String? opponentName,
    String? deckId,
    String? deckName,
    String? opponentDeckId,
    String? opponentDeckName,
    String? format,
    String? tag,
  }) {
    return MatchMetadata(
      name: name ?? this.name,
      opponentName: opponentName ?? this.opponentName,
      deckId: deckId ?? this.deckId,
      deckName: deckName ?? this.deckName,
      opponentDeckId: opponentDeckId ?? this.opponentDeckId,
      opponentDeckName: opponentDeckName ?? this.opponentDeckName,
      format: format ?? this.format,
      tag: tag ?? this.tag,
    );
  }
}

@immutable
class MatchRecord {
  const MatchRecord({
    required this.id,
    required this.tcgKey,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
    required this.games,
    required this.aggregateResult,
  });

  final String id;
  final String tcgKey;
  final MatchMetadata metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<GameRecord> games;
  final MatchAggregateResult aggregateResult;
}

