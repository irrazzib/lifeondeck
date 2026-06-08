import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants.dart';
import '../../core/ux_state.dart';
import '../../l10n/app_strings.dart';
import '../../models/app_settings.dart';
import '../../models/game_record.dart';
import '../../models/sideboard.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/sync_service.dart';
import '../customize/customize_screen.dart';
import '../profile/profile_screen.dart';
import '../duel/duel_screen.dart';
import '../game_selection/game_selection_screen.dart';
import '../history/game_history_screen.dart';
import '../mtg/mtg_duel_screen.dart';
import '../mtg/mtg_duel_setup_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../sideboard/sideboard_deck_list_screen.dart';
import '../../core/config.dart';
import '../../widgets/sync_status_badge.dart';

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
  static const String _syncedAccountKey = 'synced_account_id_v1';

  bool _isLoading = true;
  bool _onboardingCompleted = true;
  bool _defaultGameSelected = true;
  bool _premiumUnlocked = false;
  AppSettings _settings = AppSettings.defaults();
  List<GameRecord> _gameRecords = <GameRecord>[];
  List<SideboardDeck> _sideboardDecks = <SideboardDeck>[];
  Map<String, String> _lastDeckByTcg = <String, String>{};
  SupportedTcg _selectedGame = SupportedTcg.yugioh;
  String _saveDebugStatus = 'idle';
  String _buildTag = '';
  Future<void> _queuedCheckpointSave = Future<void>.value();

  // Auth / sync services (initialised in initState).
  late final ApiClient _apiClient;
  late final AuthService _authService;
  late final SyncService _syncService;

  String get _selectedTcgKey => _selectedGame.storageKey;
  bool get _isImplementedGame =>
      _selectedGame != SupportedTcg.riftbound &&
      _selectedGame != SupportedTcg.lorcana;

  // Live (non-tombstoned) records for the active game. Soft-deleted records are
  // kept in [_gameRecords] so their tombstones persist and sync, but every
  // display/stat/child-screen consumer works off this filtered view.
  List<GameRecord> _recordsForSelectedGame() {
    return _gameRecords
        .where((GameRecord record) =>
            record.tcgKey == _selectedTcgKey && record.deletedAt == null)
        .toList(growable: false);
  }

  int _matchCountForSelectedGame() {
    final Set<String> twoPlayerMatchIds = <String>{};
    int multiPlayerCount = 0;
    for (final GameRecord record in _recordsForSelectedGame()) {
      if (record.playerCount == 2) {
        final String matchId = record.matchId.trim().isNotEmpty
            ? record.matchId.trim()
            : 'legacy-${record.id}';
        twoPlayerMatchIds.add(matchId);
      } else {
        multiPlayerCount++;
      }
    }
    return twoPlayerMatchIds.length + multiPlayerCount;
  }

  List<SideboardDeck> _decksForSelectedGame() {
    return _sideboardDecks
        .where((SideboardDeck deck) => deck.tcgKey == _selectedTcgKey)
        .toList(growable: false);
  }

  List<SideboardDeck> _liveDecksForSelectedGame() {
    return _decksForSelectedGame()
        .where((SideboardDeck deck) => deck.deletedAt == null)
        .toList(growable: false);
  }

  SideboardDeck? _findDeckByNameForSelectedGame(String rawName) {
    return findUniqueDeckByName(_decksForSelectedGame(), rawName);
  }

  String _defaultDeckNameForSelectedGame() {
    final String stored = (_lastDeckByTcg[_selectedTcgKey] ?? '').trim();
    if (stored.isEmpty) {
      return '';
    }
    final SideboardDeck? linked = _findDeckByNameForSelectedGame(stored);
    return linked?.name ?? '';
  }

  int _nextTwoPlayerMatchNumberForTcg(String tcgKey) {
    final Set<String> uniqueMatchIds = <String>{};
    for (final GameRecord record in _gameRecords) {
      if (record.tcgKey != tcgKey || record.playerCount != 2) {
        continue;
      }
      final String matchId = record.matchId.trim().isNotEmpty
          ? record.matchId.trim()
          : 'legacy-${record.id}';
      uniqueMatchIds.add(matchId);
    }
    return uniqueMatchIds.length + 1;
  }

  String _defaultMatchNameFor({
    required SupportedTcg tcg,
    required int number,
  }) {
    final AppStrings txt = context.txt;
    final String prefix = tcg == SupportedTcg.mtg
        ? '${txt.t('tcg.mtg')} Match'
        : 'Match';
    return '$prefix $number';
  }

  String _gameRecordIdForPayload({
    required String tcgKey,
    required int playerCount,
    required DuelCompletedGamePayload payload,
    String? normalizedStage,
    String? normalizedMatchId,
  }) {
    final String resolvedStage = (normalizedStage ?? payload.gameStage)
        .trim()
        .toUpperCase();
    final String matchId = (normalizedMatchId ?? payload.matchId).trim();
    return [
      tcgKey,
      playerCount.toString(),
      payload.createdAt.toUtc().microsecondsSinceEpoch.toString(),
      matchId.isEmpty ? 'single' : matchId,
      resolvedStage.isEmpty ? 'G1' : resolvedStage,
    ].join('|');
  }

  List<GameRecord> _buildGameRecordsFromDuelResult({
    required SupportedTcg tcg,
    required String tcgKey,
    required String duelTitlePrefix,
    required DuelResultPayload duelResult,
    required List<SideboardDeck> availableDecks,
  }) {
    final List<DuelCompletedGamePayload> payloadGames =
        duelResult.completedGames.isNotEmpty
        ? List<DuelCompletedGamePayload>.from(duelResult.completedGames)
        : <DuelCompletedGamePayload>[
            DuelCompletedGamePayload(
              lifePointHistory: List<String>.from(duelResult.lifePointHistory),
              gameStage: duelResult.gameStage,
              opponentName: duelResult.opponentName,
              deckId: duelResult.deckId,
              deckName: duelResult.deckName,
              opponentDeckId: duelResult.opponentDeckId,
              opponentDeckName: duelResult.opponentDeckName,
              matchFormat: duelResult.matchFormat,
              matchTag: duelResult.matchTag,
              matchId: duelResult.matchId,
              matchName: duelResult.matchName,
              matchResult: duelResult.matchResult,
              createdAt: DateTime.now(),
            ),
          ];

    final int normalizedPlayerCount = duelResult.playerCount
        .clamp(2, 6)
        .toInt();
    final bool isTwoPlayerSession = normalizedPlayerCount == 2;
    String sessionMatchId = isTwoPlayerSession ? duelResult.matchId.trim() : '';
    if (isTwoPlayerSession && sessionMatchId.isEmpty) {
      sessionMatchId = 'match-${DateTime.now().microsecondsSinceEpoch}';
    }
    String sessionMatchName = isTwoPlayerSession
        ? duelResult.matchName.trim()
        : '';
    if (isTwoPlayerSession && sessionMatchName.isEmpty) {
      sessionMatchName = _defaultMatchNameFor(
        tcg: tcg,
        number: _nextTwoPlayerMatchNumberForTcg(tcgKey),
      );
    }

    int nextGeneratedMatchNumber = _nextTwoPlayerMatchNumberForTcg(tcgKey);
    final Map<String, String> generatedMatchNames = <String, String>{};
    final Map<String, GameRecord> existingById = <String, GameRecord>{
      for (final GameRecord record in _gameRecords) record.id: record,
    };
    final int scopedExistingCount = _gameRecords
        .where((GameRecord record) => record.tcgKey == tcgKey)
        .length;
    int nextGeneratedTitleIndex = scopedExistingCount + 1;
    final List<GameRecord> newRecords = <GameRecord>[];

    for (final DuelCompletedGamePayload payload in payloadGames) {
      final List<String> normalizedHistory = payload.lifePointHistory
          .map((String line) => line.trim())
          .where((String line) => line.isNotEmpty)
          .toList(growable: false);
      final String rawResult = payload.matchResult.trim();
      final String normalizedResult = supportedMatchResults.contains(rawResult)
          ? rawResult
          : '';
      final String rawStage = payload.gameStage.trim().toUpperCase();
      final String normalizedStage = supportedGameStages.contains(rawStage)
          ? rawStage
          : 'G1';
      if (normalizedHistory.isEmpty && normalizedResult.isEmpty) {
        continue;
      }

      final String rawDeckName = payload.deckName.trim();
      final String payloadDeckId = payload.deckId.trim();
      SideboardDeck? selectedDeck;
      if (payloadDeckId.isNotEmpty) {
        for (final SideboardDeck deck in availableDecks) {
          if (deck.id == payloadDeckId) {
            selectedDeck = deck;
            break;
          }
        }
      }
      selectedDeck ??= _findDeckByNameForSelectedGame(rawDeckName);
      final String resolvedDeckId = selectedDeck?.id ?? payloadDeckId;
      final String resolvedDeckName = selectedDeck?.name ?? rawDeckName;

      final String rawOpponentDeckName = payload.opponentDeckName.trim();
      final String payloadOpponentDeckId = payload.opponentDeckId.trim();
      SideboardDeck? selectedOpponentDeck;
      if (payloadOpponentDeckId.isNotEmpty) {
        for (final SideboardDeck deck in availableDecks) {
          if (deck.id == payloadOpponentDeckId) {
            selectedOpponentDeck = deck;
            break;
          }
        }
      }
      selectedOpponentDeck ??= _findDeckByNameForSelectedGame(
        rawOpponentDeckName,
      );
      final String resolvedOpponentDeckId =
          selectedOpponentDeck?.id ?? payloadOpponentDeckId;
      final String resolvedOpponentDeckName =
          selectedOpponentDeck?.name ?? rawOpponentDeckName;

      final String resolvedOpponentName = payload.opponentName.trim();
      final String resolvedMatchFormat = payload.matchFormat.trim().isNotEmpty
          ? payload.matchFormat.trim()
          : (selectedDeck?.format.trim() ?? '');
      final String resolvedMatchTag = payload.matchTag.trim();
      final DateTime createdAt = payload.createdAt;

      String resolvedMatchId = '';
      String resolvedMatchName = '';
      if (isTwoPlayerSession) {
        resolvedMatchId = payload.matchId.trim();
        if (resolvedMatchId.isEmpty) {
          resolvedMatchId = sessionMatchId;
        }
        if (resolvedMatchId.isEmpty) {
          resolvedMatchId = 'match-${createdAt.microsecondsSinceEpoch}';
        }
        resolvedMatchName = payload.matchName.trim();
        if (resolvedMatchName.isEmpty &&
            sessionMatchName.isNotEmpty &&
            (payload.matchId.trim().isEmpty ||
                payload.matchId.trim() == sessionMatchId)) {
          resolvedMatchName = sessionMatchName;
        }
        if (resolvedMatchName.isEmpty) {
          resolvedMatchName = generatedMatchNames.putIfAbsent(
            resolvedMatchId,
            () {
              final String generated = _defaultMatchNameFor(
                tcg: tcg,
                number: nextGeneratedMatchNumber,
              );
              nextGeneratedMatchNumber += 1;
              return generated;
            },
          );
        }
      }

      final String recordId = _gameRecordIdForPayload(
        tcgKey: tcgKey,
        playerCount: normalizedPlayerCount,
        payload: payload,
        normalizedStage: normalizedStage,
        normalizedMatchId: resolvedMatchId,
      );
      final GameRecord? existingRecord = existingById[recordId];
      final String title =
          existingRecord?.title ??
          '$duelTitlePrefix ${nextGeneratedTitleIndex++}';

      newRecords.add(
        GameRecord(
          id: recordId,
          title: title,
          createdAt: createdAt,
          gameStage: normalizedStage,
          notes: existingRecord?.notes ?? '',
          lifePointHistory: normalizedHistory,
          tcgKey: tcgKey,
          deckId: resolvedDeckId,
          matchResult: normalizedResult,
          opponentName: resolvedOpponentName,
          deckName: resolvedDeckName,
          playerOneName:
              existingRecord?.playerOneName ?? _settings.playerOneName,
          playerTwoName: resolvedOpponentName.isEmpty
              ? _settings.playerTwoName
              : resolvedOpponentName,
          playerCount: normalizedPlayerCount,
          matchId: resolvedMatchId,
          matchName: resolvedMatchName,
          matchFormat: resolvedMatchFormat,
          opponentDeckId: resolvedOpponentDeckId,
          opponentDeckName: resolvedOpponentDeckName,
          matchTag: resolvedMatchTag,
        ),
      );
    }

    return newRecords;
  }

  Future<int> _persistDuelResultRecords({
    required SupportedTcg tcg,
    required String tcgKey,
    required String duelTitlePrefix,
    required DuelResultPayload duelResult,
    required List<SideboardDeck> availableDecks,
    String debugPrefix = 'saved',
  }) async {
    final List<GameRecord> newRecords = _buildGameRecordsFromDuelResult(
      tcg: tcg,
      tcgKey: tcgKey,
      duelTitlePrefix: duelTitlePrefix,
      duelResult: duelResult,
      availableDecks: availableDecks,
    );

    if (newRecords.isEmpty) {
      setState(() {
        _saveDebugStatus = '$debugPrefix: no completed games to save';
      });
      await _persistState();
      return 0;
    }

    final Set<String> existingIds = _gameRecords
        .map((GameRecord record) => record.id)
        .toSet();
    final int insertedCount = newRecords
        .where((GameRecord record) => !existingIds.contains(record.id))
        .length;
    final int updatedCount = newRecords.length - insertedCount;

    final Map<String, GameRecord> mergedById = <String, GameRecord>{
      for (final GameRecord record in _gameRecords) record.id: record,
    };
    for (final GameRecord record in newRecords) {
      mergedById[record.id] = record;
    }

    final List<GameRecord> mergedRecords =
        mergedById.values.toList(growable: false)
          ..sort((GameRecord a, GameRecord b) {
            return b.createdAt.compareTo(a.createdAt);
          });

    setState(() {
      _gameRecords = mergedRecords;
      _saveDebugStatus =
          '$debugPrefix: +$insertedCount new, ~$updatedCount updated';
    });
    await _persistState();
    return insertedCount;
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
        final String normalizedKey = normalizeTcgKey(
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

  // Merge the records a child screen returns back into the full collection.
  // Union by id starting from every local record (all games + existing
  // tombstones); returned records win. Child screens only ever receive the live
  // records for one game, so a wholesale replace would silently drop this game's
  // tombstones — the union preserves them while still applying updates, new
  // records, and freshly-returned tombstones.
  List<GameRecord> _mergeRecordsForGame(
    List<GameRecord> updatedRecords,
    String tcgKey,
  ) {
    final Map<String, GameRecord> byId = <String, GameRecord>{
      for (final GameRecord record in _gameRecords) record.id: record,
    };
    for (final GameRecord record in updatedRecords) {
      final GameRecord scoped = record.copyWith(tcgKey: tcgKey);
      byId[scoped.id] = scoped;
    }
    final List<GameRecord> merged = byId.values.toList(growable: false)
      ..sort((GameRecord a, GameRecord b) {
        return b.createdAt.compareTo(a.createdAt);
      });
    return merged;
  }

  List<SideboardDeck> _mergePulledDecks({
    required List<SideboardDeck> local,
    required List<SideboardDeck> remote,
  }) {
    final Map<String, SideboardDeck> byId = <String, SideboardDeck>{
      for (final SideboardDeck d in local) d.id: d,
    };
    for (final SideboardDeck incoming in remote) {
      final SideboardDeck? existing = byId[incoming.id];
      if (existing == null ||
          !incoming.updatedAt.isBefore(existing.updatedAt)) {
        byId[incoming.id] = incoming;
      }
    }
    return byId.values.toList(growable: false);
  }

  List<GameRecord> _mergePulledRecords({
    required List<GameRecord> local,
    required List<GameRecord> remote,
  }) {
    final Map<String, GameRecord> byId = <String, GameRecord>{
      for (final GameRecord r in local) r.id: r,
    };
    for (final GameRecord incoming in remote) {
      final GameRecord? existing = byId[incoming.id];
      if (existing == null ||
          !incoming.updatedAt.isBefore(existing.updatedAt)) {
        byId[incoming.id] = incoming;
      }
    }
    return byId.values.toList(growable: false);
  }

  /// Decode a list of server sync items into domain models.
  ///
  /// Each item is `{id, data, updatedAt, deleted}` where `data` is the full
  /// record serialised as a JSON **string** blob (the wire contract is
  /// documented in `sync_service.dart`). The model is reconstructed from that
  /// blob, which already carries `id`, `updatedAt` and `deletedAt`; the wrapper
  /// fields are transport metadata only. Malformed blobs are skipped so one bad
  /// row never aborts the whole pull.
  List<T> _decodePulledItems<T>(
    Object? rawItems,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (rawItems is! List) {
      return <T>[];
    }
    final List<T> parsed = <T>[];
    for (final Object? entry in rawItems) {
      if (entry is! Map) {
        continue;
      }
      final Object? data = entry['data'];
      if (data is! String || data.isEmpty) {
        continue;
      }
      try {
        final dynamic decoded = jsonDecode(data);
        if (decoded is Map) {
          parsed.add(fromJson(Map<String, dynamic>.from(decoded)));
        }
      } catch (_) {
        // Skip malformed blob.
      }
    }
    return parsed;
  }

  /// Decode the single app-settings sync item (or null) from a pull response.
  /// Same `{id, data, updatedAt, deleted}` envelope as the list items.
  AppSettings? _decodePulledSettings(Object? rawItem) {
    if (rawItem is! Map) {
      return null;
    }
    final Object? data = rawItem['data'];
    if (data is! String || data.isEmpty) {
      return null;
    }
    try {
      final dynamic decoded = jsonDecode(data);
      if (decoded is Map) {
        return AppSettings.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      // Fall through to null on malformed blob.
    }
    return null;
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

  List<SideboardDeck> _mergeDeckCollections({
    required List<SideboardDeck> existing,
    required List<SideboardDeck> incoming,
    required String tcgKey,
  }) {
    final List<SideboardDeck> merged = existing
        .map((SideboardDeck deck) => deck.copyWith(tcgKey: tcgKey))
        .toList(growable: true);
    final Set<String> ids = merged
        .map((SideboardDeck deck) => deck.id.trim())
        .where((String id) => id.isNotEmpty)
        .toSet();
    final Set<String> names = merged
        .map((SideboardDeck deck) => normalizeDeckName(deck.name))
        .where((String name) => name.isNotEmpty)
        .toSet();
    for (final SideboardDeck deck in incoming) {
      final SideboardDeck normalized = deck.copyWith(tcgKey: tcgKey);
      final String id = normalized.id.trim();
      final String name = normalizeDeckName(normalized.name);
      if (id.isNotEmpty && ids.contains(id)) {
        continue;
      }
      if (name.isNotEmpty && names.contains(name)) {
        continue;
      }
      if (id.isNotEmpty) {
        ids.add(id);
      }
      if (name.isNotEmpty) {
        names.add(name);
      }
      merged.add(normalized);
    }
    return merged.toList(growable: false);
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
    _apiClient = ApiClient();
    _authService = AuthService(_apiClient);
    // Let the Dio client refresh an expired JWT transparently on a 401.
    _apiClient.onRefresh = _authService.refreshToken;
    _syncService = SyncService(
      apiClient: _apiClient,
      authService: _authService,
    );
    _authService.addListener(_onAuthStateChanged);
    _loadBuildTag();
    _initWithSync();
  }

  Future<void> _loadBuildTag() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _buildTag = 'v${info.version} (${info.buildNumber})';
    });
  }

  Future<void> _initWithSync() async {
    await _loadStoredData();
    await _syncService.initialize();
    // _authService.initialize() fires notifyListeners() when a valid session is
    // restored, which drives _onAuthStateChanged -> _setupSync() + an immediate
    // syncNow(). Keep the auth-reaction logic in one place (the listener) so
    // cold start and runtime login follow the exact same path.
    await _authService.initialize();
  }

  void _setupSync() {
    _syncService.onGetPayload = () => AppSyncPayload(
      gameRecords: _gameRecords
          .map((GameRecord r) => r.toJson())
          .toList(growable: false),
      sideboardDecks: _sideboardDecks
          .map((SideboardDeck d) => d.toJson())
          .toList(growable: false),
      appSettings: _settings.toJson(),
    );
    _syncService.onApplyPull = (Map<String, dynamic> pulled) async {
      // Each pulled item has shape {id, data, updatedAt, deleted} where `data`
      // is the full record serialised as a JSON string blob. Decode the blob —
      // it already carries id/updatedAt/deletedAt — before rebuilding the model.
      final List<GameRecord> remoteRecords = _decodePulledItems<GameRecord>(
        pulled['gameRecords'],
        GameRecord.fromJson,
      );
      final List<SideboardDeck> remoteDecks =
          _decodePulledItems<SideboardDeck>(
        pulled['sideboardDecks'],
        SideboardDeck.fromJson,
      );
      final AppSettings? remoteSettings =
          _decodePulledSettings(pulled['appSettings']);

      if (remoteRecords.isNotEmpty) {
        setState(() => _gameRecords = _mergePulledRecords(
          local: _gameRecords,
          remote: remoteRecords,
        ));
      }
      if (remoteDecks.isNotEmpty) {
        setState(() => _sideboardDecks = _mergePulledDecks(
          local: _sideboardDecks,
          remote: remoteDecks,
        ));
      }
      // App settings are last-write-wins by their own updatedAt; only adopt the
      // remote copy when it is strictly newer than the local one.
      if (remoteSettings != null &&
          remoteSettings.updatedAt.isAfter(_settings.updatedAt)) {
        setState(() => _settings = remoteSettings);
        AppRuntimeConfig.language.value = AppLanguageX.fromStorageKey(
          remoteSettings.appLanguageKey,
        );
      }
      await _persistState();
    };
    _syncService.startAutoSync();
  }

  Future<void> _loadStoredData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool premiumUnlocked = prefs.getBool(_premiumKey) ?? false;
    final bool onboardingCompleted =
        await AppUxStateStore.onboardingCompleted();
    final bool defaultGameSelected =
        await AppUxStateStore.defaultGameSelected();
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
      _onboardingCompleted = onboardingCompleted;
      _defaultGameSelected = defaultGameSelected;
      _settings = settings;
      _selectedGame = SupportedTcgX.fromStorageKey(settings.startupTcgKey);
      _gameRecords = records;
      _sideboardDecks = sideboardDecks;
      _lastDeckByTcg = lastDeckByTcg;
      _isLoading = false;
    });
    AppRuntimeConfig.language.value = AppLanguageX.fromStorageKey(
      settings.appLanguageKey,
    );
  }

  /// Wipe all account-scoped data from memory and disk, resetting settings to
  /// their defaults. Used on logout, on account switch, and by the guest
  /// "clear local data" action. Deliberately leaves device-level state intact:
  /// the premium entitlement and the onboarding / default-game UX flags.
  Future<void> _clearLocalData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recordsKey);
    await prefs.remove(_sideboardDecksKey);
    await prefs.remove(_settingsKey);
    await prefs.remove(_lastDeckByTcgKey);
    if (!mounted) return;
    final AppSettings defaults = _decodeSettings(null);
    setState(() {
      _gameRecords = <GameRecord>[];
      _sideboardDecks = <SideboardDeck>[];
      _settings = defaults;
      _selectedGame = SupportedTcgX.fromStorageKey(defaults.startupTcgKey);
      _lastDeckByTcg = <String, String>{};
    });
    AppRuntimeConfig.language.value = AppLanguageX.fromStorageKey(
      defaults.appLanguageKey,
    );
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
    if (_authService.isAuthenticated) {
      _syncService.markDirty();
    }
  }

  Future<void> _completeOnboarding() async {
    setState(() {
      _onboardingCompleted = true;
    });
    await AppUxStateStore.setOnboardingCompleted(true);
  }

  Future<void> _completeGameSelection(SupportedTcg game) async {
    final AppSettings updated = _settings.copyWith(
      startupTcgKey: game.storageKey,
    );
    setState(() {
      _defaultGameSelected = true;
      _settings = updated;
      _selectedGame = game;
    });
    await _persistState();
    await AppUxStateStore.setDefaultGameSelected(true);
  }

  Future<bool> _ensurePremiumAccess({required String featureName}) async {
    if (_premiumUnlocked) {
      return true;
    }
    final AppStrings txt = context.txt;

    final bool? unlocked = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(txt.t('home.upgradeProTitle')),
          content: Text(
            txt.t(
              'home.upgradeProBody',
              params: <String, Object?>{'feature': featureName},
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(txt.t('common.notNow')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(txt.t('home.buyProDemo')),
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
    final AppStrings txt = context.txt;
    late final Widget duelScreen;
    String duelTitlePrefix = 'Duel';
    final SupportedTcg selectedGame = _selectedGame;
    final String selectedTcgKey = _selectedTcgKey;
    List<SideboardDeck> availableDecks = _liveDecksForSelectedGame();
    final List<String> availableDeckNames = availableDecks
        .map((SideboardDeck deck) => deck.name)
        .toList(growable: false);
    final String defaultDeckName = _defaultDeckNameForSelectedGame();

    Future<void> mergeCreatedDecksFromPayload(DuelResultPayload payload) async {
      final List<SideboardDeck> newlyCreatedDecks = payload.createdDecks
          .where(
            (SideboardDeck deck) =>
                deck.name.trim().isNotEmpty && deck.tcgKey == selectedTcgKey,
          )
          .toList(growable: false);
      if (newlyCreatedDecks.isEmpty) {
        return;
      }
      availableDecks = _mergeDeckCollections(
        existing: availableDecks,
        incoming: newlyCreatedDecks,
        tcgKey: selectedTcgKey,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _sideboardDecks = _mergeDecksForGame(availableDecks, selectedTcgKey);
      });
    }

    Future<void> persistCheckpoint(DuelResultPayload payload) async {
      _queuedCheckpointSave = _queuedCheckpointSave.then((_) async {
        final String latestDeckName = payload.deckName.trim();
        if (latestDeckName.isNotEmpty && mounted) {
          setState(() {
            _lastDeckByTcg[selectedTcgKey] = latestDeckName;
          });
        }
        await mergeCreatedDecksFromPayload(payload);
        if (!payload.shouldSave || payload.completedGames.isEmpty) {
          await _persistState();
          return;
        }
        await _persistDuelResultRecords(
          tcg: selectedGame,
          tcgKey: selectedTcgKey,
          duelTitlePrefix: duelTitlePrefix,
          duelResult: payload,
          availableDecks: availableDecks,
          debugPrefix: 'checkpoint',
        );
      });
      await _queuedCheckpointSave;
    }

    if (selectedGame == SupportedTcg.yugioh) {
      duelScreen = DuelScreen(
        settings: _settings,
        availableDeckNames: availableDeckNames,
        availableDecks: availableDecks,
        initialDeckName: defaultDeckName,
        onCheckpoint: persistCheckpoint,
      );
    } else if (selectedGame == SupportedTcg.mtg) {
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
        onCheckpoint: persistCheckpoint,
      );
      duelTitlePrefix = 'MTG Game';
    } else {
      return;
    }

    if (!mounted) {
      return;
    }

    final DuelResultPayload? duelResult = await Navigator.of(context)
        .push<DuelResultPayload>(
          MaterialPageRoute<DuelResultPayload>(builder: (_) => duelScreen),
        );

    await _queuedCheckpointSave;

    if (!mounted) return;

    final String latestDeckName = duelResult?.deckName.trim() ?? '';
    if (duelResult != null) {
      setState(() {
        _lastDeckByTcg[selectedTcgKey] = latestDeckName;
      });
    }

    if (duelResult == null) {
      setState(() {
        _saveDebugStatus = 'duelResult=null -> nothing to save';
      });
      await _persistState();
      return;
    }

    await mergeCreatedDecksFromPayload(duelResult);

    if (!duelResult.shouldSave) {
      setState(() {
        _saveDebugStatus = 'current game discarded; confirmed games kept';
      });
      await _persistState();
      return;
    }

    final int insertedCount = await _persistDuelResultRecords(
      tcg: selectedGame,
      tcgKey: selectedTcgKey,
      duelTitlePrefix: duelTitlePrefix,
      duelResult: duelResult,
      availableDecks: availableDecks,
      debugPrefix: 'final save',
    );

    if (mounted && insertedCount > 0) {
      final int savedCount = _recordsForSelectedGame().length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            txt.t(
              'home.savedGamesToast',
              params: <String, Object?>{
                'count': insertedCount,
                'total': savedCount,
              },
            ),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _openGameHistory() async {
    final AppStrings txt = context.txt;
    final bool allowed = await _ensurePremiumAccess(
      featureName: txt.t('home.gameHistory'),
    );
    if (!allowed || !mounted) {
      return;
    }

    final String tcgKey = _selectedTcgKey;
    final List<GameRecord> scopedRecords = _recordsForSelectedGame();
    final List<SideboardDeck> scopedDecks = _liveDecksForSelectedGame();

    final GameHistoryResult? historyResult = await Navigator.of(context)
        .push<GameHistoryResult>(
          MaterialPageRoute<GameHistoryResult>(
            builder: (_) => GameHistoryScreen(
              records: scopedRecords,
              decks: scopedDecks,
              tcg: _selectedGame,
            ),
          ),
        );

    if (historyResult == null) {
      return;
    }

    setState(() {
      _gameRecords = _mergeRecordsForGame(historyResult.records, tcgKey);
      if (historyResult.createdDecks.isNotEmpty) {
        final List<SideboardDeck> merged = _mergeDeckCollections(
          existing: _decksForSelectedGame(),
          incoming: historyResult.createdDecks,
          tcgKey: tcgKey,
        );
        _sideboardDecks = _mergeDecksForGame(merged, tcgKey);
      }
    });
    await _persistState();
  }

  Future<void> _openCustomize() async {
    final AppStrings txt = context.txt;
    final bool allowed = await _ensurePremiumAccess(
      featureName: txt.t('home.customizeApp'),
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
    AppRuntimeConfig.language.value = AppLanguageX.fromStorageKey(
      updatedSettings.appLanguageKey,
    );
    await _persistState();
  }

  Future<void> _openSideboardBook() async {
    final AppStrings txt = context.txt;
    final bool allowed = await _ensurePremiumAccess(
      featureName: txt.t('home.decksUtility'),
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

  Future<void> _onAuthStateChanged() async {
    if (!mounted) return;
    if (_authService.isAuthenticated) {
      final String uid = _authService.currentUser!.id;
      final String? previous = await _readSyncedAccountId();
      // A different account owns the data currently on disk: wipe it and reset
      // the pull cursor before syncing. This is the safety net that also covers
      // the case where the logout-wipe never ran (app killed mid-session).
      if (previous != null && previous != uid) {
        await _clearLocalData();
        await _syncService.resetCursor();
      }
      await _writeSyncedAccountId(uid);
      if (!mounted) return;
      setState(() {});
      _setupSync();
      // Sync immediately on login so the user gets feedback right away instead
      // of waiting for the next auto-sync tick (up to 5 min).
      await _syncService.syncNow();
    } else {
      // Logout: wipe synced data + cursor so the next account starts clean.
      _syncService.stopAutoSync();
      await _clearLocalData();
      await _syncService.resetCursor();
      await _clearSyncedAccountId();
      if (!mounted) return;
      setState(() {});
    }
  }

  Future<String?> _readSyncedAccountId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_syncedAccountKey);
  }

  Future<void> _writeSyncedAccountId(String uid) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_syncedAccountKey, uid);
  }

  Future<void> _clearSyncedAccountId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_syncedAccountKey);
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(
          authService: _authService,
          syncService: _syncService,
          apiClient: _apiClient,
          onClearLocalData: () async {
            await _clearLocalData();
            await _syncService.resetCursor();
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthStateChanged);
    _syncService.dispose();
    _authService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings txt = context.txt;
    final AppSettings activeSettings = _settings;
    final int savedMatchesForGame = _matchCountForSelectedGame();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              _selectedGame.homePresetColors.bgStart,
              _selectedGame.homePresetColors.bgEnd,
            ],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : !_defaultGameSelected
              ? GameSelectionScreen(onCompleted: _completeGameSelection)
              : !_onboardingCompleted
              ? AppOnboardingScreen(onCompleted: _completeOnboarding)
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: SyncStatusBadge(
                          syncService: _syncService,
                          onTap: _openProfile,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        txt.t('app.title'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_buildTag • $_saveDebugStatus',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
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
                            items: supportedTcgAlphabeticalOrder
                                .map(
                                  (SupportedTcg game) =>
                                      DropdownMenuItem<SupportedTcg>(
                                        value: game,
                                        child: Text(
                                          txt.t('tcg.${game.storageKey}'),
                                        ),
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
                        ModeButton(
                          icon: Icons.splitscreen,
                          title: txt.t('home.letsDuel'),
                          subtitle: txt.t('home.topBottomPlayers'),
                          backgroundColor: activeSettings.buttonColor,
                          onPressed: _startDuel,
                        ),
                        const SizedBox(height: 12),
                        ModeButton(
                          icon: Icons.history_rounded,
                          title: txt.t('home.gameHistory'),
                          subtitle: _premiumUnlocked
                              ? txt.t(
                                  'home.savedMatches',
                                  params: <String, Object?>{
                                    'count': savedMatchesForGame,
                                  },
                                )
                              : txt.t(
                                  'home.premiumSaved',
                                  params: <String, Object?>{
                                    'count': savedMatchesForGame,
                                  },
                                ),
                          backgroundColor: activeSettings.buttonColor,
                          onPressed: _openGameHistory,
                          locked: !_premiumUnlocked,
                        ),
                        const SizedBox(height: 12),
                        ModeButton(
                          icon: Icons.menu_book_rounded,
                          title: txt.t('home.decksUtility'),
                          subtitle: _premiumUnlocked
                              ? txt.t('home.decksUtilitySubtitle')
                              : txt.t('common.premium'),
                          backgroundColor: activeSettings.buttonColor,
                          onPressed: _openSideboardBook,
                          locked: !_premiumUnlocked,
                        ),
                        const SizedBox(height: 12),
                        ModeButton(
                          icon: Icons.tune_rounded,
                          title: txt.t('home.customizeApp'),
                          subtitle: _premiumUnlocked
                              ? txt.t('home.namesAndColors')
                              : txt.t('common.premium'),
                          backgroundColor: activeSettings.buttonColor,
                          onPressed: _openCustomize,
                          locked: !_premiumUnlocked,
                        ),
                        const SizedBox(height: 12),
                        ModeButton(
                          icon: Icons.account_circle_outlined,
                          title: txt.t('account.title'),
                          subtitle: _authService.isAuthenticated
                              ? txt.t(
                                  'account.subtitleSignedIn',
                                  params: <String, Object?>{
                                    'displayName':
                                        _authService.currentUser!.displayName,
                                  },
                                )
                              : txt.t('account.subtitleSignedOut'),
                          backgroundColor: activeSettings.buttonColor,
                          onPressed: _openProfile,
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
                          child: Text(
                            txt.t('home.comingSoon'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
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
