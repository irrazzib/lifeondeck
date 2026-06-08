import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sync_state.dart';
import 'api_client.dart';
import 'auth_service.dart';

// ---------------------------------------------------------------------------
// Sync wire contract (client <-> /api/v1/sync)
//
// Every record crosses the wire wrapped in an envelope:
//
//     { "id": <string>, "data": <json-string>, "updatedAt": <iso8601>,
//       "deleted": <bool> }
//
// `data` is the COMPLETE record serialised as a JSON *string* (the server
// treats it as an opaque blob). The blob already contains `id`, `updatedAt`
// and `deletedAt`, so those envelope fields are duplicated transport metadata
// used only for routing / last-write-wins on the server.
//
//   PUSH (here): 'data' = jsonEncode(record.toJson()); envelope `updatedAt`
//                and `deleted` are derived from the same map.
//   PULL (home_screen onApplyPull): jsonDecode(item['data']) -> Model.fromJson.
//
// App settings use the same envelope but a single object instead of a list,
// and are pushed only when their real `updatedAt` is newer than the last sync.
// ---------------------------------------------------------------------------

/// Represents the full app state to be synchronised with the remote backend.
class AppSyncPayload {
  const AppSyncPayload({
    required this.gameRecords,
    required this.sideboardDecks,
    required this.appSettings,
  });

  final List<Map<String, dynamic>> gameRecords;
  final List<Map<String, dynamic>> sideboardDecks;
  final Map<String, dynamic>? appSettings;
}

/// Callback types used by [SyncService] to read/apply state without depending
/// directly on [_HomeScreenState].
typedef GetPayloadCallback = AppSyncPayload Function();
typedef ApplyPullCallback = Future<void> Function(Map<String, dynamic> pulled);

class SyncService extends ChangeNotifier {
  SyncService({
    required ApiClient apiClient,
    required AuthService authService,
    Duration autoSyncInterval = const Duration(minutes: 5),
  })  : _apiClient = apiClient,
        _authService = authService,
        _autoSyncInterval = autoSyncInterval;

  static const String _lastSyncKey = 'last_sync_at';

  final ApiClient _apiClient;
  final AuthService _authService;
  final Duration _autoSyncInterval;

  final ValueNotifier<SyncState> stateNotifier =
      ValueNotifier<SyncState>(const SyncState());

  Timer? _autoSyncTimer;
  bool _dirty = false;
  DateTime? _lastSyncedAt;

  GetPayloadCallback? onGetPayload;
  ApplyPullCallback? onApplyPull;

  /// Restore the last successful sync timestamp from persistent storage.
  /// Call once during app bootstrap before [startAutoSync].
  Future<void> initialize() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? stored = prefs.getString(_lastSyncKey);
    if (stored != null) {
      _lastSyncedAt = DateTime.tryParse(stored)?.toUtc();
    }
  }

  /// Call after every local state mutation so the service knows a push is due.
  void markDirty() {
    _dirty = true;
    stateNotifier.value = stateNotifier.value.copyWith(pendingPush: true);
  }

  /// Start the periodic auto-sync timer.
  void startAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(_autoSyncInterval, (_) => _autoSync());
  }

  /// Stop the periodic auto-sync timer.
  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  /// Reset the pull cursor and pending state to a clean slate.
  ///
  /// Both [_lastSyncedAt] and its persisted `last_sync_at` key are global (not
  /// scoped per account), so they must be cleared whenever the local data is
  /// wiped — on logout or when a different account signs in — otherwise the
  /// next pull's `since` would still be the previous user's cursor.
  Future<void> resetCursor() async {
    stopAutoSync();
    _lastSyncedAt = null;
    _dirty = false;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastSyncKey);
    stateNotifier.value = const SyncState();
  }

  Future<void> _autoSync() async {
    if (!_authService.isAuthenticated || !_dirty) return;
    await syncNow();
  }

  /// Manually trigger a full push + pull cycle.
  /// Returns [true] if the sync completed successfully.
  Future<bool> syncNow() async {
    if (!_authService.isAuthenticated) return false;

    final List<ConnectivityResult> connectivity =
        await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      stateNotifier.value = stateNotifier.value.copyWith(
        status: SyncStatus.offline,
      );
      return false;
    }

    stateNotifier.value = stateNotifier.value.copyWith(
      status: SyncStatus.syncing,
    );

    // Snapshot the dirty flag and clear it *before* sending so a mutation that
    // lands mid-push re-sets it and is caught by the next cycle. Restored on a
    // push failure (see catch) since the change never reached the server.
    final bool wasDirty = _dirty;
    bool didPush = false;

    try {
      // PUSH local changes if the state is dirty.
      if (wasDirty && onGetPayload != null) {
        final AppSyncPayload payload = onGetPayload!();
        _dirty = false;

        // App settings carry their own real updatedAt; only push them when they
        // were actually mutated after the last successful sync, so a fresh pull
        // never gets clobbered by stale local defaults.
        final Map<String, dynamic>? settings = payload.appSettings;
        final DateTime? settingsUpdatedAt = settings == null
            ? null
            : DateTime.tryParse(settings['updatedAt'] as String? ?? '')?.toUtc();
        final bool pushSettings = settings != null &&
            settingsUpdatedAt != null &&
            settingsUpdatedAt.isAfter(
              _lastSyncedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
            );

        await _apiClient.postVoid('/sync', <String, dynamic>{
          'gameRecords': payload.gameRecords
              .map(
                (Map<String, dynamic> r) => <String, dynamic>{
                  'id': r['id'],
                  'data': jsonEncode(r),
                  'updatedAt':
                      (r['updatedAt'] as String?) ??
                      DateTime.now().toIso8601String(),
                  'deleted': r['deletedAt'] != null,
                },
              )
              .toList(growable: false),
          'sideboardDecks': payload.sideboardDecks
              .map(
                (Map<String, dynamic> d) => <String, dynamic>{
                  'id': d['id'],
                  'data': jsonEncode(d),
                  'updatedAt':
                      (d['updatedAt'] as String?) ??
                      DateTime.now().toIso8601String(),
                  'deleted': d['deletedAt'] != null,
                },
              )
              .toList(growable: false),
          if (pushSettings)
            'appSettings': <String, dynamic>{
              'data': jsonEncode(settings),
              'updatedAt': settingsUpdatedAt.toIso8601String(),
            },
        });
        didPush = true;
      }

      // PULL remote changes since the last successful sync.
      final String since =
          _lastSyncedAt?.toUtc().toIso8601String() ??
          DateTime.utc(2020).toIso8601String();
      final Map<String, dynamic> pulled = await _apiClient.get(
        '/sync',
        params: <String, dynamic>{'since': since},
      );

      if (onApplyPull != null) {
        await onApplyPull!(pulled);
      }

      // Advance the cursor using the server's clock (the same clock the server
      // filters rows by), not the local wall-clock. Falls back to local time
      // only if the server omitted it.
      _lastSyncedAt =
          DateTime.tryParse((pulled['serverTime'] as String?) ?? '')?.toUtc() ??
          DateTime.now().toUtc();
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _lastSyncKey,
        _lastSyncedAt!.toIso8601String(),
      );
      stateNotifier.value = stateNotifier.value.copyWith(
        status: SyncStatus.synced,
        lastSyncedAt: _lastSyncedAt,
        pendingPush: false,
        errorMessage: null,
      );
      return true;
    } catch (e) {
      // If the push never completed, the local changes are still unsent — keep
      // the dirty flag so the next cycle retries them.
      if (wasDirty && !didPush) {
        _dirty = true;
      }
      stateNotifier.value = stateNotifier.value.copyWith(
        status: SyncStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  @override
  void dispose() {
    stopAutoSync();
    stateNotifier.dispose();
    super.dispose();
  }
}
