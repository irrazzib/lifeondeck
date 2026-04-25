import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/constants.dart';
import '../../l10n/app_strings.dart';
import '../../models/app_settings.dart';
import '../../models/game_record.dart';
import '../../models/sideboard.dart';
import '../../widgets/clearable_text_field.dart';
import '../../widgets/searchable_combo_field.dart';
import '../../widgets/text_prompt_dialog.dart';
import 'mtg_duel_setup_screen.dart';
import '../../core/ux_state.dart';

enum MtgResourceCounter { white, blue, black, red, green, colorless, storm }

extension MtgResourceCounterX on MtgResourceCounter {
  String get label {
    switch (this) {
      case MtgResourceCounter.white:
        return 'White mana';
      case MtgResourceCounter.blue:
        return 'Blue mana';
      case MtgResourceCounter.black:
        return 'Black mana';
      case MtgResourceCounter.red:
        return 'Red mana';
      case MtgResourceCounter.green:
        return 'Green mana';
      case MtgResourceCounter.colorless:
        return 'Colorless mana';
      case MtgResourceCounter.storm:
        return 'Storm count';
    }
  }

  Color get accentColor {
    switch (this) {
      case MtgResourceCounter.white:
        return const Color(0xFFF3F1E8);
      case MtgResourceCounter.blue:
        return const Color(0xFF4C81D9);
      case MtgResourceCounter.black:
        return const Color(0xFF232323);
      case MtgResourceCounter.red:
        return const Color(0xFFD94C4C);
      case MtgResourceCounter.green:
        return const Color(0xFF3FA55A);
      case MtgResourceCounter.colorless:
        return const Color(0xFF9B9B9B);
      case MtgResourceCounter.storm:
        return const Color(0xFFE6A23C);
    }
  }
}

enum MtgStatusCounter { poison, experience }

extension MtgStatusCounterX on MtgStatusCounter {
  String get label {
    switch (this) {
      case MtgStatusCounter.poison:
        return 'Poison counters (\u03A6)';
      case MtgStatusCounter.experience:
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
    this.onCheckpoint,
  });

  final AppSettings settings;
  final int playerCount;
  final int initialLifePoints;
  final MtgDuelLayoutMode layoutMode;
  final List<String> availableDeckNames;
  final List<SideboardDeck> availableDecks;
  final String initialDeckName;
  final DuelCheckpointCallback? onCheckpoint;

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
  late final List<Map<MtgResourceCounter, int>> _resourceCounters;
  late final List<Map<MtgStatusCounter, int>> _statusCounters;
  late final List<List<int>> _commanderDamageReceived;

  bool _isRollingDice = false;
  Timer? _diceRollTimer;
  Timer? _diceResultTimer;
  int _diceRollTicks = 0;
  bool _showDiceResults = false;

  late final List<String> _historyEntries;
  late final List<TwoPlayerLifeEvent> _twoPlayerLifeEvents;
  late final List<String> _playerNames;
  late List<Color> _playerCardBackgroundColors;

  String _opponentName = '';
  String _opponentDeckInUse = '';
  String _selectedOpponentDeckId = '';
  String _matchFormat = '';
  String _matchTag = '';
  String _matchName = '';
  String _selectedGameStage = 'G1';
  String _deckInUse = '';
  String _selectedDeckId = '';
  int _bo3Wins = 0;
  int _bo3Losses = 0;
  String _lastCompletedOpponentName = '';
  String _lastRecordedOpponentName = '';
  final List<DuelCompletedGamePayload> _completedGamesForSession =
      <DuelCompletedGamePayload>[];
  final List<SideboardDeck> _createdDecksForSession = <SideboardDeck>[];
  late List<SideboardDeck> _sessionAvailableDecks;
  late String _currentMatchId;

  bool get _isMultiplayer => widget.playerCount >= 3;

  MtgDuelLayoutMode get _effectiveLayoutMode => effectiveMtgLayoutMode(
    playerCount: widget.playerCount,
    layoutMode: widget.layoutMode,
  );

  bool get _isTableMode => _effectiveLayoutMode == MtgDuelLayoutMode.tableMode;

  int _quarterTurnsForPlayer(int playerIndex) {
    return mtgQuarterTurnsForPlayer(
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

  Color _playerCardBackgroundColor(int playerIndex) {
    if (playerIndex < 0 || playerIndex >= _playerCardBackgroundColors.length) {
      return widget.settings.lifePointsBackgroundColor;
    }
    return _playerCardBackgroundColors[playerIndex];
  }

  Future<Color?> _promptPlayerCardColor({
    required String title,
    required Color selectedColor,
  }) async {
    return showDialog<Color>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final Color color in appColorPalette)
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(color),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selectedColor == color
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.2),
                        width: selectedColor == color ? 2.4 : 1,
                      ),
                    ),
                    child: selectedColor == color
                        ? const Icon(Icons.check, size: 18, color: Colors.white)
                        : null,
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.txt.t('common.cancel')),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(
                context,
              ).pop(widget.settings.lifePointsBackgroundColor),
              child: const Text('Default'),
            ),
          ],
        );
      },
    );
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
    for (final SideboardDeck deck in _sessionAvailableDecks) {
      final String trimmed = deck.name.trim();
      if (trimmed.toLowerCase() == normalizedInitial) {
        return trimmed;
      }
    }
    return '';
  }

  SideboardDeck? _deckById(String deckId) {
    final String trimmedId = deckId.trim();
    if (trimmedId.isEmpty) {
      return null;
    }
    for (final SideboardDeck deck in _sessionAvailableDecks) {
      if (deck.id == trimmedId) {
        return deck;
      }
    }
    return null;
  }

  SideboardDeck? _deckByName(String deckName) {
    return findUniqueDeckByName(_sessionAvailableDecks, deckName);
  }

  SideboardDeck? _selectedDeckForGuide() {
    return _deckById(_selectedDeckId) ?? _deckByName(_deckInUse);
  }

  String _selectedDeckIdForHistory() {
    return _selectedDeckForGuide()?.id ?? '';
  }

  String _deckIdByName(String deckName) {
    return _deckByName(deckName)?.id ?? '';
  }

  String _selectedOpponentDeckIdForHistory() {
    return _deckById(_selectedOpponentDeckId)?.id ??
        _deckIdByName(_opponentDeckInUse);
  }

  bool _hasConfiguredSideboard(SideboardMatchup matchup) {
    bool hasNamedCards(List<SideboardCardEntry> entries) {
      for (final SideboardCardEntry entry in entries) {
        if (entry.name.trim().isNotEmpty) {
          return true;
        }
      }
      return false;
    }

    return hasNamedCards(matchup.sideIn) || hasNamedCards(matchup.sideOut);
  }

  List<SideboardMatchup> _configuredMatchupsForGuide(SideboardDeck deck) {
    return deck.matchups.where(_hasConfiguredSideboard).toList(growable: false);
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
    if (widget.playerCount != 2) {
      return;
    }
    final AppStrings txt = context.txt;
    final SideboardDeck? deck = _selectedDeckForGuide();
    if (deck == null) {
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(txt.t('sideboardGuide.dialogTitle')),
            content: Text(txt.t('sideboardGuide.noDeckSelected')),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(txt.t('common.close')),
              ),
            ],
          );
        },
      );
      return;
    }
    await showInfoTipOnce(
      context: context,
      tipId: InfoTipIds.sideboardGuide,
      titleKey: 'info.sideboardGuide.title',
      bodyKey: 'info.sideboardGuide.body',
      icon: Icons.menu_book_rounded,
    );
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        final List<SideboardMatchup> configuredMatchups =
            _configuredMatchupsForGuide(deck);
        final bool hasMatchups = configuredMatchups.isNotEmpty;
        return AlertDialog(
          title: Text('${deck.name} - ${txt.t('sideboardGuide.dialogTitle')}'),
          content: SizedBox(
            width: double.maxFinite,
            child: hasMatchups
                ? SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (
                          int index = 0;
                          index < configuredMatchups.length;
                          index += 1
                        ) ...[
                          if (index > 0) const SizedBox(height: 12),
                          Text(
                            configuredMatchups[index].name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${txt.t('sideboardGuide.sideIn')}: ${_formatSideboardEntries(configuredMatchups[index].sideIn)}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${txt.t('sideboardGuide.sideOut')}: ${_formatSideboardEntries(configuredMatchups[index].sideOut)}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : Text(txt.t('sideboardGuide.noPlansForDeck')),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(txt.t('common.close')),
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
    if (!supportedGameStages.contains(currentStage)) {
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
      _opponentDeckInUse = '';
      _selectedOpponentDeckId = '';
      _matchFormat = '';
      _matchTag = '';
      _matchName = '';
      _currentMatchId = 'match-${DateTime.now().microsecondsSinceEpoch}';
    }
  }

  String _resolvedOpponentForHistory() {
    final String trimmedOpponent = _opponentName.trim();
    if (trimmedOpponent.isNotEmpty) {
      return trimmedOpponent;
    }
    final String rememberedOpponent = _lastRecordedOpponentName.trim();
    if (rememberedOpponent.isNotEmpty) {
      return rememberedOpponent;
    }
    return _lastCompletedOpponentName.trim();
  }

  bool _hasActiveGameProgress() {
    for (int index = 0; index < widget.playerCount; index += 1) {
      if (_lifePoints[index] != widget.initialLifePoints) {
        return true;
      }
      if (_pendingDeltas[index] != 0) {
        return true;
      }
      for (final MtgResourceCounter counter in MtgResourceCounter.values) {
        if ((_resourceCounters[index][counter] ?? 0) != 0) {
          return true;
        }
      }
      for (final MtgStatusCounter counter in MtgStatusCounter.values) {
        if ((_statusCounters[index][counter] ?? 0) != 0) {
          return true;
        }
      }
      for (
        int sourceIndex = 0;
        sourceIndex < widget.playerCount;
        sourceIndex += 1
      ) {
        if (_commanderDamageReceived[index][sourceIndex] != 0) {
          return true;
        }
      }
    }
    if (widget.playerCount == 2) {
      return _twoPlayerLifeEvents.isNotEmpty;
    }
    return _historyEntries.length > widget.playerCount;
  }

  DuelCompletedGamePayload _buildCompletedGamePayload({
    required String matchResult,
  }) {
    final String rawStage = _selectedGameStage.trim().toUpperCase();
    final String normalizedStage = supportedGameStages.contains(rawStage)
        ? rawStage
        : 'G1';
    final String rawResult = matchResult.trim();
    final String normalizedResult = supportedMatchResults.contains(rawResult)
        ? rawResult
        : '';
    return DuelCompletedGamePayload(
      lifePointHistory: _historySnapshotWithPending(),
      gameStage: normalizedStage,
      opponentName: _resolvedOpponentForHistory(),
      deckId: _selectedDeckIdForHistory(),
      deckName: _deckInUse.trim(),
      opponentDeckId: _selectedOpponentDeckIdForHistory(),
      opponentDeckName: _opponentDeckInUse.trim(),
      matchFormat: _matchFormat.trim(),
      matchTag: _matchTag.trim(),
      matchId: widget.playerCount == 2 ? _currentMatchId : '',
      matchName: _matchName.trim(),
      matchResult: normalizedResult,
      createdAt: DateTime.now(),
    );
  }

  @override
  void initState() {
    super.initState();
    unawaited(WakelockPlus.enable());
    _sessionAvailableDecks = List<SideboardDeck>.from(widget.availableDecks);
    _deckInUse = _resolveInitialDeckName();
    _selectedDeckId = _selectedDeckForGuide()?.id ?? '';
    _matchFormat = _selectedDeckForGuide()?.format.trim() ?? '';
    _currentMatchId = 'match-${DateTime.now().microsecondsSinceEpoch}';
    _playerNames = List<String>.generate(
      widget.playerCount,
      (int index) => _defaultPlayerName(index),
    );
    _playerCardBackgroundColors = List<Color>.generate(
      widget.playerCount,
      (int i) {
        if (i == 0) return widget.settings.playerOneColor;
        if (i == 1) return widget.settings.playerTwoColor;
        return widget.settings.lifePointsBackgroundColor;
      },
    );
    _lifePoints = List<int>.filled(
      widget.playerCount,
      widget.initialLifePoints,
    );
    _pendingDeltas = List<int>.filled(widget.playerCount, 0);
    _pendingTimers = List<Timer?>.filled(widget.playerCount, null);
    _diceValues = List<int?>.filled(widget.playerCount, null);
    _resourceCounters = List<Map<MtgResourceCounter, int>>.generate(
      widget.playerCount,
      (_) => <MtgResourceCounter, int>{
        for (final MtgResourceCounter counter in MtgResourceCounter.values)
          counter: 0,
      },
    );
    _statusCounters = List<Map<MtgStatusCounter, int>>.generate(
      widget.playerCount,
      (_) => <MtgStatusCounter, int>{
        for (final MtgStatusCounter counter in MtgStatusCounter.values)
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
      return buildTwoPlayerHistoryTable(
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
    _diceResultTimer?.cancel();
    for (int index = 0; index < widget.playerCount; index += 1) {
      _cancelPendingTimer(index);
    }
    Navigator.of(context).pop(
      _buildDuelResultPayload(matchResult: matchResult, shouldSave: shouldSave),
    );
  }

  DuelResultPayload _buildDuelResultPayload({
    String matchResult = '',
    bool shouldSave = true,
    bool includeCurrentGameIfNeeded = true,
  }) {
    final String explicitMatchResult = matchResult.trim();
    final DuelCompletedGamePayload currentSnapshot = _buildCompletedGamePayload(
      matchResult: explicitMatchResult,
    );
    List<DuelCompletedGamePayload> gamesToSave =
        const <DuelCompletedGamePayload>[];
    if (shouldSave) {
      gamesToSave = List<DuelCompletedGamePayload>.from(
        _completedGamesForSession,
      );
      final bool includeCurrentGame =
          includeCurrentGameIfNeeded &&
          (explicitMatchResult.isNotEmpty || _hasActiveGameProgress());
      if (includeCurrentGame) {
        gamesToSave.add(currentSnapshot);
      }
    }
    final DuelCompletedGamePayload payloadSource = gamesToSave.isNotEmpty
        ? gamesToSave.last
        : currentSnapshot;
    return DuelResultPayload(
      lifePointHistory: List<String>.from(payloadSource.lifePointHistory),
      gameStage: payloadSource.gameStage,
      opponentName: payloadSource.opponentName,
      deckId: payloadSource.deckId,
      deckName: payloadSource.deckName,
      opponentDeckId: payloadSource.opponentDeckId,
      opponentDeckName: payloadSource.opponentDeckName,
      matchFormat: payloadSource.matchFormat,
      matchTag: payloadSource.matchTag,
      matchResult: payloadSource.matchResult,
      playerCount: widget.playerCount,
      shouldSave: shouldSave && gamesToSave.isNotEmpty,
      completedGames: gamesToSave,
      createdDecks: List<SideboardDeck>.from(_createdDecksForSession),
      matchId: widget.playerCount == 2 ? _currentMatchId : '',
      matchName: _matchName.trim(),
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
                        child: buildLifeHistoryView(
                          lines: historySnapshot,
                          playerCount: widget.playerCount,
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

  Map<MtgResourceCounter, int> _resourceCountersForPlayer(int playerIndex) {
    return _resourceCounters[playerIndex];
  }

  Map<MtgStatusCounter, int> _statusCountersForPlayer(int playerIndex) {
    return _statusCounters[playerIndex];
  }

  int _poisonCountersForPlayer(int playerIndex) {
    return _statusCountersForPlayer(playerIndex)[MtgStatusCounter.poison] ?? 0;
  }

  int _experienceCountersForPlayer(int playerIndex) {
    return _statusCountersForPlayer(
          playerIndex,
        )[MtgStatusCounter.experience] ??
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
    required MtgResourceCounter counter,
    required int delta,
  }) {
    final Map<MtgResourceCounter, int> counters = _resourceCountersForPlayer(
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
    required MtgStatusCounter counter,
    required int delta,
  }) {
    final Map<MtgStatusCounter, int> counters = _statusCountersForPlayer(
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
        final Map<MtgResourceCounter, int> counters =
            _resourceCountersForPlayer(playerIndex);
        return Column(
          children: [
            for (final MtgResourceCounter counter
                in MtgResourceCounter.values)
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
        final Map<MtgStatusCounter, int> counters = _statusCountersForPlayer(
          playerIndex,
        );
        return Column(
          children: [
            for (final MtgStatusCounter counter in MtgStatusCounter.values)
              _buildMtgCounterRow(
                label: Row(
                  children: [
                    if (counter == MtgStatusCounter.poison) ...[
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
    if (!_isMultiplayer) {
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
    }
    final TextEditingController matchNameController = TextEditingController(
      text: _matchName,
    );
    final TextEditingController opponentController = TextEditingController(
      text: _opponentName,
    );
    final TextEditingController tagController = TextEditingController(
      text: _matchTag,
    );
    final List<TextEditingController> playerNameControllers =
        List<TextEditingController>.generate(
          widget.playerCount,
          (int index) => TextEditingController(text: _playerName(index)),
        );
    final List<Color> selectedPlayerCardColors = List<Color>.from(
      _playerCardBackgroundColors,
    );
    String stage = _selectedGameStage;
    String selectedDeckId = _selectedDeckIdForHistory();
    if (selectedDeckId.isEmpty && _deckInUse.trim().isNotEmpty) {
      selectedDeckId = _deckByName(_deckInUse)?.id ?? '';
    }
    if (selectedDeckId.isNotEmpty && _deckById(selectedDeckId) == null) {
      selectedDeckId = '';
    }
    String selectedFormat = _matchFormat.trim();
    String selectedOpponentDeckId = _selectedOpponentDeckIdForHistory();

    Future<String?> promptText({
      required String title,
      required String initialValue,
      required String hintText,
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

    List<SideboardDeck> deckOptions() {
      return filterDecksByFormat(_sessionAvailableDecks, selectedFormat);
    }

    List<String> formatOptions() {
      final Set<String> unique = <String>{};
      for (final SideboardDeck deck in _sessionAvailableDecks) {
        final String format = deck.format.trim();
        if (format.isEmpty) {
          continue;
        }
        unique.add(format);
      }
      if (selectedFormat.isNotEmpty) {
        unique.add(selectedFormat);
      }
      final List<String> options = unique.toList(growable: false);
      options.sort((String a, String b) {
        return a.toLowerCase().compareTo(b.toLowerCase());
      });
      return options;
    }

    List<SideboardDeck> opponentDeckOptions() {
      return filterDecksByFormat(_sessionAvailableDecks, selectedFormat);
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
      if (selectedOpponentDeck == null) {
        selectedOpponentDeckId = '';
        return;
      }
      if (!deckMatchesFormat(selectedOpponentDeck, selectedFormat)) {
        selectedOpponentDeckId = '';
      }
    }

    if (selectedOpponentDeckId.isEmpty &&
        _opponentDeckInUse.trim().isNotEmpty) {
      selectedOpponentDeckId = _deckByName(_opponentDeckInUse)?.id ?? '';
    }
    normalizeSelectedDeck();
    normalizeSelectedOpponentDeck();

    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(context.txt.t(_isMultiplayer ? 'dialog.gameDetails' : 'dialog.matchDetails')),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              Future<void> pickPlayerColor(int playerIndex) async {
                final Color? picked = await _promptPlayerCardColor(
                  title: 'Player ${playerIndex + 1} card color',
                  selectedColor: selectedPlayerCardColors[playerIndex],
                );
                if (picked == null || !mounted) {
                  return;
                }
                setDialogState(() {
                  selectedPlayerCardColors[playerIndex] = picked;
                });
              }

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isMultiplayer) ...[
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
                        decoration: InputDecoration(
                          labelText: context.txt.t('field.opponentName'),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SearchableComboField(
                        value: selectedFormat,
                        decoration: InputDecoration(
                          labelText: context.txt.t('field.format'),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        fixedItems: <ComboItem>[
                          ComboItem(
                            value: '',
                            label: context.txt.t('field.noFormat'),
                          ),
                        ],
                        items: formatOptions()
                            .map((String f) => ComboItem(value: f, label: f))
                            .toList(growable: false),
                        addLabel: context.txt.t('field.addNewFormat'),
                        onAdd: (String query) async {
                          final String? created = await promptText(
                            title: 'New format',
                            initialValue: query,
                            hintText: 'Modern, Edison, Commander...',
                          );
                          if (created == null) return null;
                          final String trimmed = created.trim();
                          return trimmed.isEmpty ? null : trimmed;
                        },
                        onChanged: (String value) {
                          setDialogState(() {
                            selectedFormat = value.trim();
                            normalizeSelectedDeck();
                            normalizeSelectedOpponentDeck();
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      SearchableComboField(
                        value: selectedOpponentDeckId,
                        decoration: InputDecoration(
                          labelText: context.txt.t('field.opponentDeck'),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        fixedItems: <ComboItem>[
                          ComboItem(
                            value: '',
                            label: context.txt.t('field.noOpponentDeck'),
                          ),
                        ],
                        items: opponentDeckOptions()
                            .map(
                              (SideboardDeck d) =>
                                  ComboItem(value: d.id, label: d.name),
                            )
                            .toList(growable: false),
                        addLabel: context.txt.t('field.addNewDeck'),
                        onAdd: (String query) async {
                          final String? createdName = await promptText(
                            title: 'New opponent deck',
                            initialValue: query,
                            hintText: 'Deck name',
                          );
                          if (createdName == null) return null;
                          final String trimmedName = createdName.trim();
                          if (trimmedName.isEmpty) return null;
                          final SideboardDeck? existing = _deckByName(
                            trimmedName,
                          );
                          if (existing != null) return existing.id;
                          final SideboardDeck newDeck = SideboardDeck(
                            id: DateTime.now().microsecondsSinceEpoch
                                .toString(),
                            name: trimmedName,
                            createdAt: DateTime.now(),
                            isFavorite: false,
                            userNotes: '',
                            matchups: const <SideboardMatchup>[],
                            format: selectedFormat.trim(),
                            tag: '',
                            tcgKey: SupportedTcg.mtg.storageKey,
                          );
                          setDialogState(() {
                            _sessionAvailableDecks = <SideboardDeck>[
                              newDeck,
                              ..._sessionAvailableDecks,
                            ];
                            _createdDecksForSession.add(newDeck);
                          });
                          return newDeck.id;
                        },
                        onChanged: (String value) {
                          setDialogState(() {
                            selectedOpponentDeckId = value.trim();
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
                    ],
                    if (!_isMultiplayer) ...[
                      SearchableComboField(
                        value: stage,
                        decoration: const InputDecoration(
                          labelText: 'Game',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: supportedGameStages
                            .map((String s) => ComboItem(value: s, label: s))
                            .toList(growable: false),
                        onChanged: (String value) {
                          setDialogState(() {
                            stage = value;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                    SearchableComboField(
                      value: selectedDeckId,
                      decoration: InputDecoration(
                        labelText: context.txt.t('field.deckInUse'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      fixedItems: <ComboItem>[
                        ComboItem(
                          value: '',
                          label: context.txt.t('field.noDeck'),
                        ),
                      ],
                      items: deckOptions()
                          .map(
                            (SideboardDeck d) =>
                                ComboItem(value: d.id, label: d.name),
                          )
                          .toList(growable: false),
                      addLabel: context.txt.t('field.addNewDeck'),
                      onAdd: (String query) async {
                        final String? createdName = await promptText(
                          title: context.txt.t('field.addNewDeck'),
                          initialValue: query,
                          hintText: context.txt.t('field.deckName'),
                        );
                        if (createdName == null) return null;
                        final String trimmedName = createdName.trim();
                        if (trimmedName.isEmpty) return null;
                        final SideboardDeck? existing = _deckByName(trimmedName);
                        if (existing != null) return existing.id;
                        final SideboardDeck newDeck = SideboardDeck(
                          id: DateTime.now().microsecondsSinceEpoch.toString(),
                          name: trimmedName,
                          createdAt: DateTime.now(),
                          isFavorite: false,
                          userNotes: '',
                          matchups: const <SideboardMatchup>[],
                          format: selectedFormat.trim(),
                          tag: '',
                          tcgKey: SupportedTcg.mtg.storageKey,
                        );
                        setDialogState(() {
                          _sessionAvailableDecks = <SideboardDeck>[
                            newDeck,
                            ..._sessionAvailableDecks,
                          ];
                          _createdDecksForSession.add(newDeck);
                        });
                        return newDeck.id;
                      },
                      onChanged: (String value) {
                        setDialogState(() {
                          selectedDeckId = value.trim();
                          if (selectedDeckId.isEmpty) return;
                          final SideboardDeck? linkedDeck = _deckById(
                            selectedDeckId,
                          );
                          if (linkedDeck != null &&
                              selectedFormat.trim().isEmpty &&
                              linkedDeck.format.trim().isNotEmpty) {
                            selectedFormat = linkedDeck.format.trim();
                          }
                          normalizeSelectedDeck();
                          normalizeSelectedOpponentDeck();
                        });
                      },
                    ),
                    if (_isMultiplayer) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          context.txt.t('game.playerNames'),
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClearableTextField(
                                controller: playerNameControllers[playerIndex],
                                decoration: InputDecoration(
                                  labelText: context.txt.t('game.playerName', params: <String, Object?>{'n': playerIndex + 1}),
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 76,
                              child: Tooltip(
                                message:
                                    'Change Player ${playerIndex + 1} card color',
                                child: FilledButton.tonal(
                                  onPressed: () => pickPlayerColor(playerIndex),
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(76, 48),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 6,
                                    ),
                                    backgroundColor:
                                        selectedPlayerCardColors[playerIndex],
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(
                                        color: Colors.white.withValues(
                                          alpha: 0.24,
                                        ),
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.palette_outlined, size: 18),
                                      const SizedBox(height: 2),
                                      Text(
                                        context.txt.t('game.color'),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
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
        ...playerNameControllers,
      ]);
      return;
    }

    if (!mounted) {
      disposeTextControllersLater(<TextEditingController>[
        matchNameController,
        opponentController,
        tagController,
        ...playerNameControllers,
      ]);
      return;
    }

    setState(() {
      _matchName = matchNameController.text.trim();
      _opponentName = opponentController.text.trim();
      _matchFormat = selectedFormat.trim();
      final SideboardDeck? selectedDeckObject = _deckById(selectedDeckId);
      final SideboardDeck? selectedOpponentDeck = _deckById(
        selectedOpponentDeckId,
      );
      _selectedOpponentDeckId = selectedOpponentDeck?.id ?? '';
      _opponentDeckInUse = selectedOpponentDeck?.name ?? '';
      _matchTag = tagController.text.trim();
      if (_opponentName.isNotEmpty) {
        _lastCompletedOpponentName = _opponentName;
        _lastRecordedOpponentName = _opponentName;
      }
      _selectedDeckId = selectedDeckObject?.id ?? '';
      _deckInUse = selectedDeckObject?.name ?? '';
      if (!_isMultiplayer) {
        _selectedGameStage = stage;
      }
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
        _playerCardBackgroundColors = List<Color>.from(
          selectedPlayerCardColors,
        );
      }
    });
    disposeTextControllersLater(<TextEditingController>[
      matchNameController,
      opponentController,
      tagController,
      ...playerNameControllers,
    ]);
  }

  void _rollDice() {
    if (_isRollingDice) {
      return;
    }
    const int totalTicks = 12;
    const Duration tickDuration = Duration(milliseconds: 85);
    _diceRollTimer?.cancel();
    _diceResultTimer?.cancel();
    _diceResultTimer = null;
    setState(() {
      _isRollingDice = true;
      _diceRollTicks = 0;
      _showDiceResults = true;
      for (int index = 0; index < widget.playerCount; index += 1) {
        _diceValues[index] = nextDieValue(_random);
      }
    });

    _diceRollTimer = Timer.periodic(tickDuration, (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      bool shouldStop = false;
      setState(() {
        for (int index = 0; index < widget.playerCount; index += 1) {
          _diceValues[index] = nextDieValue(_random);
        }
        _diceRollTicks += 1;
        if (_diceRollTicks >= totalTicks) {
          _isRollingDice = false;
          shouldStop = true;
        }
      });
      if (shouldStop) {
        timer.cancel();
        _diceRollTimer = null;
        _scheduleDiceResultDismissal();
      }
    });
  }

  void _scheduleDiceResultDismissal() {
    _diceResultTimer?.cancel();
    _diceResultTimer = Timer(diceResultVisibilityDuration, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _showDiceResults = false;
        for (int index = 0; index < widget.playerCount; index += 1) {
          _diceValues[index] = null;
        }
      });
      _diceResultTimer = null;
    });
  }

  Future<void> _confirmReset({bool fromHome = false}) async {
    const Color resetColor = Color(0xFF232323);
    const Color saveExitColor = Color(0xFF244A67);
    const Color winColor = Color(0xFF163825);
    const Color lossColor = Color(0xFF4A1E1E);
    const Color drawColor = Color(0xFF4D4220);
    final String? action = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            widget.playerCount == 2
                ? context.txt.t('game.endOrResetMatch')
                : context.txt.t('game.endOrResetGame'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (fromHome) ...[
                FilledButton.tonal(
                  onPressed: () => Navigator.of(context).pop('save_exit'),
                  style: FilledButton.styleFrom(backgroundColor: saveExitColor),
                  child: Text(context.txt.t('game.saveAndExit')),
                ),
                const SizedBox(height: 8),
              ],
              if (widget.playerCount == 2) ...[
                FilledButton.tonal(
                  onPressed: () => Navigator.of(context).pop('sideboard'),
                  style: FilledButton.styleFrom(
                    backgroundColor: widget.settings.buttonColor,
                  ),
                  child: Text(context.txt.t('game.sideboardGuide')),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton.tonal(
                onPressed: () => Navigator.of(context).pop('reset'),
                style: FilledButton.styleFrom(backgroundColor: resetColor),
                child: Text(
                  fromHome
                      ? (_completedGamesForSession.isNotEmpty
                            ? context.txt.t('game.discardAndExit')
                            : context.txt.t('game.exitWithoutSaving'))
                      : context.txt.t('game.resetWithoutSaving'),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.of(context).pop('Win'),
                style: FilledButton.styleFrom(backgroundColor: winColor),
                child: Text(context.txt.t('game.win')),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.of(context).pop('Loss'),
                style: FilledButton.styleFrom(backgroundColor: lossColor),
                child: Text(context.txt.t('game.loss')),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.of(context).pop('Draw'),
                style: FilledButton.styleFrom(backgroundColor: drawColor),
                child: Text(context.txt.t('game.draw')),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.txt.t('common.cancel')),
            ),
          ],
        );
      },
    );
    if (action == null || !mounted) {
      return;
    }
    if (action == 'sideboard' && widget.playerCount == 2) {
      await _openSideboardGuideDialog();
      return;
    }
    if (action == 'save_exit') {
      _closeWithHistory();
      return;
    }
    if (action == 'Win' || action == 'Loss' || action == 'Draw') {
      if (widget.playerCount != 2) {
        _closeWithHistory(matchResult: action);
        return;
      }

      _diceRollTimer?.cancel();
      _diceRollTimer = null;
      _diceResultTimer?.cancel();
      _diceResultTimer = null;
      for (int index = 0; index < widget.playerCount; index += 1) {
        _cancelPendingTimer(index);
      }
      setState(() {
        _completedGamesForSession.add(
          _buildCompletedGamePayload(matchResult: action),
        );
        final String completedOpponent = _opponentName.trim();
        if (completedOpponent.isNotEmpty) {
          _lastCompletedOpponentName = completedOpponent;
          _lastRecordedOpponentName = completedOpponent;
        }
        _advanceBo3AfterRestart(declaredResult: action);
        for (int index = 0; index < widget.playerCount; index += 1) {
          _lifePoints[index] = widget.initialLifePoints;
          _pendingDeltas[index] = 0;
          _diceValues[index] = null;
          for (final MtgResourceCounter counter
              in MtgResourceCounter.values) {
            _resourceCounters[index][counter] = 0;
          }
          for (final MtgStatusCounter counter in MtgStatusCounter.values) {
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
        _showDiceResults = false;
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
      final DuelResultPayload checkpointPayload = _buildDuelResultPayload(
        shouldSave: true,
        includeCurrentGameIfNeeded: false,
      );
      if (widget.onCheckpoint != null) {
        await widget.onCheckpoint!(checkpointPayload);
      }
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
    _diceResultTimer?.cancel();
    _diceResultTimer = null;
    for (int index = 0; index < widget.playerCount; index += 1) {
      _cancelPendingTimer(index);
    }
    setState(() {
      _lastRecordedOpponentName = '';
      _advanceBo3AfterRestart();
      for (int index = 0; index < widget.playerCount; index += 1) {
        _lifePoints[index] = widget.initialLifePoints;
        _pendingDeltas[index] = 0;
        _diceValues[index] = null;
        for (final MtgResourceCounter counter in MtgResourceCounter.values) {
          _resourceCounters[index][counter] = 0;
        }
        for (final MtgStatusCounter counter in MtgStatusCounter.values) {
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
      _showDiceResults = false;
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
    bool prominent = false,
  }) {
    final double size = prominent ? (compact ? 34 : 42) : (compact ? 26 : 32);
    final double pipSize = prominent ? size * 0.16 : size * 0.145;
    final double inset = prominent ? size * 0.14 : size * 0.13;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isRolling ? const Color(0xFFFFE9B3) : const Color(0xFFEEEDED),
        borderRadius: BorderRadius.circular(prominent ? 12 : (compact ? 7 : 9)),
        border: Border.all(
          color: isRolling ? const Color(0xFFE7C061) : const Color(0xFFB0AFAF),
          width: prominent ? (isRolling ? 1.9 : 1.2) : (isRolling ? 1.6 : 1),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(inset),
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

  Widget _buildAnimatedDieResult({required int value, required bool compact}) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1).animate(animation),
            child: child,
          ),
        );
      },
      child: !_showDiceResults
          ? const SizedBox.shrink(key: ValueKey<String>('dice-hidden'))
          : Container(
              key: ValueKey<String>(
                'dice-$value-${compact ? 'compact' : 'regular'}-${_isRollingDice ? 'rolling' : 'final'}',
              ),
              padding: EdgeInsets.all(compact ? 4 : 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(compact ? 14 : 18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: _buildDieFace(
                value,
                compact: compact,
                isRolling: _isRollingDice,
                prominent: true,
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
    final bool showDieResult = _showDiceResults && dieValue != null;
    final int dieResultValue = dieValue ?? 0;
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
    final AppStrings txt = context.txt;
    final String historyLabel = ultraTight ? txt.t('game.histShort') : txt.t('game.history');
    final String manaLabel = txt.t('game.mana');
    final String statusLabel = ultraTight ? txt.t('game.cntrShort') : txt.t('game.counters');
    final String commanderLabel = ultraTight ? txt.t('game.cmdShort') : txt.t('game.commander');
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
              color: _playerCardBackgroundColor(playerIndex),
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
          top: showDieResult ? (dense ? 40 : 48) : (dense ? 2 : 4),
          child: _buildPendingDeltaBadge(
            playerIndex: playerIndex,
            compact: dense,
          ),
        ),
        Positioned(
          right: 0,
          top: dense ? 0 : 2,
          child: showDieResult
              ? _buildAnimatedDieResult(value: dieResultValue, compact: true)
              : const SizedBox.shrink(),
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
              const int buttonsCount = 5;
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
                        onPressed: () {
                          unawaited(_openSideboardGuideDialog());
                        },
                        icon: const Icon(Icons.menu_book_outlined, size: 28),
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
    final List<int> slotFlexes = slotFlexesForSlots(slots);

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

  Widget _buildMultiplayerRowsLayout({required List<MtgLayoutRowSpec> rows}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
        child: Stack(
          children: [
            Column(
              children: [
                for (final MtgLayoutRowSpec row in rows)
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
      rows: mtgLayoutRows(
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
      rows: mtgLayoutRows(
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
          required VoidCallback? onPressed,
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
                  label: dialogContext.txt.t('game.details'),
                  icon: Icons.edit_outlined,
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _openMatchDetailsEditor();
                  },
                ),
                const SizedBox(height: 8),
                menuButton(
                  label: dialogContext.txt.t('game.dice'),
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
    _diceResultTimer?.cancel();
    for (int index = 0; index < _pendingTimers.length; index += 1) {
      _pendingTimers[index]?.cancel();
    }
    super.dispose();
  }
}

