import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../l10n/app_strings.dart';
import '../../models/game_record.dart';
import '../../models/match.dart';
import '../../models/sideboard.dart';
import 'sideboard_plan_screen.dart';
import 'sideboard_deck_list_screen.dart';
import '../../widgets/text_prompt_dialog.dart';

enum DeckSectionMode { matchupHistory, sideboardPlans }

class DeckMatchupHistoryScreen extends StatefulWidget {
  const DeckMatchupHistoryScreen({
    required this.deck,
    required this.records,
    required this.mode,
  });

  final SideboardDeck deck;
  final List<GameRecord> records;
  final DeckSectionMode mode;

  @override
  State<DeckMatchupHistoryScreen> createState() =>
      _DeckMatchupHistoryScreenState();
}

class _DeckMatchupHistoryScreenState extends State<DeckMatchupHistoryScreen> {
  late List<SideboardMatchup> _matchups;
  late List<GameRecord> _records;
  SideboardMatchupSortMode _matchupSortMode =
      SideboardMatchupSortMode.createdAt;
  final TextEditingController _matchupNameFilterController =
      TextEditingController();
  String _matchupNameFilter = '';
  bool _matchupFiltersExpanded = false;

  @override
  void initState() {
    super.initState();
    _matchups = List<SideboardMatchup>.from(widget.deck.matchups);
    _records = List<GameRecord>.from(widget.records);
  }

  @override
  void dispose() {
    _matchupNameFilterController.dispose();
    super.dispose();
  }

  bool get _hasActiveMatchupFilters => _matchupNameFilter.trim().isNotEmpty;

  void _clearMatchupFilters() {
    _matchupNameFilterController.clear();
    setState(() {
      _matchupNameFilter = '';
    });
  }

  void _closeWithResult() {
    if (widget.mode == DeckSectionMode.sideboardPlans) {
      Navigator.of(context).pop(List<SideboardMatchup>.from(_matchups));
      return;
    }
    Navigator.of(context).pop();
  }

  Future<String?> _promptText({
    required String title,
    required String hintText,
    String initialValue = '',
  }) async {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return TextPromptDialog(
          title: title,
          initialValue: initialValue,
          hintText: hintText,
          maxLines: 1,
        );
      },
    );
  }

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
    final String deckId = widget.deck.id.trim();
    final String deckName = widget.deck.name.trim().toLowerCase();
    final List<GameRecord> linked = _records
        .where((GameRecord record) {
          if (deckId.isNotEmpty && record.deckId.trim() == deckId) {
            return true;
          }
          return deckName.isNotEmpty &&
              record.deckName.trim().toLowerCase() == deckName;
        })
        .toList(growable: false);
    linked.sort((GameRecord a, GameRecord b) {
      return b.createdAt.compareTo(a.createdAt);
    });
    return linked;
  }

  List<MatchRecord> _linkedMatchRecords() {
    final List<GameRecord> twoPlayerRecords = _recordsForDeck()
        .where((GameRecord record) => record.playerCount == 2)
        .toList(growable: false);
    if (twoPlayerRecords.isEmpty) {
      return const <MatchRecord>[];
    }
    final Map<String, List<GameRecord>> grouped = <String, List<GameRecord>>{};
    for (final GameRecord record in twoPlayerRecords) {
      final String key = _effectiveMatchId(record);
      grouped.putIfAbsent(key, () => <GameRecord>[]).add(record);
    }
    final List<MatchRecord> matches = <MatchRecord>[];
    for (final MapEntry<String, List<GameRecord>> entry in grouped.entries) {
      final List<GameRecord> games = List<GameRecord>.from(entry.value);
      games.sort((GameRecord a, GameRecord b) {
        final int byStage = gameStageSortKey(
          a.gameStage,
        ).compareTo(gameStageSortKey(b.gameStage));
        if (byStage != 0) {
          return byStage;
        }
        return a.createdAt.compareTo(b.createdAt);
      });
      final DateTime createdAt = games
          .map((GameRecord game) => game.createdAt)
          .reduce((DateTime a, DateTime b) => a.isBefore(b) ? a : b);
      final DateTime updatedAt = games
          .map((GameRecord game) => game.createdAt)
          .reduce((DateTime a, DateTime b) => a.isAfter(b) ? a : b);
      final String name = _firstNonEmptyFromNewest(
        games,
        (GameRecord game) => game.matchName.trim(),
      );
      final String opponent = _firstNonEmptyFromNewest(games, (
        GameRecord game,
      ) {
        final String v = game.opponentName.trim();
        if (v.isNotEmpty) {
          return v;
        }
        return game.playerTwoName.trim();
      });
      final String deckName = _firstNonEmptyFromNewest(
        games,
        (GameRecord game) => game.deckName.trim(),
      );
      final String opponentDeckName = _firstNonEmptyFromNewest(
        games,
        (GameRecord game) => game.opponentDeckName.trim(),
      );
      final String format = _firstNonEmptyFromNewest(
        games,
        (GameRecord game) => game.matchFormat.trim(),
      );
      final String tag = _firstNonEmptyFromNewest(
        games,
        (GameRecord game) => game.matchTag.trim(),
      );
      matches.add(
        MatchRecord(
          id: entry.key,
          tcgKey: widget.deck.tcgKey,
          metadata: MatchMetadata(
            name: name.isEmpty ? 'Match' : name,
            opponentName: opponent,
            deckId: widget.deck.id,
            deckName: deckName,
            opponentDeckId: '',
            opponentDeckName: opponentDeckName,
            format: format,
            tag: tag,
            matchDate: null,
          ),
          createdAt: createdAt,
          updatedAt: updatedAt,
          games: games,
          aggregateResult: aggregateMatchResultFromGames(games),
        ),
      );
    }
    matches.sort((MatchRecord a, MatchRecord b) {
      return b.createdAt.compareTo(a.createdAt);
    });
    return matches;
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
    final SideboardMatchup? updated = await Navigator.of(context)
        .push<SideboardMatchup>(
          MaterialPageRoute<SideboardMatchup>(
            builder: (_) => SideboardPlanScreen(matchup: matchup),
          ),
        );
    if (updated == null) {
      return;
    }
    final int index = _matchups.indexWhere(
      (SideboardMatchup item) => item.id == matchup.id,
    );
    if (index < 0) {
      return;
    }
    setState(() {
      _matchups[index] = updated;
    });
  }

  List<SideboardMatchup> _sortedMatchups() {
    final String query = _matchupNameFilter.trim().toLowerCase();
    final List<SideboardMatchup> sorted = _matchups
        .where(
          (SideboardMatchup m) =>
              query.isEmpty || m.name.toLowerCase().contains(query),
        )
        .toList(growable: true);
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

  Widget _buildSideboardPlansControls(AppStrings txt) {
    return Card(
      color: const Color(0xFF1E1B1B),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(
                () => _matchupFiltersExpanded = !_matchupFiltersExpanded,
              ),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      txt.t('sideboardPlans.sortFilter'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    if (_hasActiveMatchupFilters) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFAA33),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Icon(
                      _matchupFiltersExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            ),
            if (_matchupFiltersExpanded) ...[
              const SizedBox(height: 12),
              Text(
                txt.t('history.sortBy'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<SideboardMatchupSortMode>(
                      initialValue: _matchupSortMode,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items:
                          <DropdownMenuItem<SideboardMatchupSortMode>>[
                            DropdownMenuItem<SideboardMatchupSortMode>(
                              value: SideboardMatchupSortMode.createdAt,
                              child: Text(
                                txt.t('deckList.sortCreationDate'),
                              ),
                            ),
                            DropdownMenuItem<SideboardMatchupSortMode>(
                              value: SideboardMatchupSortMode.alphabetical,
                              child: Text(
                                txt.t('deckList.sortAlphabetical'),
                              ),
                            ),
                          ],
                      onChanged: (SideboardMatchupSortMode? mode) {
                        if (mode == null) {
                          return;
                        }
                        setState(() {
                          _matchupSortMode = mode;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonalIcon(
                    onPressed: _hasActiveMatchupFilters
                        ? _clearMatchupFilters
                        : null,
                    icon: const Icon(Icons.filter_alt_off_rounded),
                    label: Text(txt.t('history.clearFilters')),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                txt.t('history.filters'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _matchupNameFilterController,
                onChanged: (String value) {
                  setState(() {
                    _matchupNameFilter = value;
                  });
                },
                decoration: InputDecoration(
                  labelText: txt.t('sideboardPlans.searchByName'),
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _matchupNameFilter.trim().isEmpty
                      ? null
                      : IconButton(
                          onPressed: _clearMatchupFilters,
                          icon: const Icon(Icons.close_rounded),
                          tooltip: txt.t('common.clear'),
                        ),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings txt = context.txt;
    final List<SideboardMatchup> sortedMatchups = _sortedMatchups();
    final List<MatchRecord> linkedMatches = _linkedMatchRecords();
    final bool showSideboardPlans =
        widget.mode == DeckSectionMode.sideboardPlans;
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
          title: Text(
            txt.t(showSideboardPlans ? 'section.sideboardPlans' : 'section.matchupHistory'),
          ),
          leading: IconButton(
            onPressed: _closeWithResult,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          actions: showSideboardPlans
              ? <Widget>[
                  IconButton(
                    tooltip: 'Add matchup',
                    onPressed: _addMatchup,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ]
              : const <Widget>[],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          children: [
            if (showSideboardPlans) ...[
              _buildSideboardPlansControls(txt),
              if (sortedMatchups.isEmpty)
                Card(
                  color: const Color(0xFF1E1B1B),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      'No sideboard plans yet. Tap + to add one.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.74),
                      ),
                    ),
                  ),
                )
              else
                ...sortedMatchups.map((SideboardMatchup matchup) {
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
                }),
            ] else ...[
              if (linkedMatches.isEmpty)
                Card(
                  color: const Color(0xFF1E1B1B),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      'No saved matches for this deck yet.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.74),
                      ),
                    ),
                  ),
                )
              else
                ...linkedMatches.map((MatchRecord match) {
                  final String opponent =
                      match.metadata.opponentName.trim().isEmpty
                      ? '-'
                      : match.metadata.opponentName.trim();
                  final String opponentDeck =
                      match.metadata.opponentDeckName.trim().isEmpty
                      ? '-'
                      : match.metadata.opponentDeckName.trim();
                  final String resultLabel = matchAggregateResultLabel(
                    match.aggregateResult,
                  );
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    color: const Color(0xFF1E1B1B),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  match.metadata.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
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
                                    resultLabel,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  resultLabel,
                                  style: TextStyle(
                                    color: _matchResultTextColor(resultLabel),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatDateTime(match.createdAt, context),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Opponent: $opponent',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.82),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Opponent Deck: $opponentDeck',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${match.games.length} game${match.games.length == 1 ? '' : 's'}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ],
        ),
      ),
    );
  }
}
