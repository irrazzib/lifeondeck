import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../models/sync_state.dart';
import 'api_client.dart';
import 'auth_service.dart';

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

    try {
      // PUSH local changes if the state is dirty.
      if (_dirty && onGetPayload != null) {
        final AppSyncPayload payload = onGetPayload!();
        await _apiClient.postVoid('/sync', <String, dynamic>{
          'gameRecords': payload.gameRecords
              .map(
                (Map<String, dynamic> r) => <String, dynamic>{
                  'id': r['id'],
                  'data': jsonEncode(r),
                  'updatedAt':
                      (r['updatedAt'] as String?) ??
                      DateTime.now().toIso8601String(),
                  'deleted': false,
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
                  'deleted': false,
                },
              )
              .toList(growable: false),
          if (payload.appSettings != null)
            'appSettings': <String, dynamic>{
              'data': jsonEncode(payload.appSettings),
              'updatedAt': DateTime.now().toIso8601String(),
            },
        });
        _dirty = false;
      }

      // PULL remote changes since the last successful sync.
      final String since =
          _lastSyncedAt?.toIso8601String() ??
          DateTime(2020).toIso8601String();
      final Map<String, dynamic> pulled = await _apiClient.get(
        '/sync',
        params: <String, dynamic>{'since': since},
      );

      if (onApplyPull != null) {
        await onApplyPull!(pulled);
      }

      _lastSyncedAt = DateTime.now();
      stateNotifier.value = stateNotifier.value.copyWith(
        status: SyncStatus.synced,
        lastSyncedAt: _lastSyncedAt,
        pendingPush: false,
        errorMessage: null,
      );
      return true;
    } catch (e) {
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
