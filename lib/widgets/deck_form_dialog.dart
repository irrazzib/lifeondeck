import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../l10n/app_strings.dart';
import '../models/sideboard.dart';

/// Result returned by [showDeckFormDialog]: trimmed name and format.
typedef DeckFormResult = ({String name, String format});

/// Unified deck creation/edit dialog used by every flow that needs to add or
/// edit a [SideboardDeck]. Always asks for both name and format so that callers
/// can never end up with a deck missing its format.
///
/// Pass [editingDeck] for edit mode; pass [initialFormat] to pre-fill the
/// format field (e.g. from the current match context).
Future<DeckFormResult?> showDeckFormDialog(
  BuildContext context, {
  required List<SideboardDeck> existingDecks,
  required List<String> existingFormats,
  SideboardDeck? editingDeck,
  String initialName = '',
  String initialFormat = '',
}) {
  return showDialog<DeckFormResult>(
    context: context,
    builder: (BuildContext dialogContext) {
      return _DeckFormDialog(
        existingDecks: existingDecks,
        existingFormats: existingFormats,
        editingDeck: editingDeck,
        initialName: editingDeck?.name ?? initialName,
        initialFormat: editingDeck?.format ?? initialFormat,
      );
    },
  );
}

class _DeckFormDialog extends StatefulWidget {
  const _DeckFormDialog({
    required this.existingDecks,
    required this.existingFormats,
    required this.editingDeck,
    required this.initialName,
    required this.initialFormat,
  });

  final List<SideboardDeck> existingDecks;
  final List<String> existingFormats;
  final SideboardDeck? editingDeck;
  final String initialName;
  final String initialFormat;

  @override
  State<_DeckFormDialog> createState() => _DeckFormDialogState();
}

class _DeckFormDialogState extends State<_DeckFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _formatController;
  String? _nameErrorText;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _formatController = TextEditingController(text: widget.initialFormat);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _formatController.dispose();
    super.dispose();
  }

  String _canonicalizeFormat(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final String key = trimmed.toLowerCase();
    for (final String existing in widget.existingFormats) {
      if (existing.toLowerCase() == key) {
        return existing;
      }
    }
    return trimmed;
  }

  void _submit() {
    final AppStrings txt = context.txt;
    final String name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _nameErrorText = txt.t('deckForm.nameRequired');
      });
      return;
    }
    if (hasDeckNameConflict(
      widget.existingDecks,
      name,
      excludedDeckId: widget.editingDeck?.id ?? '',
    )) {
      setState(() {
        _nameErrorText = txt.t('deckForm.nameConflict');
      });
      return;
    }
    Navigator.of(context).pop(
      (name: name, format: _canonicalizeFormat(_formatController.text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings txt = context.txt;
    final bool isEdit = widget.editingDeck != null;
    return AlertDialog(
      title: Text(
        isEdit ? txt.t('deckList.editDeck') : txt.t('deckList.newDeck'),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _nameController,
              autofocus: true,
              onChanged: (_) {
                if (_nameErrorText == null) {
                  return;
                }
                setState(() {
                  _nameErrorText = null;
                });
              },
              decoration: InputDecoration(
                labelText: txt.t('field.deckName'),
                errorText: _nameErrorText,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _formatController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: txt.t('field.format'),
                hintText: 'Modern, Commander, Edison...',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            if (widget.existingFormats.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                txt.t('deckList.existingFormats'),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.74),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final String format in widget.existingFormats)
                    ChoiceChip(
                      label: Text(format),
                      selected:
                          _formatController.text.trim().toLowerCase() ==
                          format.toLowerCase(),
                      onSelected: (_) {
                        setState(() {
                          _formatController.text = format;
                        });
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(txt.t('common.cancel')),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(
            isEdit ? txt.t('common.save') : txt.t('common.create'),
          ),
        ),
      ],
    );
  }
}
