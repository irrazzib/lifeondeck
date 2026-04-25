import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../l10n/app_strings.dart';
import '../../models/game_record.dart';
import '../../models/match.dart';
import '../../models/sideboard.dart';
import '../../widgets/clearable_text_field.dart';
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

  Future<String?> _promptText({
    required String title,
    required String initialValue,
    required String hintText,
    int maxLines = 1,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return TextPromptDialog(
          title: title,
          initialValue: initialValue,
          hintText: hintText,
          maxLines: maxLines,
        );
      },
    );
  }

  SideboardDeck? _deckById(String deckId) {
    final String trimmedId = deckId.trim();
    if (trimmedId.isEmpty) {
      return null;
    }
    for (final SideboardDeck deck in widget.decks) {
      if (deck.id == trimmedId) {
        return deck;
      }
    }
    return null;
  }

  SideboardDeck? _deckByName(String deckName) {
    return findUniqueDeckByName(widget.decks, deckName);
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
    final TextEditingController matchNameController = TextEditingController(
      text: _effectiveMatchName(),
    );
    final TextEditingController opponentController = TextEditingController(
      text: _metadata.opponentName,
    );
    final TextEditingController tagController = TextEditingController(
      text: _metadata.tag,
    );
    String selectedDeckId = _metadata.deckId.trim();
    if (selectedDeckId.isEmpty && _metadata.deckName.trim().isNotEmpty) {
      selectedDeckId = _deckByName(_metadata.deckName)?.id ?? '';
    }
    if (selectedDeckId.isNotEmpty && _deckById(selectedDeckId) == null) {
      selectedDeckId = '';
    }
    String customDeckName = (selectedDeckId.isEmpty &&
            _metadata.deckName.trim().isNotEmpty)
        ? _metadata.deckName.trim()
        : '';
    DateTime selectedMatchDate = _metadata.matchDate ?? DateTime.now();
    String selectedFormat = _metadata.format.trim();
    String selectedOpponentDeckId = _metadata.opponentDeckId.trim();
    if (selectedOpponentDeckId.isEmpty &&
        _metadata.opponentDeckName.trim().isNotEmpty) {
      selectedOpponentDeckId =
          _deckByName(_metadata.opponentDeckName)?.id ?? '';
    }
    String customOpponentDeckName = (selectedOpponentDeckId.isEmpty &&
            _metadata.opponentDeckName.trim().isNotEmpty)
        ? _metadata.opponentDeckName.trim()
        : '';

    List<String> formatOptions() {
      final Set<String> formats = <String>{};
      for (final SideboardDeck deck in widget.decks) {
        final String format = deck.format.trim();
        if (format.isNotEmpty) {
          formats.add(format);
        }
      }
      for (final GameRecord game in _games) {
        final String format = game.matchFormat.trim();
        if (format.isNotEmpty) {
          formats.add(format);
        }
      }
      if (selectedFormat.trim().isNotEmpty) {
        formats.add(selectedFormat.trim());
      }
      final List<String> sorted = formats.toList(growable: false);
      sorted.sort((String a, String b) {
        return a.toLowerCase().compareTo(b.toLowerCase());
      });
      return sorted;
    }

    List<SideboardDeck> opponentDeckOptions() {
      return filterDecksByFormat(widget.decks, selectedFormat);
    }

    List<SideboardDeck> deckOptions() {
      return filterDecksByFormat(widget.decks, selectedFormat);
    }

    void normalizeSelectedDeck() {
      if (selectedDeckId.isEmpty) {
        return;
      }
      final SideboardDeck? selectedDeck = _deckById(selectedDeckId);
      if (selectedDeck == null ||
          !deckMatchesFormat(selectedDeck, selectedFormat)) {
        selectedDeckId = '';
      }
    }

    void normalizeSelectedOpponentDeck() {
      if (selectedOpponentDeckId.isEmpty) {
        return;
      }
      final SideboardDeck? selectedOpponentDeck = _deckById(
        selectedOpponentDeckId,
      );
      if (selectedOpponentDeck == null ||
          !deckMatchesFormat(selectedOpponentDeck, selectedFormat)) {
        selectedOpponentDeckId = '';
      }
    }

    normalizeSelectedDeck();
    normalizeSelectedOpponentDeck();

    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(context.txt.t('dialog.matchDetails')),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClearableTextField(
                      controller: matchNameController,
                      decoration: InputDecoration(
                        labelText: context.txt.t('field.matchName'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClearableTextField(
                      controller: opponentController,
                      decoration: const InputDecoration(
                        labelText: 'Opponent',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedFormat.isEmpty
                          ? null
                          : selectedFormat,
                      decoration: InputDecoration(
                        labelText: context.txt.t('field.format'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(
                          value: '',
                          child: Text(context.txt.t('field.noFormat')),
                        ),
                        ...formatOptions().map((String format) {
                          return DropdownMenuItem<String>(
                            value: format,
                            child: Text(format),
                          );
                        }),
                        DropdownMenuItem<String>(
                          value: '__add_format__',
                          child: Text(context.txt.t('field.addNewFormat')),
                        ),
                      ],
                      onChanged: (String? nextValue) async {
                        if (nextValue == null) {
                          return;
                        }
                        if (nextValue == '__add_format__') {
                          final String? created = await _promptText(
                            title: 'New format',
                            initialValue: '',
                            hintText: 'Modern, Edison, Commander...',
                          );
                          if (created == null) {
                            return;
                          }
                          final String trimmed = created.trim();
                          if (trimmed.isEmpty) {
                            return;
                          }
                          setDialogState(() {
                            selectedFormat = trimmed;
                            normalizeSelectedDeck();
                            normalizeSelectedOpponentDeck();
                          });
                          return;
                        }
                        setDialogState(() {
                          selectedFormat = nextValue.trim();
                          normalizeSelectedDeck();
                          normalizeSelectedOpponentDeck();
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      key: ValueKey<String>(
                        'deck_${selectedDeckId}_$customDeckName',
                      ),
                      initialValue: selectedDeckId.isNotEmpty
                          ? selectedDeckId
                          : (customDeckName.isNotEmpty
                                ? '__custom_deck__'
                                : null),
                      decoration: InputDecoration(
                        labelText: context.txt.t('field.deck'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(
                          value: '',
                          child: Text(context.txt.t('field.noDeck')),
                        ),
                        ...deckOptions().map((SideboardDeck deck) {
                          return DropdownMenuItem<String>(
                            value: deck.id,
                            child: Text(
                              deck.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                        if (customDeckName.isNotEmpty)
                          DropdownMenuItem<String>(
                            value: '__custom_deck__',
                            child: Text(
                              customDeckName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        DropdownMenuItem<String>(
                          value: '__add_deck__',
                          child: Text(context.txt.t('field.addNewDeck')),
                        ),
                      ],
                      onChanged: (String? nextValue) async {
                        if (nextValue == '__add_deck__') {
                          final String? created = await _promptText(
                            title: context.txt.t('field.addNewDeck'),
                            initialValue: customDeckName,
                            hintText: context.txt.t('field.deckName'),
                          );
                          if (created == null) {
                            return;
                          }
                          final String trimmed = created.trim();
                          if (trimmed.isEmpty) {
                            return;
                          }
                          setDialogState(() {
                            selectedDeckId = '';
                            customDeckName = trimmed;
                          });
                          return;
                        }
                        if (nextValue == '__custom_deck__') {
                          return;
                        }
                        setDialogState(() {
                          selectedDeckId = (nextValue ?? '').trim();
                          customDeckName = '';
                          normalizeSelectedDeck();
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      key: ValueKey<String>(
                        'opp_deck_${selectedOpponentDeckId}_$customOpponentDeckName',
                      ),
                      initialValue: selectedOpponentDeckId.isNotEmpty
                          ? selectedOpponentDeckId
                          : (customOpponentDeckName.isNotEmpty
                                ? '__custom_opp_deck__'
                                : null),
                      decoration: InputDecoration(
                        labelText: context.txt.t('field.opponentDeck'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(
                          value: '',
                          child: Text(context.txt.t('field.noOpponentDeck')),
                        ),
                        ...opponentDeckOptions().map((SideboardDeck deck) {
                          return DropdownMenuItem<String>(
                            value: deck.id,
                            child: Text(
                              deck.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                        if (customOpponentDeckName.isNotEmpty)
                          DropdownMenuItem<String>(
                            value: '__custom_opp_deck__',
                            child: Text(
                              customOpponentDeckName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        DropdownMenuItem<String>(
                          value: '__add_deck__',
                          child: Text(context.txt.t('field.addNewDeck')),
                        ),
                      ],
                      onChanged: (String? nextValue) async {
                        if (nextValue == '__add_deck__') {
                          final String? created = await _promptText(
                            title: context.txt.t('field.addNewDeck'),
                            initialValue: customOpponentDeckName,
                            hintText: context.txt.t('field.deckName'),
                          );
                          if (created == null) {
                            return;
                          }
                          final String trimmed = created.trim();
                          if (trimmed.isEmpty) {
                            return;
                          }
                          setDialogState(() {
                            selectedOpponentDeckId = '';
                            customOpponentDeckName = trimmed;
                          });
                          return;
                        }
                        if (nextValue == '__custom_opp_deck__') {
                          return;
                        }
                        setDialogState(() {
                          selectedOpponentDeckId = (nextValue ?? '').trim();
                          customOpponentDeckName = '';
                          normalizeSelectedOpponentDeck();
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    ClearableTextField(
                      controller: tagController,
                      decoration: const InputDecoration(
                        labelText: 'Tag',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () async {
                        final DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedMatchDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(
                            const Duration(days: 1),
                          ),
                        );
                        if (pickedDate == null) {
                          return;
                        }
                        final TimeOfDay? pickedTime = await showTimePicker(
                          context: context, // ignore: use_build_context_synchronously
                          initialTime: TimeOfDay.fromDateTime(
                            selectedMatchDate,
                          ),
                        );
                        setDialogState(() {
                          selectedMatchDate = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime?.hour ?? selectedMatchDate.hour,
                            pickedTime?.minute ?? selectedMatchDate.minute,
                          );
                        });
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: context.txt.t('field.date'),
                          border: const OutlineInputBorder(),
                          isDense: true,
                          suffixIcon: const Icon(
                            Icons.calendar_today_rounded,
                            size: 18,
                          ),
                        ),
                        child: Text(
                          formatDateTime(selectedMatchDate, context),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.txt.t('common.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.txt.t('common.save')),
            ),
          ],
        );
      },
    );

    if (shouldSave != true) {
      disposeTextControllersLater(<TextEditingController>[
        matchNameController,
        opponentController,
        tagController,
      ]);
      return;
    }

    if (!mounted) {
      disposeTextControllersLater(<TextEditingController>[
        matchNameController,
        opponentController,
        tagController,
      ]);
      return;
    }

    final SideboardDeck? selectedDeck = _deckById(selectedDeckId);
    final SideboardDeck? selectedOpponentDeck = _deckById(
      selectedOpponentDeckId,
    );
    _applyMatchMetadata(
      _metadata.copyWith(
        name: matchNameController.text.trim(),
        opponentName: opponentController.text.trim(),
        deckId: selectedDeck?.id ?? '',
        deckName: selectedDeck?.name ?? customDeckName,
        format: selectedFormat,
        opponentDeckId: selectedOpponentDeck?.id ?? '',
        opponentDeckName: selectedOpponentDeck?.name ?? customOpponentDeckName,
        tag: tagController.text.trim(),
        matchDate: selectedMatchDate,
      ),
    );
    disposeTextControllersLater(<TextEditingController>[
      matchNameController,
      opponentController,
      tagController,
    ]);
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
    String stage = supportedGameStages.contains(record.gameStage)
        ? record.gameStage
        : 'G1';
    String result = _selectedMatchResult(record);

    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(context.txt.t('dialog.gameDetails')),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: stage,
                      decoration: const InputDecoration(
                        labelText: 'Game',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: supportedGameStages
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
                        ...supportedMatchResults.map((String item) {
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
              child: Text(context.txt.t('common.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.txt.t('common.save')),
            ),
          ],
        );
      },
    );

    if (shouldSave != true) {
      return;
    }

    _updateGame(record.copyWith(gameStage: stage, matchResult: result));
  }

  Future<void> _editNotes(GameRecord record) async {
    final String? result = await _promptText(
      title: 'Edit game notes',
      initialValue: record.notes,
      hintText: 'Write some notes...',
      maxLines: 6,
    );
    if (result == null) {
      return;
    }
    _updateGame(record.copyWith(notes: result.trim()));
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

