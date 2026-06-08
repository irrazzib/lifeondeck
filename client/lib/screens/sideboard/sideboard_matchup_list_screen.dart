import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../models/sideboard.dart';
import '../../models/game_record.dart';
import '../../models/app_settings.dart';
import 'deck_matchup_history_screen.dart';
import 'deck_notes_screen.dart';
import 'deck_statistics_screen.dart';

class SideboardMatchupListScreen extends StatefulWidget {
  const SideboardMatchupListScreen({
    super.key,
    required this.deck,
    required this.records,
    required this.settings,
  });

  final SideboardDeck deck;
  final List<GameRecord> records;
  final AppSettings settings;

  @override
  State<SideboardMatchupListScreen> createState() =>
      _SideboardMatchupListScreenState();
}

class _SideboardMatchupListScreenState
    extends State<SideboardMatchupListScreen> {
  late List<SideboardMatchup> _matchups;
  late List<GameRecord> _records;
  late String _userNotes;

  @override
  void initState() {
    super.initState();
    _matchups = List<SideboardMatchup>.from(widget.deck.matchups);
    _records = List<GameRecord>.from(widget.records);
    _userNotes = widget.deck.userNotes;
  }

  void _closeWithResult() {
    Navigator.of(context).pop(
      SideboardDeckEditResult(
        deck: widget.deck.copyWith(
          matchups: _matchups,
          userNotes: _userNotes.trim(),
        ),
        records: List<GameRecord>.from(_records),
      ),
    );
  }

  Future<void> _openUserNotes() async {
    final String? updated = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => DeckUserNotesScreen(
          deckName: widget.deck.name,
          initialNotes: _userNotes,
        ),
      ),
    );
    if (updated == null) {
      return;
    }
    setState(() {
      _userNotes = updated;
    });
  }

  Future<void> _openMatchupHistory() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DeckMatchupHistoryScreen(
          deck: widget.deck.copyWith(
            matchups: _matchups,
            userNotes: _userNotes,
          ),
          records: _records,
          mode: DeckSectionMode.matchupHistory,
        ),
      ),
    );
  }

  Future<void> _openSideboardPlans() async {
    final List<SideboardMatchup>? updated = await Navigator.of(context)
        .push<List<SideboardMatchup>>(
          MaterialPageRoute<List<SideboardMatchup>>(
            builder: (_) => DeckMatchupHistoryScreen(
              deck: widget.deck.copyWith(
                matchups: _matchups,
                userNotes: _userNotes,
              ),
              records: _records,
              mode: DeckSectionMode.sideboardPlans,
            ),
          ),
        );
    if (updated == null) {
      return;
    }
    setState(() {
      _matchups = updated;
    });
  }

  Future<void> _openStatistics() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DeckStatisticsScreen(
          deck: widget.deck.copyWith(
            matchups: _matchups,
            userNotes: _userNotes,
          ),
          records: _records,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings txt = context.txt;
    final String formatLabel = widget.deck.format.trim().isEmpty
        ? '-'
        : widget.deck.format.trim();

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
          title: Text(widget.deck.name),
          leading: IconButton(
            onPressed: _closeWithResult,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: const Color(0xFF1E1B1B),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Format: $formatLabel',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.86),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        txt.t('section.chooseSection'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _DeckSectionButton(
                icon: Icons.sticky_note_2_outlined,
                title: txt.t('section.userNotes'),
                subtitle: 'Write and update notes for this deck',
                onTap: _openUserNotes,
              ),
              const SizedBox(height: 10),
              _DeckSectionButton(
                icon: Icons.history_rounded,
                title: txt.t('section.matchupHistory'),
                subtitle: 'Saved matches played with this deck',
                onTap: _openMatchupHistory,
              ),
              const SizedBox(height: 10),
              _DeckSectionButton(
                icon: Icons.menu_book_rounded,
                title: txt.t('section.sideboardPlans'),
                subtitle: 'Manage side in/out plans by matchup',
                onTap: _openSideboardPlans,
              ),
              const SizedBox(height: 10),
              _DeckSectionButton(
                icon: Icons.query_stats_rounded,
                title: txt.t('section.statistics'),
                subtitle: 'Deck vs deck results from saved matches',
                onTap: _openStatistics,
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeckSectionButton extends StatelessWidget {
  const _DeckSectionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: const Color(0xFF1E1B1B),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, size: 22),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

