import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../l10n/app_strings.dart';
import '../models/match.dart';
import '../models/sideboard.dart';
import 'clearable_text_field.dart';
import 'searchable_combo_field.dart';
import 'text_prompt_dialog.dart';

@immutable
class MatchEditorInput {
  const MatchEditorInput({
    required this.decks,
    this.tcgKey = '',
    this.matchName = '',
    this.opponentName = '',
    this.format = '',
    this.deckId = '',
    this.deckName = '',
    this.opponentDeckId = '',
    this.opponentDeckName = '',
    this.tag = '',
    this.matchDate,
    this.gameStage = 'G1',
    this.result = '',
    this.showMatchName = true,
    this.showOpponent = true,
    this.showFormat = true,
    this.showDeck = false,
    this.showDeckInUse = false,
    this.showOpponentDeck = true,
    this.showTag = true,
    this.showDate = false,
    this.showGameStage = false,
    this.showResult = false,
    this.allowCreateDeck = false,
  });

  final List<SideboardDeck> decks;
  final String tcgKey;
  final String matchName;
  final String opponentName;
  final String format;
  final String deckId;
  final String deckName;
  final String opponentDeckId;
  final String opponentDeckName;
  final String tag;
  final DateTime? matchDate;
  final String gameStage;
  final String result;

  // visibility flags
  final bool showMatchName;
  final bool showOpponent;
  final bool showFormat;
  final bool showDeck;        // deck picker, label "Deck"
  final bool showDeckInUse;   // same backing field, label "Deck in use"
  final bool showOpponentDeck;
  final bool showTag;
  final bool showDate;
  final bool showGameStage;
  final bool showResult;

  final bool allowCreateDeck;
}

@immutable
class MatchEditorResult {
  const MatchEditorResult({
    required this.matchName,
    required this.opponentName,
    required this.format,
    required this.deckId,
    required this.deckName,
    required this.opponentDeckId,
    required this.opponentDeckName,
    required this.tag,
    this.matchDate,
    required this.gameStage,
    required this.result,
    required this.createdDecks,
  });

  final String matchName;
  final String opponentName;
  final String format;
  final String deckId;
  final String deckName;
  final String opponentDeckId;
  final String opponentDeckName;
  final String tag;
  final DateTime? matchDate;
  final String gameStage;
  final String result;
  final List<SideboardDeck> createdDecks;
}

class MatchEditorDialog extends StatefulWidget {
  const MatchEditorDialog({
    required this.title,
    required this.input,
    this.extraContentBuilder,
  });

  final String title;
  final MatchEditorInput input;

  /// Optional screen-specific extra widgets appended below the common fields.
  /// Receives the dialog's [StateSetter] so the section can trigger rebuilds.
  final Widget Function(StateSetter setState)? extraContentBuilder;

  @override
  State<MatchEditorDialog> createState() => _MatchEditorDialogState();
}

class _MatchEditorDialogState extends State<MatchEditorDialog> {
  late final TextEditingController _matchNameCtrl;
  late final TextEditingController _opponentCtrl;
  late final TextEditingController _tagCtrl;

  late List<SideboardDeck> _decks;
  late String _format;
  late String _deckId;
  late String _deckName;
  late String _opponentDeckId;
  late String _opponentDeckName;
  late DateTime _date;
  late String _gameStage;
  late String _result;
  final List<SideboardDeck> _createdDecks = <SideboardDeck>[];

  @override
  void initState() {
    super.initState();
    final MatchEditorInput i = widget.input;
    _matchNameCtrl = TextEditingController(text: i.matchName);
    _opponentCtrl = TextEditingController(text: i.opponentName);
    _tagCtrl = TextEditingController(text: i.tag);
    _decks = List<SideboardDeck>.from(i.decks);
    _format = i.format.trim();
    _deckId = _resolveId(i.deckId, i.deckName);
    _deckName = (_deckId.isEmpty && i.deckName.trim().isNotEmpty)
        ? i.deckName.trim()
        : '';
    _opponentDeckId = _resolveId(i.opponentDeckId, i.opponentDeckName);
    _opponentDeckName =
        (_opponentDeckId.isEmpty && i.opponentDeckName.trim().isNotEmpty)
            ? i.opponentDeckName.trim()
            : '';
    _date = i.matchDate ?? DateTime.now();
    _gameStage =
        supportedGameStages.contains(i.gameStage) ? i.gameStage : 'G1';
    _result = normalizedMatchResultOrEmpty(i.result);
    _normalizeDeckSelections();
  }

  @override
  void dispose() {
    _matchNameCtrl.dispose();
    _opponentCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  String _resolveId(String id, String name) {
    final String trimmedId = id.trim();
    if (trimmedId.isNotEmpty && _byId(trimmedId) != null) {
      return trimmedId;
    }
    if (name.trim().isNotEmpty) {
      return _byName(name)?.id ?? '';
    }
    return '';
  }

  SideboardDeck? _byId(String id) {
    if (id.isEmpty) return null;
    for (final SideboardDeck d in _decks) {
      if (d.id == id) return d;
    }
    return null;
  }

  SideboardDeck? _byName(String name) => findUniqueDeckByName(_decks, name);

  List<SideboardDeck> _filteredDecks() =>
      filterDecksByFormat(_decks, _format);

  List<String> _formatOptions() {
    final Set<String> set = <String>{};
    for (final SideboardDeck d in _decks) {
      final String f = d.format.trim();
      if (f.isNotEmpty) set.add(f);
    }
    if (_format.trim().isNotEmpty) set.add(_format.trim());
    final List<String> sorted = set.toList(growable: false);
    sorted.sort(
      (String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()),
    );
    return sorted;
  }

  void _normalizeDeckSelections() {
    if (_deckId.isNotEmpty) {
      final SideboardDeck? d = _byId(_deckId);
      if (d == null || !deckMatchesFormat(d, _format)) {
        _deckId = '';
      }
    }
    if (_opponentDeckId.isNotEmpty) {
      final SideboardDeck? d = _byId(_opponentDeckId);
      if (d == null || !deckMatchesFormat(d, _format)) {
        _opponentDeckId = '';
      }
    }
  }

  Future<String?> _addDeck(String query, {bool isOpponent = false}) async {
    if (!widget.input.allowCreateDeck) {
      return _addCustomName(query, isOpponent: isOpponent);
    }
    final String? name = await showTextPromptDialog(
      context,
      title: isOpponent
          ? 'New opponent deck'
          : context.txt.t('field.addNewDeck'),
      initialValue: query,
      hintText: context.txt.t('field.deckName'),
    );
    if (name == null) return null;
    final String trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final SideboardDeck? existing = _byName(trimmed);
    if (existing != null) return existing.id;
    final SideboardDeck newDeck = SideboardDeck(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: trimmed,
      createdAt: DateTime.now(),
      isFavorite: false,
      userNotes: '',
      matchups: const <SideboardMatchup>[],
      format: _format.trim(),
      tag: '',
      tcgKey: widget.input.tcgKey,
    );
    setState(() {
      _decks = <SideboardDeck>[newDeck, ..._decks];
      _createdDecks.add(newDeck);
    });
    return newDeck.id;
  }

  Future<String?> _addCustomName(
    String query, {
    bool isOpponent = false,
  }) async {
    final String? name = await showTextPromptDialog(
      context,
      title: context.txt.t('field.addNewDeck'),
      initialValue: isOpponent ? _opponentDeckName : _deckName,
      hintText: context.txt.t('field.deckName'),
    );
    if (name == null) return null;
    final String trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    setState(() {
      if (isOpponent) {
        _opponentDeckId = '';
        _opponentDeckName = trimmed;
      } else {
        _deckId = '';
        _deckName = trimmed;
      }
    });
    return isOpponent ? '__custom_opp_deck__' : '__custom_deck__';
  }

  void _save() {
    final SideboardDeck? deckObj = _byId(_deckId);
    final SideboardDeck? opponentDeckObj = _byId(_opponentDeckId);
    Navigator.of(context).pop(
      MatchEditorResult(
        matchName: _matchNameCtrl.text.trim(),
        opponentName: _opponentCtrl.text.trim(),
        format: _format,
        deckId: deckObj?.id ?? '',
        deckName: deckObj?.name ?? _deckName,
        opponentDeckId: opponentDeckObj?.id ?? '',
        opponentDeckName: opponentDeckObj?.name ?? _opponentDeckName,
        tag: _tagCtrl.text.trim(),
        matchDate: widget.input.showDate ? _date : widget.input.matchDate,
        gameStage: _gameStage,
        result: _result,
        createdDecks: List<SideboardDeck>.unmodifiable(_createdDecks),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MatchEditorInput cfg = widget.input;
    final List<Widget> fields = <Widget>[];

    void add(Widget w) {
      if (fields.isNotEmpty) fields.add(const SizedBox(height: 10));
      fields.add(w);
    }

    if (cfg.showMatchName) {
      add(ClearableTextField(
        controller: _matchNameCtrl,
        decoration: InputDecoration(
          labelText: context.txt.t('field.matchName'),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ));
    }

    if (cfg.showOpponent) {
      add(ClearableTextField(
        controller: _opponentCtrl,
        decoration: InputDecoration(
          labelText: context.txt.t('field.opponentName'),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ));
    }

    if (cfg.showFormat) {
      add(SearchableComboField(
        value: _format,
        decoration: InputDecoration(
          labelText: context.txt.t('field.format'),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        fixedItems: <ComboItem>[
          ComboItem(value: '', label: context.txt.t('field.noFormat')),
        ],
        items: _formatOptions()
            .map((String f) => ComboItem(value: f, label: f))
            .toList(growable: false),
        addLabel: context.txt.t('field.addNewFormat'),
        onAdd: (String q) async {
          final String? created = await showTextPromptDialog(
            context,
            title: 'New format',
            initialValue: q,
            hintText: 'Modern, Edison, Commander...',
          );
          if (created == null) return null;
          final String trimmed = created.trim();
          return trimmed.isEmpty ? null : trimmed;
        },
        onChanged: (String value) {
          setState(() {
            _format = value.trim();
            _normalizeDeckSelections();
          });
        },
      ));
    }

    if (cfg.showOpponentDeck) {
      final String oppValue = _opponentDeckId.isNotEmpty
          ? _opponentDeckId
          : (_opponentDeckName.isNotEmpty ? '__custom_opp_deck__' : '');
      add(SearchableComboField(
        key: ValueKey<String>('opp_deck_${_opponentDeckId}_$_opponentDeckName'),
        value: oppValue,
        decoration: InputDecoration(
          labelText: context.txt.t('field.opponentDeck'),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        fixedItems: <ComboItem>[
          ComboItem(
            value: '',
            label: context.txt.t('field.noOpponentDeck'),
          ),
        ],
        items: <ComboItem>[
          ..._filteredDecks()
              .map((SideboardDeck d) => ComboItem(value: d.id, label: d.name)),
          if (_opponentDeckName.isNotEmpty)
            ComboItem(
              value: '__custom_opp_deck__',
              label: _opponentDeckName,
            ),
        ],
        addLabel: context.txt.t('field.addNewDeck'),
        onAdd: (String q) => _addDeck(q, isOpponent: true),
        onChanged: (String value) {
          if (value == '__custom_opp_deck__') return;
          setState(() {
            _opponentDeckId = value.trim();
            _opponentDeckName = '';
            _normalizeDeckSelections();
          });
        },
      ));
    }

    if (cfg.showTag) {
      add(ClearableTextField(
        controller: _tagCtrl,
        decoration: const InputDecoration(
          labelText: 'Tag',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ));
    }

    if (cfg.showDate) {
      add(InkWell(
        onTap: () async {
          final DateTime? pickedDate = await showDatePicker(
            context: context,
            initialDate: _date,
            firstDate: DateTime(2000),
            lastDate: DateTime.now().add(const Duration(days: 1)),
          );
          if (pickedDate == null) return;
          final TimeOfDay? pickedTime = await showTimePicker(
            context: context, // ignore: use_build_context_synchronously
            initialTime: TimeOfDay.fromDateTime(_date),
          );
          setState(() {
            _date = DateTime(
              pickedDate.year,
              pickedDate.month,
              pickedDate.day,
              pickedTime?.hour ?? _date.hour,
              pickedTime?.minute ?? _date.minute,
            );
          });
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: context.txt.t('field.date'),
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
          ),
          child: Text(
            formatDateTime(_date, context),
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ));
    }

    if (cfg.showGameStage) {
      add(SearchableComboField(
        value: _gameStage,
        decoration: const InputDecoration(
          labelText: 'Game',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        items: supportedGameStages
            .map((String s) => ComboItem(value: s, label: s))
            .toList(growable: false),
        onChanged: (String value) {
          setState(() {
            _gameStage = value;
          });
        },
      ));
    }

    if (cfg.showDeck || cfg.showDeckInUse) {
      final String deckValue = _deckId.isNotEmpty
          ? _deckId
          : (_deckName.isNotEmpty ? '__custom_deck__' : '');
      add(SearchableComboField(
        key: ValueKey<String>('deck_${_deckId}_$_deckName'),
        value: deckValue,
        decoration: InputDecoration(
          labelText: cfg.showDeckInUse
              ? context.txt.t('field.deckInUse')
              : context.txt.t('field.deck'),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        fixedItems: <ComboItem>[
          ComboItem(value: '', label: context.txt.t('field.noDeck')),
        ],
        items: <ComboItem>[
          ..._filteredDecks()
              .map((SideboardDeck d) => ComboItem(value: d.id, label: d.name)),
          if (_deckName.isNotEmpty)
            ComboItem(value: '__custom_deck__', label: _deckName),
        ],
        addLabel: context.txt.t('field.addNewDeck'),
        onAdd: (String q) => _addDeck(q),
        onChanged: (String value) {
          if (value == '__custom_deck__') return;
          setState(() {
            _deckId = value.trim();
            _deckName = '';
            if (_deckId.isNotEmpty) {
              final SideboardDeck? d = _byId(_deckId);
              if (d != null &&
                  _format.trim().isEmpty &&
                  d.format.trim().isNotEmpty) {
                _format = d.format.trim();
              }
            }
            _normalizeDeckSelections();
          });
        },
      ));
    }

    if (cfg.showResult) {
      add(SearchableComboField(
        value: _result,
        decoration: const InputDecoration(
          labelText: 'Result',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        fixedItems: const <ComboItem>[
          ComboItem(value: '', label: 'No result'),
        ],
        items: supportedMatchResults
            .map((String s) => ComboItem(value: s, label: s))
            .toList(growable: false),
        onChanged: (String value) {
          setState(() {
            _result = value.trim();
          });
        },
      ));
    }

    if (widget.extraContentBuilder != null) {
      fields.add(widget.extraContentBuilder!(setState));
    }

    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: fields),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.txt.t('common.cancel')),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(context.txt.t('common.save')),
        ),
      ],
    );
  }
}

Future<MatchEditorResult?> showMatchEditorDialog(
  BuildContext context, {
  required String title,
  required MatchEditorInput input,
  Widget Function(StateSetter setState)? extraContentBuilder,
}) {
  return showDialog<MatchEditorResult>(
    context: context,
    builder: (_) => MatchEditorDialog(
      title: title,
      input: input,
      extraContentBuilder: extraContentBuilder,
    ),
  );
}
