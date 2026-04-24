import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';

class DeckUserNotesScreen extends StatefulWidget {
  const DeckUserNotesScreen({
    required this.deckName,
    required this.initialNotes,
  });

  final String deckName;
  final String initialNotes;

  @override
  State<DeckUserNotesScreen> createState() => _DeckUserNotesScreenState();
}

class _DeckUserNotesScreenState extends State<DeckUserNotesScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNotes);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _closeWithSave() {
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        _closeWithSave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.txt.t('section.userNotes')),
          leading: IconButton(
            onPressed: _closeWithSave,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.deckName,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.74),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: 'Write notes for this deck...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

