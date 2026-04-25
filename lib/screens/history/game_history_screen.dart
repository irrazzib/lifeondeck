import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../l10n/app_strings.dart';
import '../../models/game_record.dart';
import '../../models/match.dart';
import '../../models/sideboard.dart';
import '../../widgets/searchable_combo_field.dart';
import '../../widgets/match_editor_dialog.dart';
import '../../widgets/text_prompt_dialog.dart';
import 'match_detail_screen.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import '../../core/ux_state.dart';

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
  static const int _matchPageSize = 5;

  late List<GameRecord> _records;
  MatchHistorySortMode _matchHistorySortMode = MatchHistorySortMode.date;
  String _selectedMatchDeckFilter = '';
  String _selectedMatchOpponentDeckFilter = '';
  String _selectedMatchFormatFilter = '';
  String _selectedMatchTagFilter = '';
  late final ScrollController _matchListController;
  late final TextEditingController _opponentNameFilterController;
  int _visibleMatchCount = _matchPageSize;
  bool _filtersExpanded = true;

  @override
  void initState() {
    super.initState();
    _matchListController = ScrollController();
    _opponentNameFilterController = TextEditingController();
    _records = List<GameRecord>.from(widget.records);
    _records.sort((GameRecord a, GameRecord b) {
      return b.createdAt.compareTo(a.createdAt);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        showInfoTipOnce(
          context: context,
          tipId: InfoTipIds.matchHistory,
          titleKey: 'info.matchHistory.title',
          bodyKey: 'info.matchHistory.body',
          icon: Icons.history_rounded,
        ),
      );
    });
  }

  void _loadMoreMatches(int totalMatches) {
    setState(() {
      _visibleMatchCount = min(
        totalMatches,
        _visibleMatchCount + _matchPageSize,
      );
    });
  }

  void _resetVisibleMatchCount() {
    _visibleMatchCount = _matchPageSize;
  }

  bool _isPersistedHistoryRecord(GameRecord record) {
    return record.lifePointHistory.isNotEmpty ||
        normalizedMatchResultOrEmpty(record.matchResult).isNotEmpty;
  }

  void _closeWithResult() {
    Navigator.of(context).pop(_records);
  }

  bool get _hasActiveMatchFilters {
    return _selectedMatchDeckFilter.isNotEmpty ||
        _selectedMatchOpponentDeckFilter.isNotEmpty ||
        _selectedMatchFormatFilter.isNotEmpty ||
        _selectedMatchTagFilter.isNotEmpty ||
        _opponentNameFilterController.text.trim().isNotEmpty;
  }

  void _clearMatchFilters() {
    _opponentNameFilterController.clear();
    setState(() {
      _selectedMatchDeckFilter = '';
      _selectedMatchOpponentDeckFilter = '';
      _selectedMatchFormatFilter = '';
      _selectedMatchTagFilter = '';
      _resetVisibleMatchCount();
    });
  }

  @override
  void dispose() {
    _opponentNameFilterController.dispose();
    _matchListController.dispose();
    super.dispose();
  }

  bool get _isTwoPlayerHistoryOnly {
    return _records.isNotEmpty &&
        _records.every((GameRecord record) => record.playerCount == 2);
  }

  String _defaultMatchName(int number) {
    final String prefix = widget.tcg == SupportedTcg.mtg
        ? context.txt.t('history.mtgMatchPrefix')
        : context.txt.t('history.matchPrefix');
    return '$prefix $number';
  }

  String _effectiveMatchId(GameRecord record) {
    final String rawMatchId = record.matchId.trim();
    if (rawMatchId.isNotEmpty) {
      return rawMatchId;
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

  String _matchDeckFilterValue({
    required String deckId,
    required String deckName,
  }) {
    final String trimmedId = deckId.trim();
    final String trimmedName = deckName.trim();
    if (trimmedId.isNotEmpty) {
      return 'id:$trimmedId';
    }
    if (trimmedName.isNotEmpty) {
      return 'name:${trimmedName.toLowerCase()}';
    }
    return '';
  }

  List<FilterOption> _matchDeckOptions(
    List<MatchRecord> matches, {
    required bool opponentDeck,
  }) {
    final Map<String, String> values = <String, String>{};
    for (final MatchRecord match in matches) {
      final String deckId = opponentDeck
          ? match.metadata.opponentDeckId
          : match.metadata.deckId;
      final String deckName = opponentDeck
          ? match.metadata.opponentDeckName
          : match.metadata.deckName;
      final String value = _matchDeckFilterValue(
        deckId: deckId,
        deckName: deckName,
      );
      final String label = deckName.trim().isNotEmpty
          ? deckName.trim()
          : deckId.trim();
      if (value.isEmpty || label.isEmpty) {
        continue;
      }
      values.putIfAbsent(value, () => label);
    }
    final List<FilterOption> options = values.entries
        .map(
          (MapEntry<String, String> entry) =>
              FilterOption(value: entry.key, label: entry.value),
        )
        .toList(growable: false);
    options.sort(((FilterOption a, FilterOption b) {
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    }));
    return options;
  }

  List<String> _availableMatchFormats(List<MatchRecord> matches) {
    final Set<String> unique = <String>{};
    for (final MatchRecord match in matches) {
      final String format = match.metadata.format.trim();
      if (format.isEmpty) {
        continue;
      }
      unique.add(format);
    }
    final List<String> sorted = unique.toList(growable: false);
    sorted.sort((String a, String b) {
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
    return sorted;
  }

  bool _matchesDeckFilter(
    MatchRecord match,
    String selectedValue, {
    required bool opponentDeck,
  }) {
    final String trimmedValue = selectedValue.trim();
    if (trimmedValue.isEmpty) {
      return true;
    }
    final String value = _matchDeckFilterValue(
      deckId: opponentDeck
          ? match.metadata.opponentDeckId
          : match.metadata.deckId,
      deckName: opponentDeck
          ? match.metadata.opponentDeckName
          : match.metadata.deckName,
    );
    return value == trimmedValue;
  }

  List<MatchRecord> _filteredMatchRecords(
    List<MatchRecord> matches, {
    required String selectedDeckFilter,
    required String selectedOpponentDeckFilter,
    required String selectedFormatFilter,
    required String selectedTagFilter,
    required String opponentQuery,
  }) {
    final String normalizedFormat = selectedFormatFilter.trim().toLowerCase();
    final String normalizedTag = selectedTagFilter.trim().toLowerCase();
    final String normalizedOpponentQuery = opponentQuery.trim().toLowerCase();

    return matches
        .where((MatchRecord match) {
          if (!_matchesDeckFilter(
            match,
            selectedDeckFilter,
            opponentDeck: false,
          )) {
            return false;
          }
          if (!_matchesDeckFilter(
            match,
            selectedOpponentDeckFilter,
            opponentDeck: true,
          )) {
            return false;
          }
          if (normalizedFormat.isNotEmpty &&
              match.metadata.format.trim().toLowerCase() != normalizedFormat) {
            return false;
          }
          if (normalizedTag.isNotEmpty &&
              match.metadata.tag.trim().toLowerCase() != normalizedTag) {
            return false;
          }
          if (normalizedOpponentQuery.isNotEmpty &&
              !match.metadata.opponentName.trim().toLowerCase().contains(
                normalizedOpponentQuery,
              )) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  List<MatchRecord> _twoPlayerMatchRecords() {
    final List<GameRecord> twoPlayerRecords = _records
        .where(
          (GameRecord record) =>
              record.playerCount == 2 && _isPersistedHistoryRecord(record),
        )
        .toList(growable: false);
    if (twoPlayerRecords.isEmpty) {
      return const <MatchRecord>[];
    }

    final Map<String, List<GameRecord>> grouped = <String, List<GameRecord>>{};
    for (final GameRecord record in twoPlayerRecords) {
      final String matchId = _effectiveMatchId(record);
      grouped.putIfAbsent(matchId, () => <GameRecord>[]).add(record);
    }

    final List<MapEntry<String, List<GameRecord>>> groupedEntries = grouped
        .entries
        .toList(growable: false);
    groupedEntries.sort((
      MapEntry<String, List<GameRecord>> a,
      MapEntry<String, List<GameRecord>> b,
    ) {
      final DateTime aCreated = a.value
          .map((GameRecord record) => record.createdAt)
          .reduce(
            (DateTime first, DateTime next) =>
                first.isBefore(next) ? first : next,
          );
      final DateTime bCreated = b.value
          .map((GameRecord record) => record.createdAt)
          .reduce(
            (DateTime first, DateTime next) =>
                first.isBefore(next) ? first : next,
          );
      return aCreated.compareTo(bCreated);
    });

    final List<MatchRecord> matches = <MatchRecord>[];
    int fallbackNumber = 0;
    for (final MapEntry<String, List<GameRecord>> entry in groupedEntries) {
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
      fallbackNumber += 1;

      String matchName = '';
      for (final GameRecord game in games) {
        final String candidate = game.matchName.trim();
        if (candidate.isNotEmpty) {
          matchName = candidate;
          break;
        }
      }
      if (matchName.isEmpty) {
        matchName = _defaultMatchName(fallbackNumber);
      }

      final DateTime createdAt = games
          .map((GameRecord record) => record.createdAt)
          .reduce(
            (DateTime first, DateTime next) =>
                first.isBefore(next) ? first : next,
          );
      final DateTime updatedAt = games
          .map((GameRecord record) => record.createdAt)
          .reduce(
            (DateTime first, DateTime next) =>
                first.isAfter(next) ? first : next,
          );
      final String opponent = _firstNonEmptyFromNewest(games, (
        GameRecord game,
      ) {
        final String rawOpponent = game.opponentName.trim();
        if (rawOpponent.isNotEmpty) {
          return rawOpponent;
        }
        return game.playerTwoName.trim();
      });
      final String deckId = _firstNonEmptyFromNewest(
        games,
        (GameRecord game) => _resolvedDeckId(game),
      );
      final String deckName = _firstNonEmptyFromNewest(
        games,
        (GameRecord game) => _resolvedDeckName(game),
      );
      final String opponentDeckId = _firstNonEmptyFromNewest(
        games,
        (GameRecord game) => _resolvedOpponentDeckId(game),
      );
      final String opponentDeckName = _firstNonEmptyFromNewest(
        games,
        (GameRecord game) => _resolvedOpponentDeckName(game),
      );
      final String matchFormat = _firstNonEmptyFromNewest(
        games,
        (GameRecord game) => game.matchFormat.trim(),
      );
      final String tag = _firstNonEmptyFromNewest(
        games,
        (GameRecord game) => game.matchTag.trim(),
      );
      DateTime? matchDate;
      for (int i = games.length - 1; i >= 0; i--) {
        final String raw = games[i].matchDate.trim();
        if (raw.isNotEmpty) {
          matchDate = DateTime.tryParse(raw);
          if (matchDate != null) {
            break;
          }
        }
      }
      final MatchMetadata metadata = MatchMetadata(
        name: matchName,
        opponentName: opponent,
        deckId: deckId,
        deckName: deckName,
        opponentDeckId: opponentDeckId,
        opponentDeckName: opponentDeckName,
        format: matchFormat,
        tag: tag,
        matchDate: matchDate,
      );

      final DateTime effectiveCreatedAt = matchDate ?? createdAt;
      matches.add(
        MatchRecord(
          id: entry.key,
          tcgKey: widget.tcg.storageKey,
          metadata: metadata,
          createdAt: effectiveCreatedAt,
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

  List<MatchRecord> _sortedMatchRecords(List<MatchRecord> matches) {
    final List<MatchRecord> sorted = List<MatchRecord>.from(matches);
    switch (_matchHistorySortMode) {
      case MatchHistorySortMode.date:
        sorted.sort((MatchRecord a, MatchRecord b) {
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
      case MatchHistorySortMode.name:
        sorted.sort((MatchRecord a, MatchRecord b) {
          return a.metadata.name.toLowerCase().compareTo(
            b.metadata.name.toLowerCase(),
          );
        });
        break;
    }
    return sorted;
  }

  Future<void> _openMatchGroup(MatchRecord match) async {
    final List<GameRecord>? updatedGames = await Navigator.of(context)
        .push<List<GameRecord>>(
          MaterialPageRoute<List<GameRecord>>(
            builder: (_) => TwoPlayerMatchDetailScreen(
              tcg: widget.tcg,
              decks: widget.decks,
              match: match,
            ),
          ),
        );
    if (updatedGames == null) {
      return;
    }

    final Set<String> oldIds = match.games
        .map((GameRecord record) => record.id)
        .toSet();
    setState(() {
      _records = _records
          .where((GameRecord record) => !oldIds.contains(record.id))
          .toList(growable: false);
      _records = <GameRecord>[...updatedGames, ..._records];
      _records.sort((GameRecord a, GameRecord b) {
        return b.createdAt.compareTo(a.createdAt);
      });
    });
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

  SideboardDeck? _deckByName(String deckName) {
    return findUniqueDeckByName(widget.decks, deckName);
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
    final SideboardDeck? linked = _deckByName(record.deckName);
    return linked?.id ?? '';
  }

  String _resolvedOpponentDeckName(GameRecord record) {
    final SideboardDeck? linkedDeck = _deckById(record.opponentDeckId);
    if (linkedDeck != null) {
      return linkedDeck.name;
    }
    return record.opponentDeckName.trim();
  }

  String _resolvedOpponentDeckId(GameRecord record) {
    final String currentId = record.opponentDeckId.trim();
    if (currentId.isNotEmpty && _deckById(currentId) != null) {
      return currentId;
    }
    final SideboardDeck? linked = _deckByName(record.opponentDeckName);
    return linked?.id ?? '';
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

  Future<void> _editMatchDetails(GameRecord record) async {
    final MatchEditorResult? result = await showMatchEditorDialog(
      context,
      title: context.txt.t('dialog.matchDetails'),
      input: MatchEditorInput(
        decks: widget.decks,
        opponentName: record.opponentName,
        deckId: _resolvedDeckId(record),
        deckName: _resolvedDeckName(record),
        gameStage: record.gameStage,
        result: _selectedMatchResult(record),
        showMatchName: false,
        showFormat: false,
        showOpponentDeck: false,
        showTag: false,
        showDeck: true,
        showGameStage: true,
        showResult: true,
      ),
    );
    if (result == null) {
      return;
    }
    _updateRecord(
      record.copyWith(
        opponentName: result.opponentName,
        playerTwoName: result.opponentName.isEmpty
            ? record.playerTwoName
            : result.opponentName,
        deckId: result.deckId,
        deckName: result.deckName,
        gameStage: result.gameStage,
        matchResult: result.result,
      ),
    );
  }

  String _buildHistoryExportText() {
    final List<Map<String, Object>> serializedRecords = _records
        .map((GameRecord record) {
          return record
              .copyWith(
                tcgKey: widget.tcg.storageKey,
                deckName: _resolvedDeckName(record),
                opponentDeckName: _resolvedOpponentDeckName(record),
              )
              .toJson();
        })
        .toList(growable: false);

    final Map<String, Object> payload = <String, Object>{
      'schema': historyExportSchema,
      'exportedAt': DateTime.now().toIso8601String(),
      'tcg': widget.tcg.storageKey,
      'records': serializedRecords,
    };

    return '$historyExportSchema\n'
        '${const JsonEncoder.withIndent('  ').convert(payload)}';
  }

  List<GameRecord> _parseHistoryImportText(String rawText) {
    String payloadText = rawText.trim();
    if (payloadText.isEmpty) {
      throw const FormatException('Empty input');
    }

    if (payloadText.startsWith(historyExportSchema)) {
      payloadText = payloadText.substring(historyExportSchema.length).trim();
    }

    final dynamic decoded = jsonDecode(payloadText);
    if (decoded is! Map) {
      throw const FormatException('Invalid history payload');
    }
    final Map<String, dynamic> payload = Map<String, dynamic>.from(decoded);
    final String? payloadTcgKey = supportedTcgKeyOrNull(payload['tcg']);
    if (payload['tcg'] != null && payloadTcgKey == null) {
      throw const FormatException(
        'Import failed. Unsupported game in history file.',
      );
    }
    if (payloadTcgKey != null && payloadTcgKey != widget.tcg.storageKey) {
      final String tcgLabel = SupportedTcgX.fromStorageKey(payloadTcgKey).label;
      throw FormatException(
        'This history file belongs to $tcgLabel. Import it from that game history.',
      );
    }
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
          title: Text(context.txt.t('history.exportDialogTitle')),
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
                  SnackBar(
                    content: Text(
                      this.context.txt.t('history.exportCopied'),
                    ),
                  ),
                );
              },
              child: Text(context.txt.t('common.copy')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.txt.t('common.close')),
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
          title: Text(context.txt.t('history.importDialogTitle')),
          content: SizedBox(
            width: double.maxFinite,
            child: TextField(
              controller: textController,
              maxLines: 14,
              minLines: 8,
              decoration: InputDecoration(
                hintText: context.txt.t('history.importHint'),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.txt.t('common.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.txt.t('common.import')),
            ),
          ],
        );
      },
    );

    final String rawInput = textController.text.trim();
    disposeTextControllersLater(<TextEditingController>[textController]);
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
          SnackBar(content: Text(context.txt.t('history.noValidRecords'))),
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
        SnackBar(content: Text(context.txt.t('history.importedCount', params: <String, Object?>{'count': imported.length}))),
      );
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      final String message = error.message.trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message.isEmpty
                ? context.txt.t('history.importFailed')
                : message,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.txt.t('history.importFailed')),
        ),
      );
    }
  }

  Future<void> _renameRecord(GameRecord record) async {
    final String? result = await showTextPromptDialog(
      context,
      title: context.txt.t('history.renameGame'),
      initialValue: record.title,
      hintText: context.txt.t('history.gameNameHint'),
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
    final GameRecord? updated = await showNotesEditDialog(context, record);
    if (updated != null) _updateRecord(updated);
  }

  Future<void> _deleteRecord(GameRecord record) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(context.txt.t('history.deleteGame')),
          content: Text(context.txt.t('history.deleteGameConfirm', params: <String, Object?>{'title': record.title})),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.txt.t('common.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.txt.t('common.delete')),
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

  Future<void> _createManualRecord() async {
    final DateTime now = DateTime.now();
    final Set<String> twoPlayerMatchIds = _records
        .where((GameRecord record) => record.playerCount == 2)
        .map((GameRecord record) => _effectiveMatchId(record))
        .toSet();
    final String matchId = 'manual-match-${now.microsecondsSinceEpoch}';
    final String defaultMatchName = _defaultMatchName(
      twoPlayerMatchIds.length + 1,
    );
    const List<String> gameStageLabels = <String>['G1', 'G2', 'G3'];
    final List<String> gameResults = <String>['', '', ''];

    final MatchEditorResult? result = await showMatchEditorDialog(
      context,
      title: context.txt.t('history.addMatch'),
      input: MatchEditorInput(
        decks: widget.decks,
        matchName: defaultMatchName,
        showMatchName: true,
        showOpponent: true,
        showFormat: false,
        showDeck: true,
        showOpponentDeck: true,
        showTag: false,
        showDate: true,
        showGameStage: false,
        showResult: false,
      ),
      extraContentBuilder: (StateSetter setDialogState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 14),
            Text(
              context.txt.t('history.games'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            for (int i = 0; i < 3; i++) ...<Widget>[
              Row(
                children: <Widget>[
                  SizedBox(
                    width: 28,
                    child: Text(
                      gameStageLabels[i],
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SearchableComboField(
                      value: gameResults[i],
                      decoration: const InputDecoration(
                        labelText: 'Result',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      fixedItems: <ComboItem>[
                        ComboItem(value: '', label: context.txt.t('history.gameResultNone')),
                      ],
                      items: supportedMatchResults
                          .map((String s) => ComboItem(value: s, label: s))
                          .toList(growable: false),
                      onChanged: (String nextValue) {
                        setDialogState(() {
                          gameResults[i] = nextValue.trim();
                        });
                      },
                    ),
                  ),
                ],
              ),
              if (i < 2) const SizedBox(height: 8),
            ],
          ],
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    final bool anyResult = gameResults.any((String r) => r.isNotEmpty);
    if (!anyResult) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.txt.t('history.atLeastOneResult')),
        ),
      );
      return;
    }

    final DateTime selectedDate = result.matchDate ?? now;
    final String effectiveMatchName = result.matchName.isNotEmpty
        ? result.matchName
        : defaultMatchName;
    final String opponentText = result.opponentName;
    final String gamePrefix = widget.tcg == SupportedTcg.mtg
        ? context.txt.t('history.mtgGamePrefix')
        : context.txt.t('history.gamePrefix');

    final List<GameRecord> newRecords = <GameRecord>[];
    for (int i = 0; i < 3; i++) {
      final String gameResult = gameResults[i];
      if (gameResult.isEmpty) {
        continue;
      }
      newRecords.add(
        GameRecord(
          id: '${now.microsecondsSinceEpoch}_g${i + 1}',
          title: '$gamePrefix ${_records.length + newRecords.length + 1}',
          createdAt: selectedDate.add(Duration(seconds: i)),
          gameStage: gameStageLabels[i],
          notes: '',
          lifePointHistory: const <String>[],
          tcgKey: widget.tcg.storageKey,
          deckId: result.deckId,
          deckName: result.deckName,
          playerOneName: 'Player 1',
          playerTwoName: opponentText.isNotEmpty ? opponentText : 'Player 2',
          playerCount: 2,
          matchId: matchId,
          matchName: effectiveMatchName,
          opponentName: opponentText,
          opponentDeckId: result.opponentDeckId,
          opponentDeckName: result.opponentDeckName,
          matchTag: '',
          matchResult: gameResult,
          matchDate: selectedDate.toIso8601String(),
        ),
      );
    }

    setState(() {
      _records.insertAll(0, newRecords);
    });
  }

  Future<void> _showLifePointHistory(GameRecord record) async {
    final bool hasHistory = record.lifePointHistory.isNotEmpty;

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${record.title} - ${context.txt.t('game.lpHistory')}'),
          content: SizedBox(
            width: double.maxFinite,
            child: hasHistory
                ? buildLifeHistoryView(
                    lines: record.lifePointHistory,
                    playerCount: record.playerCount,
                    dividerColor: Colors.white.withValues(alpha: 0.14),
                  )
                : Text(context.txt.t('history.noLpHistory')),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.txt.t('common.close')),
            ),
          ],
        );
      },
    );
  }

  List<String> _availableMatchTags(List<MatchRecord> matches) {
    final Set<String> unique = <String>{};
    for (final MatchRecord match in matches) {
      final String tag = match.metadata.tag.trim();
      if (tag.isEmpty) {
        continue;
      }
      unique.add(tag);
    }
    final List<String> sorted = unique.toList(growable: false);
    sorted.sort((String a, String b) {
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
    return sorted;
  }

  Widget _buildAggregateResultBadge(MatchAggregateResult result) {
    final String label = matchAggregateResultLabel(result);
    final Color bg = _matchResultBackgroundColor(label);
    final Color fg = _matchResultTextColor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildTwoPlayerMatchList() {
    final AppStrings txt = context.txt;
    final List<MatchRecord> allMatches = _twoPlayerMatchRecords();
    final List<FilterOption> deckOptions = _matchDeckOptions(
      allMatches,
      opponentDeck: false,
    );
    final List<FilterOption> opponentDeckOptions = _matchDeckOptions(
      allMatches,
      opponentDeck: true,
    );
    final List<String> availableFormats = _availableMatchFormats(allMatches);
    final List<String> availableTags = _availableMatchTags(allMatches);
    final String effectiveSelectedDeckFilter =
        deckOptions.any(
          (FilterOption option) => option.value == _selectedMatchDeckFilter,
        )
        ? _selectedMatchDeckFilter
        : '';
    final String effectiveSelectedOpponentDeckFilter =
        opponentDeckOptions.any(
          (FilterOption option) =>
              option.value == _selectedMatchOpponentDeckFilter,
        )
        ? _selectedMatchOpponentDeckFilter
        : '';
    final String effectiveSelectedFormatFilter =
        _selectedMatchFormatFilter.isNotEmpty &&
            availableFormats.contains(_selectedMatchFormatFilter)
        ? _selectedMatchFormatFilter
        : '';
    final String effectiveSelectedTagFilter =
        _selectedMatchTagFilter.isNotEmpty &&
            availableTags.contains(_selectedMatchTagFilter)
        ? _selectedMatchTagFilter
        : '';
    final List<MatchRecord> matches = _sortedMatchRecords(
      _filteredMatchRecords(
        allMatches,
        selectedDeckFilter: effectiveSelectedDeckFilter,
        selectedOpponentDeckFilter: effectiveSelectedOpponentDeckFilter,
        selectedFormatFilter: effectiveSelectedFormatFilter,
        selectedTagFilter: effectiveSelectedTagFilter,
        opponentQuery: _opponentNameFilterController.text,
      ),
    );
    if (matches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _hasActiveMatchFilters
                    ? txt.t('history.noMatchesWithFilters')
                    : txt.t('history.empty'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.74)),
              ),
              if (_hasActiveMatchFilters) ...[
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: _clearMatchFilters,
                  icon: const Icon(Icons.filter_alt_off_rounded),
                  label: Text(txt.t('history.clearFilters')),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final int visibleMatchCount = min(matches.length, _visibleMatchCount);
    final bool hasMoreMatches = visibleMatchCount < matches.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: Card(
            color: const Color(0xFF1E1B1B),
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                        child: DropdownButtonFormField<MatchHistorySortMode>(
                          initialValue: _matchHistorySortMode,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: <DropdownMenuItem<MatchHistorySortMode>>[
                            DropdownMenuItem<MatchHistorySortMode>(
                              value: MatchHistorySortMode.date,
                              child: Text(txt.t('history.byDate')),
                            ),
                            DropdownMenuItem<MatchHistorySortMode>(
                              value: MatchHistorySortMode.name,
                              child: Text(txt.t('history.byName')),
                            ),
                          ],
                          onChanged: (MatchHistorySortMode? mode) {
                            if (mode == null) {
                              return;
                            }
                            setState(() {
                              _matchHistorySortMode = mode;
                              _resetVisibleMatchCount();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.tonalIcon(
                        onPressed: _hasActiveMatchFilters
                            ? _clearMatchFilters
                            : null,
                        icon: const Icon(Icons.filter_alt_off_rounded),
                        label: Text(txt.t('history.clearFilters')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: () => setState(
                      () => _filtersExpanded = !_filtersExpanded,
                    ),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Text(
                            txt.t('history.filters'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            _filtersExpanded
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_filtersExpanded) ...[
                  const SizedBox(height: 8),
                  if (deckOptions.isNotEmpty || opponentDeckOptions.isNotEmpty)
                    Row(
                      children: [
                        Expanded(
                          child: SearchableComboField(
                            value: effectiveSelectedDeckFilter,
                            decoration: InputDecoration(
                              labelText: txt.t('field.deck'),
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            fixedItems: <ComboItem>[
                              ComboItem(
                                value: '',
                                label: txt.t('history.allDecks'),
                              ),
                            ],
                            items: deckOptions
                                .map(
                                  (FilterOption o) =>
                                      ComboItem(value: o.value, label: o.label),
                                )
                                .toList(growable: false),
                            onChanged: (String value) {
                              setState(() {
                                _selectedMatchDeckFilter = value.trim();
                                _resetVisibleMatchCount();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SearchableComboField(
                            value: effectiveSelectedOpponentDeckFilter,
                            decoration: InputDecoration(
                              labelText: txt.t('field.opponentDeck'),
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            fixedItems: <ComboItem>[
                              ComboItem(
                                value: '',
                                label: txt.t('history.allOpponentDecks'),
                              ),
                            ],
                            items: opponentDeckOptions
                                .map(
                                  (FilterOption o) =>
                                      ComboItem(value: o.value, label: o.label),
                                )
                                .toList(growable: false),
                            onChanged: (String value) {
                              setState(() {
                                _selectedMatchOpponentDeckFilter = value.trim();
                                _resetVisibleMatchCount();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  if (deckOptions.isNotEmpty || opponentDeckOptions.isNotEmpty)
                    const SizedBox(height: 12),
                  if (availableFormats.isNotEmpty || availableTags.isNotEmpty)
                    Row(
                      children: [
                        if (availableFormats.isNotEmpty)
                          Expanded(
                            child: SearchableComboField(
                              value: effectiveSelectedFormatFilter,
                              decoration: InputDecoration(
                                labelText: txt.t('field.format'),
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                              fixedItems: <ComboItem>[
                                ComboItem(
                                  value: '',
                                  label: txt.t('history.allFormats'),
                                ),
                              ],
                              items: availableFormats
                                  .map(
                                    (String f) =>
                                        ComboItem(value: f, label: f),
                                  )
                                  .toList(growable: false),
                              onChanged: (String value) {
                                setState(() {
                                  _selectedMatchFormatFilter = value.trim();
                                  _resetVisibleMatchCount();
                                });
                              },
                            ),
                          ),
                        if (availableFormats.isNotEmpty &&
                            availableTags.isNotEmpty)
                          const SizedBox(width: 12),
                        if (availableTags.isNotEmpty)
                          Expanded(
                            child: SearchableComboField(
                              value: effectiveSelectedTagFilter,
                              decoration: InputDecoration(
                                labelText: txt.t('field.tag'),
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                              fixedItems: <ComboItem>[
                                ComboItem(
                                  value: '',
                                  label: txt.t('history.allTags'),
                                ),
                              ],
                              items: availableTags
                                  .map(
                                    (String t) =>
                                        ComboItem(value: t, label: t),
                                  )
                                  .toList(growable: false),
                              onChanged: (String value) {
                                setState(() {
                                  _selectedMatchTagFilter = value.trim();
                                  _resetVisibleMatchCount();
                                });
                              },
                            ),
                          ),
                      ],
                    ),
                  if (availableFormats.isNotEmpty || availableTags.isNotEmpty)
                    const SizedBox(height: 12),
                  TextField(
                    controller: _opponentNameFilterController,
                    onChanged: (_) {
                      setState(() {
                        _resetVisibleMatchCount();
                      });
                    },
                    decoration: InputDecoration(
                      labelText: txt.t('history.opponentSearch'),
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon:
                          _opponentNameFilterController.text.trim().isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _opponentNameFilterController.clear();
                                setState(() {
                                  _resetVisibleMatchCount();
                                });
                              },
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
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _matchListController,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: visibleMatchCount + (hasMoreMatches ? 1 : 0),
            itemBuilder: (BuildContext context, int index) {
              if (index >= visibleMatchCount) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: FilledButton.tonal(
                      onPressed: () => _loadMoreMatches(matches.length),
                      child: Text(txt.t('common.loadMore')),
                    ),
                  ),
                );
              }
              final MatchRecord match = matches[index];
              final String opponentLabel = match.metadata.opponentName.isEmpty
                  ? '-'
                  : match.metadata.opponentName;
              final String deckLabel = match.metadata.deckName.isEmpty
                  ? '-'
                  : match.metadata.deckName;
              final String opponentDeckLabel =
                  match.metadata.opponentDeckName.isEmpty
                  ? '-'
                  : match.metadata.opponentDeckName;
              final String formatLabel = match.metadata.format.isEmpty
                  ? '-'
                  : match.metadata.format;
              final String tagLabel = match.metadata.tag.isEmpty
                  ? '-'
                  : match.metadata.tag;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                color: const Color(0xFF1E1B1B),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openMatchGroup(match),
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
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildAggregateResultBadge(match.aggregateResult),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          formatDateTime(match.createdAt, context),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${txt.t('field.opponent')}: $opponentLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.84),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${txt.t('field.deck')}: $deckLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${txt.t('field.opponentDeck')}: $opponentDeckLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${txt.t('field.format')}: $formatLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${txt.t('field.tag')}: $tagLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          txt.t(
                            'field.gamesCount',
                            params: <String, Object?>{
                              'count': match.games.length,
                            },
                          ),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings txt = context.txt;
    final bool twoPlayerOnly = _isTwoPlayerHistoryOnly;
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
          title: Text(txt.t('history.title')),
          leading: IconButton(
            onPressed: _closeWithResult,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          actions: [
            IconButton(
              tooltip: txt.t('history.importTxt'),
              onPressed: _importHistoryTxt,
              icon: const Icon(Icons.upload_file_rounded),
            ),
            IconButton(
              tooltip: txt.t('history.exportTxt'),
              onPressed: _exportHistoryTxt,
              icon: const Icon(Icons.download_rounded),
            ),
            IconButton(
              tooltip: twoPlayerOnly
                  ? txt.t('history.addMatch')
                  : txt.t('history.addGame'),
              onPressed: _createManualRecord,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        body: _records.isEmpty
            ? Center(
                child: Text(
                  txt.t('history.empty'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.74)),
                ),
              )
            : twoPlayerOnly
            ? _buildTwoPlayerMatchList()
            : ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                itemCount: _records.length,
                itemBuilder: (BuildContext context, int index) {
                  final GameRecord record = _records[index];
                  final String dropdownValue =
                      supportedGameStages.contains(record.gameStage)
                      ? record.gameStage
                      : 'G1';
                  final String selectedDeckId = _resolvedDeckId(record);
                  final String selectedResult = _selectedMatchResult(record);
                  final String opponentLabel =
                      record.opponentName.trim().isNotEmpty
                      ? record.opponentName.trim()
                      : (record.playerTwoName.trim().isNotEmpty
                            ? record.playerTwoName.trim()
                            : '-');
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
                                      formatDateTime(record.createdAt, context),
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
                                items: supportedGameStages
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
                                  '${context.txt.t('field.opponent')}: $opponentLabel',
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
                                      context.txt.t('history.resultHint'),
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
                          SearchableComboField(
                            value: selectedDeckId,
                            decoration: InputDecoration(
                              labelText: context.txt.t('field.deck'),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            fixedItems: <ComboItem>[
                              ComboItem(
                                value: '',
                                label: context.txt.t('field.noDeck'),
                              ),
                            ],
                            items: widget.decks
                                .map(
                                  (SideboardDeck d) =>
                                      ComboItem(value: d.id, label: d.name),
                                )
                                .toList(growable: false),
                            onChanged: (String deckId) {
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
                                ? context.txt.t('common.noNotes')
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
                                      label: Text(context.txt.t('common.rename')),
                                    ),
                                    TextButton.icon(
                                      onPressed: () => _editNotes(record),
                                      icon: const Icon(
                                        Icons.sticky_note_2_outlined,
                                        size: 16,
                                      ),
                                      label: Text(context.txt.t('common.notes')),
                                    ),
                                    TextButton.icon(
                                      onPressed: () =>
                                          _editMatchDetails(record),
                                      icon: const Icon(
                                        Icons.edit_note_rounded,
                                        size: 16,
                                      ),
                                      label: Text(context.txt.t('game.details')),
                                    ),
                                    TextButton.icon(
                                      onPressed: () =>
                                          _showLifePointHistory(record),
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
                                tooltip: context.txt.t('history.deleteDuelTooltip'),
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

