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
import '../../widgets/text_prompt_dialog.dart';
import '../../core/ux_state.dart';
import '../mtg/mtg_duel_screen.dart';

class DuelScreen extends StatefulWidget {
  const DuelScreen({
    super.key,
    required this.settings,
    this.ruleset = DuelRuleSet.yugioh,
    this.initialLifePoints = 8000,
    this.availableDeckNames = const <String>[],
    this.availableDecks = const <SideboardDeck>[],
    this.initialDeckName = '',
    this.onCheckpoint,
  });

  final AppSettings settings;
  final DuelRuleSet ruleset;
  final int initialLifePoints;
  final List<String> availableDeckNames;
  final List<SideboardDeck> availableDecks;
  final String initialDeckName;
  final DuelCheckpointCallback? onCheckpoint;

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
  Timer? _diceResultTimer;
  int _diceRollTicks = 0;
  bool _showDiceResults = false;
  Timer? _playerOnePendingTimer;
  Timer? _playerTwoPendingTimer;

  late final Map<MtgResourceCounter, int> _playerOneResourceCounters;
  late final Map<MtgResourceCounter, int> _playerTwoResourceCounters;
  late final Map<MtgStatusCounter, int> _playerOneStatusCounters;
  late final Map<MtgStatusCounter, int> _playerTwoStatusCounters;

  late final List<TwoPlayerLifeEvent> _twoPlayerLifeEvents;

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
    if (_playerOneLp != widget.initialLifePoints ||
        _playerTwoLp != widget.initialLifePoints) {
      return true;
    }
    if (_playerOnePendingDelta != 0 || _playerTwoPendingDelta != 0) {
      return true;
    }
    if (_twoPlayerLifeEvents.isNotEmpty) {
      return true;
    }
    if (_isMtgRules) {
      for (final MtgResourceCounter counter in MtgResourceCounter.values) {
        if ((_playerOneResourceCounters[counter] ?? 0) != 0 ||
            (_playerTwoResourceCounters[counter] ?? 0) != 0) {
          return true;
        }
      }
      for (final MtgStatusCounter counter in MtgStatusCounter.values) {
        if ((_playerOneStatusCounters[counter] ?? 0) != 0 ||
            (_playerTwoStatusCounters[counter] ?? 0) != 0) {
          return true;
        }
      }
    }
    return false;
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
      matchId: _currentMatchId,
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
    _playerOneLp = widget.initialLifePoints;
    _playerTwoLp = widget.initialLifePoints;
    _playerOneResourceCounters = {
      for (final MtgResourceCounter counter in MtgResourceCounter.values)
        counter: 0,
    };
    _playerTwoResourceCounters = {
      for (final MtgResourceCounter counter in MtgResourceCounter.values)
        counter: 0,
    };
    _playerOneStatusCounters = {
      for (final MtgStatusCounter counter in MtgStatusCounter.values)
        counter: 0,
    };
    _playerTwoStatusCounters = {
      for (final MtgStatusCounter counter in MtgStatusCounter.values)
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

  Map<MtgResourceCounter, int> _resourceCountersForPlayer(int player) {
    return player == 1
        ? _playerOneResourceCounters
        : _playerTwoResourceCounters;
  }

  Map<MtgStatusCounter, int> _statusCountersForPlayer(int player) {
    return player == 1 ? _playerOneStatusCounters : _playerTwoStatusCounters;
  }

  int _poisonCountersForPlayer(int player) {
    return _statusCountersForPlayer(player)[MtgStatusCounter.poison] ?? 0;
  }

  int _experienceCountersForPlayer(int player) {
    return _statusCountersForPlayer(player)[MtgStatusCounter.experience] ?? 0;
  }

  void _changeMtgResourceCounter({
    required int player,
    required MtgResourceCounter counter,
    required int delta,
  }) {
    final Map<MtgResourceCounter, int> counters = _resourceCountersForPlayer(
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
    required MtgStatusCounter counter,
    required int delta,
  }) {
    final Map<MtgStatusCounter, int> counters = _statusCountersForPlayer(
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
        final Map<MtgResourceCounter, int> counters =
            _resourceCountersForPlayer(player);
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
        final Map<MtgStatusCounter, int> counters = _statusCountersForPlayer(
          player,
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
                        child: buildLifeHistoryView(
                          lines: historySnapshot,
                          playerCount: 2,
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
    return buildTwoPlayerHistoryTable(
      playerOneName: _playerName(1),
      playerTwoName: _playerName(2),
      initialPlayerOneLife: widget.initialLifePoints,
      initialPlayerTwoLife: widget.initialLifePoints,
      events: events,
    );
  }

  void _closeWithHistory({String matchResult = '', bool shouldSave = true}) {
    _diceRollTimer?.cancel();
    _diceResultTimer?.cancel();
    _cancelPendingTimer(1);
    _cancelPendingTimer(2);
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
      playerCount: 2,
      shouldSave: shouldSave && gamesToSave.isNotEmpty,
      completedGames: gamesToSave,
      createdDecks: List<SideboardDeck>.from(_createdDecksForSession),
      matchId: _currentMatchId,
      matchName: _matchName.trim(),
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
      text: _matchName,
    );
    final TextEditingController opponentController = TextEditingController(
      text: _opponentName,
    );
    final TextEditingController tagController = TextEditingController(
      text: _matchTag,
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

    List<String> formatOptions() {
      final Set<String> unique = <String>{};
      for (final SideboardDeck deck in _sessionAvailableDecks) {
        final String format = deck.format.trim();
        if (format.isNotEmpty) {
          unique.add(format);
        }
      }
      if (selectedFormat.trim().isNotEmpty) {
        unique.add(selectedFormat.trim());
      }
      final List<String> sorted = unique.toList(growable: false);
      sorted.sort((String a, String b) {
        return a.toLowerCase().compareTo(b.toLowerCase());
      });
      return sorted;
    }

    List<SideboardDeck> deckOptions() {
      return filterDecksByFormat(_sessionAvailableDecks, selectedFormat);
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
                      decoration: InputDecoration(
                        labelText: context.txt.t('field.opponentName'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedFormat,
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
                      onChanged: (String? value) async {
                        if (value == null) {
                          return;
                        }
                        if (value == '__add_format__') {
                          final String? created = await promptText(
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
                          selectedFormat = value.trim();
                          normalizeSelectedDeck();
                          normalizeSelectedOpponentDeck();
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedOpponentDeckId,
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
                        const DropdownMenuItem<String>(
                          value: '__add_opponent_deck__',
                          child: Text('Add new deck...'),
                        ),
                      ],
                      onChanged: (String? value) async {
                        if (value == null) {
                          return;
                        }
                        if (value == '__add_opponent_deck__') {
                          final String? createdName = await promptText(
                            title: 'New opponent deck',
                            initialValue: '',
                            hintText: 'Deck name',
                          );
                          if (createdName == null) {
                            return;
                          }
                          final String trimmedName = createdName.trim();
                          if (trimmedName.isEmpty) {
                            return;
                          }
                          final SideboardDeck? existing = _deckByName(
                            trimmedName,
                          );
                          if (existing != null) {
                            setDialogState(() {
                              selectedOpponentDeckId = existing.id;
                              normalizeSelectedOpponentDeck();
                            });
                            return;
                          }
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
                            tcgKey: _isMtgRules
                                ? SupportedTcg.mtg.storageKey
                                : SupportedTcg.yugioh.storageKey,
                          );
                          setDialogState(() {
                            _sessionAvailableDecks = <SideboardDeck>[
                              newDeck,
                              ..._sessionAvailableDecks,
                            ];
                            _createdDecksForSession.add(newDeck);
                            selectedOpponentDeckId = newDeck.id;
                            normalizeSelectedOpponentDeck();
                          });
                          return;
                        }
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
                      initialValue: selectedDeckId,
                      decoration: InputDecoration(
                        labelText: context.txt.t('field.deckInUse'),
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
                            child: Text(deck.name),
                          );
                        }),
                      ],
                      onChanged: (String? value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() {
                          selectedDeckId = value.trim();
                          if (selectedDeckId.isEmpty) {
                            return;
                          }
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

    setState(() {
      _matchName = matchNameController.text.trim();
      _opponentName = opponentController.text.trim();
      final SideboardDeck? selectedDeckObject = _deckById(selectedDeckId);
      final SideboardDeck? selectedOpponentDeck = _deckById(
        selectedOpponentDeckId,
      );
      _selectedOpponentDeckId = selectedOpponentDeck?.id ?? '';
      _opponentDeckInUse = selectedOpponentDeck?.name ?? '';
      _matchFormat = selectedFormat.trim();
      _matchTag = tagController.text.trim();
      if (_opponentName.isNotEmpty) {
        _lastCompletedOpponentName = _opponentName;
        _lastRecordedOpponentName = _opponentName;
      }
      _selectedDeckId = selectedDeckObject?.id ?? '';
      _deckInUse = selectedDeckObject?.name ?? '';
      _selectedGameStage = stage;
      if (stage == 'G1') {
        _bo3Wins = 0;
        _bo3Losses = 0;
      }
    });
    disposeTextControllersLater(<TextEditingController>[
      matchNameController,
      opponentController,
      tagController,
    ]);
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
          title: Text(context.txt.t('game.endOrResetMatch')),
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
              FilledButton.tonal(
                onPressed: () => Navigator.of(context).pop('sideboard'),
                style: FilledButton.styleFrom(
                  backgroundColor: widget.settings.buttonColor,
                ),
                child: Text(context.txt.t('game.sideboardGuide')),
              ),
              const SizedBox(height: 8),
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
    if (action == 'sideboard') {
      await _openSideboardGuideDialog();
      return;
    }
    if (action == 'save_exit') {
      _closeWithHistory();
      return;
    }
    if (action == 'Win' || action == 'Loss' || action == 'Draw') {
      _diceRollTimer?.cancel();
      _diceRollTimer = null;
      _diceResultTimer?.cancel();
      _diceResultTimer = null;
      _cancelPendingTimer(1);
      _cancelPendingTimer(2);

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
        _playerOneLp = widget.initialLifePoints;
        _playerTwoLp = widget.initialLifePoints;
        _playerOneDie = null;
        _playerTwoDie = null;
        _isRollingDice = false;
        _diceRollTicks = 0;
        _showDiceResults = false;
        _playerOnePendingDelta = 0;
        _playerTwoPendingDelta = 0;
        for (final MtgResourceCounter counter in MtgResourceCounter.values) {
          _playerOneResourceCounters[counter] = 0;
          _playerTwoResourceCounters[counter] = 0;
        }
        for (final MtgStatusCounter counter in MtgStatusCounter.values) {
          _playerOneStatusCounters[counter] = 0;
          _playerTwoStatusCounters[counter] = 0;
        }
        _twoPlayerLifeEvents.clear();
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
    _cancelPendingTimer(1);
    _cancelPendingTimer(2);

    setState(() {
      _lastRecordedOpponentName = '';
      _advanceBo3AfterRestart();
      _playerOneLp = widget.initialLifePoints;
      _playerTwoLp = widget.initialLifePoints;
      _playerOneDie = null;
      _playerTwoDie = null;
      _isRollingDice = false;
      _diceRollTicks = 0;
      _showDiceResults = false;
      _playerOnePendingDelta = 0;
      _playerTwoPendingDelta = 0;
      for (final MtgResourceCounter counter in MtgResourceCounter.values) {
        _playerOneResourceCounters[counter] = 0;
        _playerTwoResourceCounters[counter] = 0;
      }
      for (final MtgStatusCounter counter in MtgStatusCounter.values) {
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
    _diceResultTimer?.cancel();
    _diceResultTimer = null;
    setState(() {
      _isRollingDice = true;
      _diceRollTicks = 0;
      _showDiceResults = true;
      _playerOneDie = nextDieValue(_random);
      _playerTwoDie = nextDieValue(_random);
    });

    _diceRollTimer = Timer.periodic(tickDuration, (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      bool shouldStop = false;
      setState(() {
        _playerOneDie = nextDieValue(_random);
        _playerTwoDie = nextDieValue(_random);
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
        _playerOneDie = null;
        _playerTwoDie = null;
      });
      _diceResultTimer = null;
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
    bool prominent = false,
  }) {
    final double size = prominent ? (compact ? 36 : 44) : (compact ? 28 : 34);
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
    final bool showDieResult = _showDiceResults && dieValue != null;
    final int dieResultValue = dieValue ?? 0;
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
                      color: player == 1
                          ? widget.settings.playerOneColor
                          : widget.settings.playerTwoColor,
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
                Positioned(
                  left: 0,
                  top: compact ? 2 : 4,
                  child: showDieResult
                      ? _buildAnimatedDieResult(
                          value: dieResultValue,
                          compact: compact,
                        )
                      : const SizedBox.shrink(),
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
              const int buttonsCount = 5;
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
                        onPressed: () {
                          unawaited(_openSideboardGuideDialog());
                        },
                        child: const Icon(Icons.menu_book_outlined, size: 30),
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

