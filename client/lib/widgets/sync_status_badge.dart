import 'package:flutter/material.dart';

import '../models/sync_state.dart';
import '../services/sync_service.dart';

class SyncStatusBadge extends StatelessWidget {
  const SyncStatusBadge({
    super.key,
    required this.syncService,
    this.onTap,
  });

  final SyncService syncService;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncState>(
      valueListenable: syncService.stateNotifier,
      builder: (BuildContext context, SyncState state, _) {
        final (IconData icon, Color color, String tooltip) =
            switch (state.status) {
              SyncStatus.syncing => (
                Icons.sync,
                Colors.blue,
                'Sincronizzazione...',
              ),
              SyncStatus.synced => (
                Icons.cloud_done,
                Colors.green,
                'Sincronizzato ${_formatTime(state.lastSyncedAt)}',
              ),
              SyncStatus.error => (
                Icons.cloud_off,
                Colors.red,
                state.errorMessage ?? 'Errore sync',
              ),
              SyncStatus.offline => (
                Icons.wifi_off,
                Colors.orange,
                'Offline',
              ),
              SyncStatus.idle => (
                Icons.cloud_queue,
                Colors.grey,
                'Non sincronizzato',
              ),
            };

        return IconButton(
          icon: state.status == SyncStatus.syncing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, color: color, size: 20),
          tooltip: tooltip,
          onPressed: onTap,
        );
      },
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
