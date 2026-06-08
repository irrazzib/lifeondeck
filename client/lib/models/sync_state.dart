import 'package:flutter/foundation.dart';

enum SyncStatus { idle, syncing, synced, error, offline }

@immutable
class SyncState {
  const SyncState({
    this.status = SyncStatus.idle,
    this.lastSyncedAt,
    this.errorMessage,
    this.pendingPush = false,
  });

  final SyncStatus status;
  final DateTime? lastSyncedAt;
  final String? errorMessage;
  final bool pendingPush;

  SyncState copyWith({
    SyncStatus? status,
    DateTime? lastSyncedAt,
    String? errorMessage,
    bool? pendingPush,
  }) => SyncState(
    status: status ?? this.status,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    errorMessage: errorMessage,
    pendingPush: pendingPush ?? this.pendingPush,
  );
}
