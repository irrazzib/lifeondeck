import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/ux_state.dart';
import '../../l10n/app_strings.dart';
import '../../models/game_record.dart';
import '../../models/match.dart';
import '../../models/sideboard.dart';

class _DeckStatisticsRow {
  const _DeckStatisticsRow({
    required this.opponentDeck,
    required this.matches,
    required this.wins,
    required this.losses,
    required this.draws,
  });

  final String opponentDeck;
  final int matches;
  final int wins;
  final int losses;
  final int draws;
}

class DeckStatisticsScreen extends StatelessWidget {
  const DeckStatisticsScreen({required this.deck, required this.records});

  final SideboardDeck deck;
  final List<GameRecord> records;

  String _effectiveMatchId(GameRecord record) {
    final String raw = record.matchId.trim();
    if (raw.isNotEmpty) {
      return raw;
    }
    return 'legacy-${record.id}';
  }

  String _firstNonEmptyFromNewest(
    List<GameRecord> games,
    String Function(GameRecord game) pick,
  ) {
    for (int index = games.length - 1; index >= 0; index -= 1) {
      final String value = pick(games[index]).trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  List<GameRecord> _recordsForDeck() {
    final String deckId = deck.id.trim();
    final String deckName = deck.name.trim().toLowerCase();
    final List<GameRecord> linked = records
        .where((GameRecord record) {
          if (deckId.isNotEmpty && record.deckId.trim() == deckId) {
            return true;
          }
          return deckName.isNotEmpty &&
              record.deckName.trim().toLowerCase() == deckName;
        })
        .where((GameRecord record) => record.playerCount == 2)
        .toList(growable: false);
    linked.sort((GameRecord a, GameRecord b) {
      return b.createdAt.compareTo(a.createdAt);
    });
    return linked;
  }

  List<_DeckStatisticsRow> _statsRows() {
    final List<GameRecord> linked = _recordsForDeck();
    if (linked.isEmpty) {
      return const <_DeckStatisticsRow>[];
    }
    final Map<String, List<GameRecord>> groupedMatches =
        <String, List<GameRecord>>{};
    for (final GameRecord record in linked) {
      final String key = _effectiveMatchId(record);
      groupedMatches.putIfAbsent(key, () => <GameRecord>[]).add(record);
    }

    final Map<String, ({int matches, int wins, int losses, int draws})> table =
        <String, ({int matches, int wins, int losses, int draws})>{};

    for (final List<GameRecord> games in groupedMatches.values) {
      games.sort((GameRecord a, GameRecord b) {
        final int byStage = gameStageSortKey(
          a.gameStage,
        ).compareTo(gameStageSortKey(b.gameStage));
        if (byStage != 0) {
          return byStage;
        }
        return a.createdAt.compareTo(b.createdAt);
      });
      final String opponentDeck = _firstNonEmptyFromNewest(
        games,
        (GameRecord game) => game.opponentDeckName.trim(),
      );
      final String key = opponentDeck.isEmpty ? '-' : opponentDeck;
      final MatchAggregateResult aggregate = aggregateMatchResultFromGames(
        games,
      );
      final ({int matches, int wins, int losses, int draws}) current =
          table[key] ?? (matches: 0, wins: 0, losses: 0, draws: 0);
      int wins = current.wins;
      int losses = current.losses;
      int draws = current.draws;
      if (aggregate == MatchAggregateResult.win) {
        wins += 1;
      } else if (aggregate == MatchAggregateResult.loss) {
        losses += 1;
      } else if (aggregate == MatchAggregateResult.draw) {
        draws += 1;
      }
      table[key] = (
        matches: current.matches + 1,
        wins: wins,
        losses: losses,
        draws: draws,
      );
    }

    final List<_DeckStatisticsRow> rows = table.entries
        .map((
          MapEntry<String, ({int matches, int wins, int losses, int draws})> e,
        ) {
          return _DeckStatisticsRow(
            opponentDeck: e.key,
            matches: e.value.matches,
            wins: e.value.wins,
            losses: e.value.losses,
            draws: e.value.draws,
          );
        })
        .toList(growable: false);
    rows.sort((_DeckStatisticsRow a, _DeckStatisticsRow b) {
      return a.opponentDeck.toLowerCase().compareTo(
        b.opponentDeck.toLowerCase(),
      );
    });
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings txt = context.txt;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) {
        return;
      }
      unawaited(
        showInfoTipOnce(
          context: context,
          tipId: InfoTipIds.statistics,
          titleKey: 'info.statistics.title',
          bodyKey: 'info.statistics.body',
          icon: Icons.query_stats_rounded,
        ),
      );
    });
    final List<_DeckStatisticsRow> rows = _statsRows();
    return Scaffold(
      appBar: AppBar(title: Text(txt.t('statistics.title'))),
      body: rows.isEmpty
          ? Center(
              child: Text(
                txt.t('statistics.empty'),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.74)),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              itemCount: rows.length,
              itemBuilder: (BuildContext context, int index) {
                final _DeckStatisticsRow row = rows[index];
                final double winRate = row.matches == 0
                    ? 0
                    : (row.wins / row.matches) * 100;
                final double lossRate = row.matches == 0
                    ? 0
                    : (row.losses / row.matches) * 100;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  color: const Color(0xFF1E1B1B),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          txt.t(
                            'statistics.vs',
                            params: <String, Object?>{'deck': row.opponentDeck},
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(txt.t('statistics.matches', params: <String, Object?>{'count': row.matches})),
                        const SizedBox(height: 2),
                        Text(txt.t('statistics.wins', params: <String, Object?>{'count': row.wins})),
                        const SizedBox(height: 2),
                        Text(txt.t('statistics.losses', params: <String, Object?>{'count': row.losses})),
                        if (row.draws > 0) ...[
                          const SizedBox(height: 2),
                          Text(txt.t('statistics.draws', params: <String, Object?>{'count': row.draws})),
                        ],
                        const SizedBox(height: 6),
                        Text(txt.t('statistics.winrate', params: <String, Object?>{'value': winRate.toStringAsFixed(1)})),
                        const SizedBox(height: 2),
                        Text(txt.t('statistics.lossRate', params: <String, Object?>{'value': lossRate.toStringAsFixed(1)})),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

