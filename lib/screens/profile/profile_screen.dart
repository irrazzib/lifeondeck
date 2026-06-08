import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../models/sync_state.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/sync_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.authService,
    required this.syncService,
    required this.apiClient,
    required this.onClearLocalData,
  });

  final AuthService authService;
  final SyncService syncService;
  final ApiClient apiClient;

  /// Wipes account-scoped data from this device (records, decks, settings) and
  /// resets the sync cursor. Surfaced only while signed out.
  final Future<void> Function() onClearLocalData;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _signingIn = false;

  /// API reachability: null = probing, true = healthy, false = unreachable.
  bool? _apiHealthy;

  @override
  void initState() {
    super.initState();
    _checkApiHealth();
  }

  Future<void> _checkApiHealth() async {
    setState(() => _apiHealthy = null);
    final bool ok = await widget.apiClient.checkHealth();
    if (mounted) setState(() => _apiHealthy = ok);
  }

  Future<void> _handleSignIn() async {
    setState(() => _signingIn = true);
    await widget.authService.signInWithGoogle();
    if (mounted) setState(() => _signingIn = false);
  }

  Future<void> _handleSignOut() async {
    final AppStrings txt = context.txt;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(txt.t('account.signOut')),
        content: Text(txt.t('account.subtitleSignedOut')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(txt.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(txt.t('account.signOut')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.authService.signOut();
    }
  }

  Future<void> _handleClearLocalData() async {
    final AppStrings txt = context.txt;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(txt.t('account.clearLocalData')),
        content: Text(txt.t('account.clearLocalDataConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(txt.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(txt.t('account.clearLocalData')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.onClearLocalData();
    }
  }

  String _formatSyncTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '< 1 min';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildApiStatus(AppStrings txt) {
    final (IconData icon, Color color, String label) = switch (_apiHealthy) {
      null => (Icons.hourglass_empty, Colors.grey, txt.t('account.apiChecking')),
      true => (Icons.check_circle, Colors.green, txt.t('account.apiOnline')),
      false => (Icons.error_outline, Colors.red, txt.t('account.apiOffline')),
    };
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(txt.t('account.apiSection')),
        subtitle: Text(label, style: TextStyle(color: color)),
        trailing: IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: txt.t('account.apiSection'),
          onPressed: _apiHealthy == null ? null : _checkApiHealth,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings txt = context.txt;
    return Scaffold(
      appBar: AppBar(title: Text(txt.t('account.title'))),
      body: ListenableBuilder(
        listenable: widget.authService,
        builder: (context, _) {
          final authenticated = widget.authService.isAuthenticated;
          return authenticated
              ? _buildAuthenticated(txt)
              : _buildUnauthenticated(txt);
        },
      ),
    );
  }

  Widget _buildUnauthenticated(AppStrings txt) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_circle_outlined, size: 80),
            const SizedBox(height: 16),
            Text(
              txt.t('account.title'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              txt.t('account.subtitleSignedOut'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            _signingIn
                ? const CircularProgressIndicator()
                : OutlinedButton.icon(
                    onPressed: _handleSignIn,
                    icon: const Icon(Icons.login),
                    label: Text(txt.t('account.signInGoogle')),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                    ),
                  ),
            const SizedBox(height: 24),
            _buildApiStatus(txt),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _handleClearLocalData,
              icon: const Icon(Icons.delete_outline),
              label: Text(txt.t('account.clearLocalData')),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthenticated(AppStrings txt) {
    final user = widget.authService.currentUser!;
    final initial = user.displayName.isNotEmpty
        ? user.displayName[0].toUpperCase()
        : user.email[0].toUpperCase();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Avatar + user info
          Column(
            children: [
              CircleAvatar(
                radius: 40,
                child: Text(
                  initial,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                user.displayName,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                user.email,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          // Sync section
          Text(
            txt.t('account.syncSection'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<SyncState>(
            valueListenable: widget.syncService.stateNotifier,
            builder: (context, state, _) {
              final (IconData icon, Color color, String label) =
                  switch (state.status) {
                SyncStatus.syncing => (
                    Icons.sync,
                    Colors.blue,
                    txt.t('account.syncing'),
                  ),
                SyncStatus.synced => (
                    Icons.cloud_done,
                    Colors.green,
                    state.lastSyncedAt != null
                        ? txt.t(
                            'account.lastSync',
                            params: <String, Object?>{
                              'time': _formatSyncTime(state.lastSyncedAt),
                            },
                          )
                        : txt.t('account.syncOk'),
                  ),
                SyncStatus.error => (
                    Icons.cloud_off,
                    Colors.red,
                    txt.t('account.syncError'),
                  ),
                SyncStatus.offline => (
                    Icons.wifi_off,
                    Colors.orange,
                    txt.t('account.offline'),
                  ),
                SyncStatus.idle => (
                    Icons.cloud_queue,
                    Colors.grey,
                    txt.t('account.neverSynced'),
                  ),
              };

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          state.status == SyncStatus.syncing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(icon, color: color, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              label,
                              style: TextStyle(fontSize: 13, color: color),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonal(
                          onPressed: state.status == SyncStatus.syncing
                              ? null
                              : () => widget.syncService.syncNow(),
                          child: Text(txt.t('account.syncNow')),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildApiStatus(txt),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: _handleSignOut,
            icon: const Icon(Icons.logout),
            label: Text(txt.t('account.signOut')),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(color: Theme.of(context).colorScheme.error),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}
