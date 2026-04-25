import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../l10n/app_strings.dart';
import '../../widgets/searchable_combo_field.dart';
import '../../models/app_settings.dart';
import '../../models/game_record.dart';
import '../../models/sideboard.dart';
import 'sideboard_matchup_list_screen.dart';
import 'dart:math';

enum SideboardDeckSortMode { alphabetical, createdAt, format }

enum SideboardMatchupSortMode { alphabetical, createdAt }

class SideboardDeckListScreen extends StatefulWidget {
  const SideboardDeckListScreen({
    super.key,
    required this.decks,
    required this.records,
    required this.settings,
    required this.tcg,
  });

  final List<SideboardDeck> decks;
  final List<GameRecord> records;
  final AppSettings settings;
  final SupportedTcg tcg;

  @override
  State<SideboardDeckListScreen> createState() =>
      _SideboardDeckListScreenState();
}

class _SideboardDeckListScreenState extends State<SideboardDeckListScreen> {
  static const int _deckPageSize = 5;

  late List<SideboardDeck> _decks;
  late List<GameRecord> _records;
  SideboardDeckSortMode _sortMode = SideboardDeckSortMode.createdAt;
  bool _showFavoritesOnly = false;
  String _selectedDeckFormatFilter = '';
  String _selectedDeckTagFilter = '';
  int _visibleDeckCount = _deckPageSize;
  bool _filtersExpanded = true;

  @override
  void initState() {
    super.initState();
    _decks = List<SideboardDeck>.from(widget.decks);
    _records = List<GameRecord>.from(widget.records);
  }

  void _closeWithResult() {
    Navigator.of(context).pop(
      SideboardBookResult(
        decks: List<SideboardDeck>.from(_decks),
        records: List<GameRecord>.from(_records),
      ),
    );
  }

  List<String> _existingDeckTags() {
    final Set<String> uniqueTags = <String>{};
    for (final SideboardDeck deck in _decks) {
      final String tag = deck.tag.trim();
      if (tag.isEmpty) {
        continue;
      }
      uniqueTags.add(tag);
    }
    final List<String> sorted = uniqueTags.toList(growable: false);
    sorted.sort((String a, String b) {
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
    return sorted;
  }

  bool get _hasActiveDeckFilters {
    return _showFavoritesOnly ||
        _selectedDeckFormatFilter.isNotEmpty ||
        _selectedDeckTagFilter.isNotEmpty;
  }

  void _clearDeckFilters() {
    setState(() {
      _showFavoritesOnly = false;
      _selectedDeckFormatFilter = '';
      _selectedDeckTagFilter = '';
    });
  }

  List<SideboardDeck> _sortedAndFilteredDecks({
    required String selectedFormatFilter,
    required String selectedTagFilter,
  }) {
    final List<SideboardDeck> sorted = _decks
        .where((SideboardDeck deck) {
          if (_showFavoritesOnly && !deck.isFavorite) {
            return false;
          }
          if (selectedFormatFilter.isNotEmpty &&
              deck.format.trim().toLowerCase() !=
                  selectedFormatFilter.trim().toLowerCase()) {
            return false;
          }
          if (selectedTagFilter.isNotEmpty &&
              deck.tag.trim().toLowerCase() !=
                  selectedTagFilter.trim().toLowerCase()) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
    switch (_sortMode) {
      case SideboardDeckSortMode.alphabetical:
        sorted.sort((SideboardDeck a, SideboardDeck b) {
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
      case SideboardDeckSortMode.createdAt:
        sorted.sort((SideboardDeck a, SideboardDeck b) {
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
      case SideboardDeckSortMode.format:
        sorted.sort((SideboardDeck a, SideboardDeck b) {
          final String formatA = a.format.trim().toLowerCase();
          final String formatB = b.format.trim().toLowerCase();
          if (formatA.isEmpty != formatB.isEmpty) {
            return formatA.isEmpty ? 1 : -1;
          }
          final int byFormat = formatA.compareTo(formatB);
          if (byFormat != 0) {
            return byFormat;
          }
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
    }
    return sorted;
  }

  List<String> _existingDeckFormats() {
    final Set<String> uniqueFormats = <String>{};
    for (final SideboardDeck deck in _decks) {
      final String format = deck.format.trim();
      if (format.isEmpty) {
        continue;
      }
      uniqueFormats.add(format);
    }
    for (final GameRecord record in _records) {
      final String format = record.matchFormat.trim();
      if (format.isEmpty) {
        continue;
      }
      uniqueFormats.add(format);
    }
    final List<String> sorted = uniqueFormats.toList(growable: false);
    sorted.sort((String a, String b) {
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
    return sorted;
  }

  Future<({String name, String format})?> _promptNewDeckData({
    SideboardDeck? initialDeck,
  }) async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController formatController = TextEditingController();
    String? nameErrorText;
    if (initialDeck != null) {
      nameController.text = initialDeck.name;
      formatController.text = initialDeck.format;
    }
    final List<String> existingFormats = _existingDeckFormats();
    try {
      final bool? shouldCreate = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              return AlertDialog(
                title: Text(initialDeck == null ? context.txt.t('deckList.newDeck') : context.txt.t('deckList.editDeck')),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameController,
                        onChanged: (_) {
                          if (nameErrorText == null) {
                            return;
                          }
                          setDialogState(() {
                            nameErrorText = null;
                          });
                        },
                        decoration: InputDecoration(
                          labelText: context.txt.t('field.deckName'),
                          errorText: nameErrorText,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: formatController,
                        decoration: InputDecoration(
                          labelText: context.txt.t('field.format'),
                          hintText: 'Modern, Commander, Edison...',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      if (existingFormats.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          context.txt.t('deckList.existingFormats'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.74),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final String format in existingFormats)
                              ChoiceChip(
                                label: Text(format),
                                selected:
                                    formatController.text
                                        .trim()
                                        .toLowerCase() ==
                                    format.toLowerCase(),
                                onSelected: (_) {
                                  formatController.text = format;
                                  setDialogState(() {});
                                },
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(context.txt.t('common.cancel')),
                  ),
                  FilledButton(
                    onPressed: () {
                      final String candidateName = nameController.text.trim();
                      if (candidateName.isEmpty) {
                        setDialogState(() {
                          nameErrorText = 'Deck name is required.';
                        });
                        return;
                      }
                      if (hasDeckNameConflict(
                        _decks,
                        candidateName,
                        excludedDeckId: initialDeck?.id ?? '',
                      )) {
                        setDialogState(() {
                          nameErrorText =
                              'A deck with this name already exists.';
                        });
                        return;
                      }
                      Navigator.of(context).pop(true);
                    },
                    child: Text(initialDeck == null ? context.txt.t('common.create') : context.txt.t('common.save')),
                  ),
                ],
              );
            },
          );
        },
      );

      if (shouldCreate != true) {
        return null;
      }

      final String name = nameController.text.trim();
      final String format = formatController.text.trim();
      if (name.isEmpty) {
        return null;
      }

      return (name: name, format: format);
    } finally {
      disposeTextControllersLater(<TextEditingController>[
        nameController,
        formatController,
      ]);
    }
  }

  Future<bool> _confirmAutoMatchupForFormat(String format) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(context.txt.t('deckList.syncMatchupsTitle')),
          content: Text(
            context.txt.t('deckList.syncMatchupsBody', params: {'format': format}),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.txt.t('common.no')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.txt.t('common.yes')),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  String _normalizedMatchupName(String name) {
    return name.trim().toLowerCase();
  }

  List<SideboardMatchup> _deduplicateMatchupsByName(
    List<SideboardMatchup> matchups,
  ) {
    final Set<String> seen = <String>{};
    final List<SideboardMatchup> deduplicated = <SideboardMatchup>[];

    for (final SideboardMatchup matchup in matchups) {
      final String key = _normalizedMatchupName(matchup.name);
      if (key.isEmpty || seen.contains(key)) {
        continue;
      }
      seen.add(key);
      deduplicated.add(matchup);
    }

    return deduplicated;
  }

  List<SideboardDeck> _renameDeckReferencesInMatchups({
    required List<SideboardDeck> decks,
    required String oldName,
    required String newName,
  }) {
    final String normalizedOldName = _normalizedMatchupName(oldName);
    final String trimmedNewName = newName.trim();
    if (normalizedOldName.isEmpty || trimmedNewName.isEmpty) {
      return List<SideboardDeck>.from(decks);
    }
    return decks
        .map((SideboardDeck deck) {
          final List<SideboardMatchup> updatedMatchups = deck.matchups
              .map((SideboardMatchup matchup) {
                if (_normalizedMatchupName(matchup.name) != normalizedOldName) {
                  return matchup;
                }
                return matchup.copyWith(name: trimmedNewName);
              })
              .toList(growable: false);
          return deck.copyWith(
            matchups: _deduplicateMatchupsByName(updatedMatchups),
          );
        })
        .toList(growable: false);
  }

  List<GameRecord> _renameDeckReferencesInRecords({
    required List<GameRecord> records,
    required SideboardDeck previousDeck,
    required SideboardDeck updatedDeck,
  }) {
    final String normalizedOldName = normalizeDeckName(previousDeck.name);
    final String updatedName = updatedDeck.name.trim();
    if (normalizedOldName.isEmpty || updatedName.isEmpty) {
      return List<GameRecord>.from(records);
    }
    final String updatedDeckId = updatedDeck.id.trim();
    return records
        .map((GameRecord record) {
          final bool deckMatches = updatedDeckId.isNotEmpty
              ? record.deckId.trim() == updatedDeckId
              : normalizeDeckName(record.deckName) == normalizedOldName;
          final bool opponentDeckMatches = updatedDeckId.isNotEmpty
              ? record.opponentDeckId.trim() == updatedDeckId
              : normalizeDeckName(record.opponentDeckName) ==
                    normalizedOldName;
          return record.copyWith(
            deckName: deckMatches ? updatedName : record.deckName,
            opponentDeckName: opponentDeckMatches
                ? updatedName
                : record.opponentDeckName,
          );
        })
        .toList(growable: false);
  }

  List<SideboardDeck> _synchronizeFormatMatchupsForNewDeck({
    required List<SideboardDeck> decks,
    required SideboardDeck newDeck,
  }) {
    final String normalizedFormat = newDeck.format.trim().toLowerCase();
    if (normalizedFormat.isEmpty) {
      return List<SideboardDeck>.from(decks);
    }

    final List<SideboardDeck> updatedDecks = List<SideboardDeck>.from(decks);
    final int newDeckIndex = updatedDecks.indexWhere(
      (SideboardDeck deck) => deck.id == newDeck.id,
    );
    if (newDeckIndex < 0) {
      return updatedDecks;
    }

    final List<int> sameFormatIndexes = <int>[];
    for (int index = 0; index < updatedDecks.length; index += 1) {
      if (updatedDecks[index].format.trim().toLowerCase() == normalizedFormat) {
        sameFormatIndexes.add(index);
      }
    }
    if (sameFormatIndexes.isEmpty) {
      return updatedDecks;
    }

    final DateTime now = DateTime.now();
    int matchupSeed = 0;

    final String newDeckName = newDeck.name.trim();
    final String newDeckNameKey = _normalizedMatchupName(newDeckName);
    final Map<String, String> inheritedNames = <String, String>{};

    void collectInheritedName(String rawName) {
      final String trimmed = rawName.trim();
      final String key = _normalizedMatchupName(trimmed);
      if (key.isEmpty || inheritedNames.containsKey(key)) {
        return;
      }
      inheritedNames[key] = trimmed;
    }

    for (final int index in sameFormatIndexes) {
      final SideboardDeck deck = updatedDecks[index];
      if (deck.id != newDeck.id) {
        collectInheritedName(deck.name);
      }
      for (final SideboardMatchup matchup in deck.matchups) {
        collectInheritedName(matchup.name);
      }
    }

    final SideboardDeck currentNewDeck = updatedDecks[newDeckIndex];
    final List<SideboardMatchup> newDeckMatchups = _deduplicateMatchupsByName(
      List<SideboardMatchup>.from(currentNewDeck.matchups),
    );
    final Set<String> newDeckExistingKeys = newDeckMatchups
        .map((SideboardMatchup matchup) => _normalizedMatchupName(matchup.name))
        .toSet();

    for (final MapEntry<String, String> entry in inheritedNames.entries) {
      if (entry.key == newDeckNameKey) {
        continue;
      }
      if (newDeckExistingKeys.contains(entry.key)) {
        continue;
      }
      matchupSeed += 1;
      newDeckMatchups.add(
        SideboardMatchup(
          id: '${now.microsecondsSinceEpoch + matchupSeed}',
          name: entry.value,
          createdAt: now,
          sideIn: const <SideboardCardEntry>[],
          sideOut: const <SideboardCardEntry>[],
        ),
      );
      newDeckExistingKeys.add(entry.key);
    }

    updatedDecks[newDeckIndex] = currentNewDeck.copyWith(
      matchups: _deduplicateMatchupsByName(newDeckMatchups),
    );

    for (final int index in sameFormatIndexes) {
      final SideboardDeck deck = updatedDecks[index];
      final List<SideboardMatchup> deduplicatedCurrent =
          _deduplicateMatchupsByName(
            List<SideboardMatchup>.from(deck.matchups),
          );
      final bool alreadyContainsNewDeck = deduplicatedCurrent.any((
        SideboardMatchup matchup,
      ) {
        return _normalizedMatchupName(matchup.name) == newDeckNameKey;
      });
      if (alreadyContainsNewDeck) {
        updatedDecks[index] = deck.copyWith(matchups: deduplicatedCurrent);
        continue;
      }

      matchupSeed += 1;
      updatedDecks[index] = deck.copyWith(
        matchups: _deduplicateMatchupsByName(<SideboardMatchup>[
          SideboardMatchup(
            id: '${now.microsecondsSinceEpoch + matchupSeed}',
            name: newDeckName,
            createdAt: now,
            sideIn: const <SideboardCardEntry>[],
            sideOut: const <SideboardCardEntry>[],
          ),
          ...deduplicatedCurrent,
        ]),
      );
    }

    return updatedDecks;
  }

  Future<void> _addDeck() async {
    final ({String name, String format})? deckData = await _promptNewDeckData();
    if (deckData == null) {
      return;
    }

    final DateTime now = DateTime.now();
    final SideboardDeck newDeck = SideboardDeck(
      id: now.microsecondsSinceEpoch.toString(),
      name: deckData.name,
      createdAt: now,
      isFavorite: false,
      userNotes: '',
      matchups: const <SideboardMatchup>[],
      format: deckData.format,
      tag: '',
      tcgKey: widget.tcg.storageKey,
    );

    bool shouldAutoInsert = false;
    if (deckData.format.trim().isNotEmpty) {
      shouldAutoInsert = await _confirmAutoMatchupForFormat(deckData.format);
    }

    setState(() {
      _decks = List<SideboardDeck>.from(_decks);
      _decks.insert(0, newDeck);
      if (shouldAutoInsert) {
        _decks = List<SideboardDeck>.from(
          _synchronizeFormatMatchupsForNewDeck(decks: _decks, newDeck: newDeck),
        );
      }
    });
  }

  Future<void> _editDeck(SideboardDeck deck) async {
    final ({String name, String format})? updated = await _promptNewDeckData(
      initialDeck: deck,
    );
    if (updated == null) {
      return;
    }
    final int index = _decks.indexWhere(
      (SideboardDeck item) => item.id == deck.id,
    );
    if (index < 0) {
      return;
    }
    final SideboardDeck updatedDeck = _decks[index].copyWith(
      name: updated.name,
      format: updated.format,
    );
    setState(() {
      List<SideboardDeck> nextDecks = List<SideboardDeck>.from(_decks);
      nextDecks[index] = updatedDeck;
      if (normalizeDeckName(deck.name) !=
          normalizeDeckName(updatedDeck.name)) {
        nextDecks = _renameDeckReferencesInMatchups(
          decks: nextDecks,
          oldName: deck.name,
          newName: updatedDeck.name,
        );
        _records = _renameDeckReferencesInRecords(
          records: _records,
          previousDeck: deck,
          updatedDeck: updatedDeck,
        );
      }
      _decks = nextDecks;
    });
  }

  void _toggleFavorite(SideboardDeck deck) {
    final int index = _decks.indexWhere(
      (SideboardDeck item) => item.id == deck.id,
    );
    if (index < 0) {
      return;
    }
    setState(() {
      _decks[index] = _decks[index].copyWith(isFavorite: !deck.isFavorite);
    });
  }

  Future<void> _openDeck(SideboardDeck deck) async {
    final SideboardDeckEditResult? result = await Navigator.of(context)
        .push<SideboardDeckEditResult>(
          MaterialPageRoute<SideboardDeckEditResult>(
            builder: (_) => SideboardMatchupListScreen(
              deck: deck,
              records: _records,
              settings: widget.settings,
            ),
          ),
        );
    if (result == null) {
      return;
    }

    final int index = _decks.indexWhere(
      (SideboardDeck item) => item.id == result.deck.id,
    );
    if (index < 0) {
      return;
    }

    setState(() {
      _decks[index] = result.deck;
      _records = result.records;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings txt = context.txt;
    final List<String> availableFormats = _existingDeckFormats();
    final List<String> availableTags = _existingDeckTags();
    final String effectiveFormatFilter =
        _selectedDeckFormatFilter.isNotEmpty &&
            availableFormats.contains(_selectedDeckFormatFilter)
        ? _selectedDeckFormatFilter
        : '';
    final String effectiveTagFilter =
        _selectedDeckTagFilter.isNotEmpty &&
            availableTags.contains(_selectedDeckTagFilter)
        ? _selectedDeckTagFilter
        : '';
    final List<SideboardDeck> sortedDecks = _sortedAndFilteredDecks(
      selectedFormatFilter: effectiveFormatFilter,
      selectedTagFilter: effectiveTagFilter,
    );
    final int visibleDeckCount = min(sortedDecks.length, _visibleDeckCount);
    final bool hasMoreDecks = visibleDeckCount < sortedDecks.length;

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
          title: Text(txt.t('home.decksUtility')),
          leading: IconButton(
            onPressed: _closeWithResult,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          actions: [
            IconButton(
              tooltip: txt.t('deckList.addDeck'),
              onPressed: _addDeck,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        body: _decks.isEmpty
            ? Center(
                child: Text(
                  txt.t('deckList.empty'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.74)),
                ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                    child: Card(
                      color: const Color(0xFF1E1B1B),
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              txt.t('deckList.sortBy'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<SideboardDeckSortMode>(
                              initialValue: _sortMode,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: <DropdownMenuItem<SideboardDeckSortMode>>[
                                DropdownMenuItem<SideboardDeckSortMode>(
                                  value: SideboardDeckSortMode.createdAt,
                                  child: Text(
                                    txt.t('deckList.sortCreationDate'),
                                  ),
                                ),
                                DropdownMenuItem<SideboardDeckSortMode>(
                                  value: SideboardDeckSortMode.alphabetical,
                                  child: Text(
                                    txt.t('deckList.sortAlphabetical'),
                                  ),
                                ),
                                DropdownMenuItem<SideboardDeckSortMode>(
                                  value: SideboardDeckSortMode.format,
                                  child: Text(txt.t('deckList.sortFormat')),
                                ),
                              ],
                              onChanged: (SideboardDeckSortMode? mode) {
                                if (mode == null) {
                                  return;
                                }
                                setState(() {
                                  _sortMode = mode;
                                  _visibleDeckCount = _deckPageSize;
                                });
                              },
                            ),
                            const SizedBox(height: 14),
                            InkWell(
                              onTap: () => setState(
                                () => _filtersExpanded = !_filtersExpanded,
                              ),
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      txt.t('deckList.filters'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(
                                      _filtersExpanded
                                          ? Icons.expand_less_rounded
                                          : Icons.expand_more_rounded,
                                      size: 18,
                                      color: Colors.white.withValues(alpha: 0.7),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_filtersExpanded) ...[
                            const SizedBox(height: 8),
                            if (availableFormats.isNotEmpty)
                              SearchableComboField(
                                value: effectiveFormatFilter,
                                decoration: InputDecoration(
                                  labelText: txt.t('field.format'),
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
                                fixedItems: <ComboItem>[
                                  ComboItem(
                                    value: '',
                                    label: txt.t('deckList.allFormats'),
                                  ),
                                ],
                                items: availableFormats
                                    .map(
                                      (String f) =>
                                          ComboItem(value: f, label: f),
                                    )
                                    .toList(growable: false),
                                onChanged: (String value) {
                                  setState(() {
                                    _selectedDeckFormatFilter = value.trim();
                                    _visibleDeckCount = _deckPageSize;
                                  });
                                },
                              ),
                            if (availableFormats.isNotEmpty &&
                                availableTags.isNotEmpty)
                              const SizedBox(height: 12),
                            if (availableTags.isNotEmpty)
                              SearchableComboField(
                                value: effectiveTagFilter,
                                decoration: InputDecoration(
                                  labelText: txt.t('field.tag'),
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
                                fixedItems: <ComboItem>[
                                  ComboItem(
                                    value: '',
                                    label: txt.t('deckList.allTags'),
                                  ),
                                ],
                                items: availableTags
                                    .map(
                                      (String t) =>
                                          ComboItem(value: t, label: t),
                                    )
                                    .toList(growable: false),
                                onChanged: (String value) {
                                  setState(() {
                                    _selectedDeckTagFilter = value.trim();
                                    _visibleDeckCount = _deckPageSize;
                                  });
                                },
                              ),
                            if (availableFormats.isNotEmpty ||
                                availableTags.isNotEmpty)
                              const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: FilterChip(
                                      label: Text(
                                        txt.t('deckList.favoritesOnly'),
                                      ),
                                      selected: _showFavoritesOnly,
                                      onSelected: (bool selected) {
                                        setState(() {
                                          _showFavoritesOnly = selected;
                                          _visibleDeckCount = _deckPageSize;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                FilledButton.tonalIcon(
                                  onPressed: _hasActiveDeckFilters
                                      ? _clearDeckFilters
                                      : null,
                                  icon: const Icon(
                                    Icons.filter_alt_off_rounded,
                                  ),
                                  label: Text(txt.t('deckList.clearFilters')),
                                ),
                              ],
                            ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: sortedDecks.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    txt.t('deckList.noDecksWithFilters'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.74,
                                      ),
                                    ),
                                  ),
                                  if (_hasActiveDeckFilters) ...[
                                    const SizedBox(height: 12),
                                    FilledButton.tonalIcon(
                                      onPressed: _clearDeckFilters,
                                      icon: const Icon(
                                        Icons.filter_alt_off_rounded,
                                      ),
                                      label: Text(
                                        txt.t('deckList.clearFilters'),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            itemCount: visibleDeckCount + (hasMoreDecks ? 1 : 0),
                            itemBuilder: (BuildContext context, int index) {
                              if (index >= visibleDeckCount) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: FilledButton.tonal(
                                      onPressed: () => setState(() {
                                        _visibleDeckCount = min(
                                          sortedDecks.length,
                                          _visibleDeckCount + _deckPageSize,
                                        );
                                      }),
                                      child: Text(txt.t('common.loadMore')),
                                    ),
                                  ),
                                );
                              }
                              final SideboardDeck deck = sortedDecks[index];
                              final int matchupCount = deck.matchups.length;
                              final String matchupLabel = matchupCount == 1
                                  ? txt.t('deckList.matchupSingular')
                                  : txt.t('deckList.matchupPlural', params: {'count': matchupCount});
                              final String trimmedFormat = deck.format.trim();
                              final String subtitleText = trimmedFormat.isEmpty
                                  ? matchupLabel
                                  : txt.t('deckList.deckSubtitleWithFormat', params: {'format': trimmedFormat, 'matchups': matchupLabel});
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                color: const Color(0xFF1E1B1B),
                                child: ListTile(
                                  onTap: () => _openDeck(deck),
                                  title: Text(
                                    deck.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 17,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      subtitleText,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.75,
                                        ),
                                      ),
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        onPressed: () => _editDeck(deck),
                                        tooltip: 'Edit deck',
                                        icon: const Icon(Icons.edit_rounded),
                                      ),
                                      IconButton(
                                        onPressed: () => _toggleFavorite(deck),
                                        tooltip: 'Toggle favorite',
                                        icon: Icon(
                                          deck.isFavorite
                                              ? Icons.star_rounded
                                              : Icons.star_outline_rounded,
                                          color: deck.isFavorite
                                              ? Colors.white
                                              : Colors.white.withValues(
                                                  alpha: 0.65,
                                                ),
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right_rounded),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

