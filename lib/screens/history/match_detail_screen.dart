import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../l10n/app_strings.dart';
import '../../models/game_record.dart';
import '../../models/match.dart';
import '../../models/sideboard.dart';
import '../../widgets/match_editor_dialog.dart';
import '../../widgets/text_prompt_dialog.dart';
import '../../core/ux_state.dart';

class TwoPlayerMatchDetailScreen extends StatefulWidget {
  const TwoPlayerMatchDetailScreen({
    required this.tcg,
    required this.decks,
    required this.match,
  });

  final SupportedTcg tcg;
  final List<SideboardDeck> decks;
  final MatchRecord match;

  @override
  State<TwoPlayerMatchDetailScreen> createState() =>
      _TwoPlayerMatchDetailScreenState();
}

class _TwoPlayerMatchDetailScreenState
    extends State<TwoPlayerMatchDetailScreen> {
  late List<GameRecord> _games;
  late MatchMetadata _metadata;

  @override
  void initState() {
    super.initState();
    final String initialName = widget.match.metadata.name.trim().isEmpty
        ? _defaultMatchName()
        : widget.match.metadata.name.trim();
    final DateTime initialMatchDate =
        widget.match.metadata.matchDate ?? widget.match.createdAt;
    _metadata = widget.match.metadata.copyWith(
      name: initialName,
      matchDate: initialMatchDate,
    );
    _games = widget.match.games
        .map((GameRecord game) => _applyMetadataToGame(game))
        .toList(growable: false);
    _sortGames();
  }

  String _defaultMatchName() {
    return widget.tcg == SupportedTcg.mtg ? 'MTG Match' : 'Match';
  }

  void _sortGames() {
    _games.sort((GameRecord a, GameRecord b) {
      final int byStage = gameStageSortKey(
        a.gameStage,
      ).compareTo(gameStageSortKey(b.gameStage));
      if (byStage != 0) {
        return byStage;
      }
      return a.createdAt.compareTo(b.createdAt);
    });
  }

  void _closeWithResult() {
    final List<GameRecord> updated = _games
        .map((GameRecord game) => _applyMetadataToGame(game))
        .toList(growable: false);
    Navigator.of(context).pop(updated);
  }

  String _effectiveMatchName() {
    final String name = _metadata.name.trim();
    return name.isEmpty ? _defaultMatchName() : name;
  }

  GameRecord _applyMetadataToGame(GameRecord game) {
    final String opponent = _metadata.opponentName.trim();
    return game.copyWith(
      matchId: widget.match.id,
      matchName: _effectiveMatchName(),
      opponentName: opponent,
      playerTwoName: opponent.isEmpty ? 'Player 2' : opponent,
      deckId: _metadata.deckId.trim(),
      deckName: _metadata.deckName.trim(),
      opponentDeckId: _metadata.opponentDeckId.trim(),
      opponentDeckName: _metadata.opponentDeckName.trim(),
      matchFormat: _metadata.format.trim(),
      matchTag: _metadata.tag.trim(),
      matchDate: _metadata.matchDate?.toIso8601String() ?? '',
    );
  }

  String _selectedMatchResult(GameRecord record) {
    return normalizedMatchResultOrEmpty(record.matchResult);
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

  void _updateGame(GameRecord updatedGame) {
    final int index = _games.indexWhere(
      (GameRecord game) => game.id == updatedGame.id,
    );
    if (index < 0) {
      return;
    }
    setState(() {
      _games[index] = _applyMetadataToGame(updatedGame);
      _sortGames();
    });
  }

  void _applyMatchMetadata(MatchMetadata metadata) {
    final String normalizedName = metadata.name.trim().isEmpty
        ? _defaultMatchName()
        : metadata.name.trim();
    final MatchMetadata normalized = metadata.copyWith(name: normalizedName);
    setState(() {
      _metadata = normalized;
      _games = _games
          .map((GameRecord game) => _applyMetadataToGame(game))
          .toList(growable: false);
      _sortGames();
    });
  }

  Future<void> _openMatchEditor() async {
    await showInfoTipOnce(
      context: context,
      tipId: InfoTipIds.opponentDeckSelection,
      titleKey: 'info.opponentDeck.title',
      bodyKey: 'info.opponentDeck.body',
      icon: Icons.arrow_drop_down_circle_outlined,
    );
    if (!mounted) {
      return;
    }

    final MatchEditorResult? result = await showMatchEditorDialog(
      context,
      title: context.txt.t('dialog.matchDetails'),
      input: MatchEditorInput(
        decks: widget.decks,
        matchName: _effectiveMatchName(),
        opponentName: _metadata.opponentName,
        format: _metadata.format,
        deckId: _metadata.deckId,
        deckName: _metadata.deckName,
        opponentDeckId: _metadata.opponentDeckId,
        opponentDeckName: _metadata.opponentDeckName,
        tag: _metadata.tag,
        matchDate: _metadata.matchDate,
        showDeck: true,
        showDate: true,
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    _applyMatchMetadata(
      _metadata.copyWith(
        name: result.matchName,
        opponentName: result.opponentName,
        deckId: result.deckId,
        deckName: result.deckName,
        format: result.format,
        opponentDeckId: result.opponentDeckId,
        opponentDeckName: result.opponentDeckName,
        tag: result.tag,
        matchDate: result.matchDate,
      ),
    );
  }

  Widget _buildSummaryRow({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.68),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '-' : value.trim(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editGameDetails(GameRecord record) async {
    final MatchEditorResult? result = await showMatchEditorDialog(
      context,
      title: context.txt.t('dialog.gameDetails'),
      input: MatchEditorInput(
        decks: const <SideboardDeck>[],
        gameStage: record.gameStage,
        result: _selectedMatchResult(record),
        showMatchName: false,
        showOpponent: false,
        showFormat: false,
        showOpponentDeck: false,
        showTag: false,
        showGameStage: true,
        showResult: true,
      ),
    );
    if (result == null) {
      return;
    }
    _updateGame(
      record.copyWith(gameStage: result.gameStage, matchResult: result.result),
    );
  }

  Future<void> _editNotes(GameRecord record) async {
    final GameRecord? updated = await showNotesEditDialog(
      context,
      record,
      title: 'Edit game notes',
    );
    if (updated != null) _updateGame(updated);
  }

  Future<void> _deleteGame(GameRecord record) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete game'),
          content: Text('Delete "${record.title}" from this match?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.txt.t('common.cancel')),
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
      _games = _games
          .where((GameRecord game) => game.id != record.id)
          .toList(growable: false);
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
                ? buildLifeHistoryView(
                    lines: record.lifePointHistory,
                    playerCount: record.playerCount,
                    dividerColor: Colors.white.withValues(alpha: 0.14),
                  )
                : const Text('No life point history saved for this game yet.'),
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
          title: Text(_effectiveMatchName()),
          leading: IconButton(
            onPressed: _closeWithResult,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            Card(
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
                            _effectiveMatchName(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _matchResultBackgroundColor(
                              matchAggregateResultLabel(
                                aggregateMatchResultFromGames(_games),
                              ),
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            matchAggregateResultLabel(
                              aggregateMatchResultFromGames(_games),
                            ),
                            style: TextStyle(
                              color: _matchResultTextColor(
                                matchAggregateResultLabel(
                                  aggregateMatchResultFromGames(_games),
                                ),
                              ),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildSummaryRow(
                      label: context.txt.t('field.opponent'),
                      value: _metadata.opponentName,
                    ),
                    _buildSummaryRow(label: context.txt.t('field.deck'), value: _metadata.deckName),
                    _buildSummaryRow(
                      label: context.txt.t('field.opponentDeck'),
                      value: _metadata.opponentDeckName,
                    ),
                    _buildSummaryRow(label: context.txt.t('field.format'), value: _metadata.format),
                    _buildSummaryRow(label: context.txt.t('field.tag'), value: _metadata.tag),
                    if (_metadata.matchDate != null)
                      _buildSummaryRow(
                        label: context.txt.t('field.date'),
                        value: formatDateTime(_metadata.matchDate!, context),
                      ),
                    const SizedBox(height: 10),
                    Text(
                      'Edit match changes metadata only. Match result is calculated from the game results below.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.tonalIcon(
                        onPressed: _openMatchEditor,
                        icon: const Icon(Icons.edit_note_rounded, size: 18),
                        label: const Text('Edit match'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_games.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'No games in this match.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.74),
                    ),
                  ),
                ),
              )
            else
              ..._games.map((GameRecord game) {
                final String selectedResult = _selectedMatchResult(game);
                final String stage =
                    supportedGameStages.contains(game.gameStage)
                    ? game.gameStage
                    : 'G1';
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
                                '$stage - ${game.title}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
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
                                  items: supportedMatchResults
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
                                    _updateGame(
                                      game.copyWith(matchResult: nextResult),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatDateTime(game.createdAt, context),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          game.notes.trim().isEmpty ? 'No notes' : game.notes,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: game.notes.trim().isEmpty
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
                                    onPressed: () => _editGameDetails(game),
                                    icon: const Icon(
                                      Icons.edit_note_rounded,
                                      size: 16,
                                    ),
                                    label: Text(context.txt.t('game.details')),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => _editNotes(game),
                                    icon: const Icon(
                                      Icons.sticky_note_2_outlined,
                                      size: 16,
                                    ),
                                    label: Text(context.txt.t('common.notes')),
                                  ),
                                  TextButton.icon(
                                    onPressed: () =>
                                        _showLifePointHistory(game),
                                    icon: const Icon(
                                      Icons.format_list_bulleted_rounded,
                                      size: 16,
                                    ),
                                    label: Text(context.txt.t('game.lpHistory')),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Delete game',
                              onPressed: () => _deleteGame(game),
                              icon: const Icon(Icons.delete_outline_rounded),
                              color: const Color(0xFFFF8A8A),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

