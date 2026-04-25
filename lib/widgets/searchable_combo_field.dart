import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

class ComboItem {
  const ComboItem({required this.value, required this.label});

  final String value;
  final String label;
}

/// Combo field with search and optional "add new" action.
///
/// - [fixedItems]: always shown at top, not filtered by search query (e.g. "All", "No deck").
/// - [items]: searchable; shows first 5 without query, all matches when query is active.
/// - [onAdd]: if non-null, an "add new" row is always visible at the bottom of the sheet.
///   Called with the current search query. Returns the created value or null to cancel.
/// - [addLabel]: overrides the default "Add new..." label.
class SearchableComboField extends StatelessWidget {
  const SearchableComboField({
    super.key,
    required this.value,
    required this.decoration,
    required this.items,
    required this.onChanged,
    this.fixedItems = const <ComboItem>[],
    this.onAdd,
    this.addLabel,
  });

  final String? value;
  final InputDecoration decoration;
  final List<ComboItem> fixedItems;
  final List<ComboItem> items;
  final ValueChanged<String> onChanged;
  final Future<String?> Function(String query)? onAdd;
  final String? addLabel;

  String _resolveLabel(BuildContext context) {
    if (value == null || value!.isEmpty) {
      if (fixedItems.isNotEmpty) {
        return fixedItems.first.label;
      }
      return '';
    }
    for (final ComboItem item in fixedItems) {
      if (item.value == value) return item.label;
    }
    for (final ComboItem item in items) {
      if (item.value == value) return item.label;
    }
    return value!;
  }

  @override
  Widget build(BuildContext context) {
    final String displayLabel = _resolveLabel(context);
    return GestureDetector(
      onTap: () => _openSheet(context),
      child: InputDecorator(
        decoration: decoration.copyWith(
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          displayLabel,
          style: Theme.of(context).textTheme.bodyMedium,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Future<void> _openSheet(BuildContext context) async {
    final String? picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext sheetContext) {
        return _ComboSheet(
          fixedItems: fixedItems,
          items: items,
          selectedValue: value,
          onAdd: onAdd,
          addLabel: addLabel,
        );
      },
    );
    if (picked != null) {
      onChanged(picked);
    }
  }
}

class _ComboSheet extends StatefulWidget {
  const _ComboSheet({
    required this.fixedItems,
    required this.items,
    required this.selectedValue,
    required this.onAdd,
    required this.addLabel,
  });

  final List<ComboItem> fixedItems;
  final List<ComboItem> items;
  final String? selectedValue;
  final Future<String?> Function(String query)? onAdd;
  final String? addLabel;

  @override
  State<_ComboSheet> createState() => _ComboSheetState();
}

class _ComboSheetState extends State<_ComboSheet> {
  static const int _maxUnfilteredItems = 5;

  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ComboItem> get _filteredItems {
    if (_query.isEmpty) {
      return widget.items.take(_maxUnfilteredItems).toList(growable: false);
    }
    return widget.items
        .where((ComboItem i) => i.label.toLowerCase().contains(_query))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings txt = context.txt;
    final List<ComboItem> dynamic = _filteredItems;
    final bool hasMore =
        _query.isEmpty && widget.items.length > _maxUnfilteredItems;
    final bool noResults =
        _query.isNotEmpty && dynamic.isEmpty && widget.fixedItems.isEmpty;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              autofocus: widget.items.length > _maxUnfilteredItems,
              decoration: InputDecoration(
                hintText: txt.t('combo.search'),
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: <Widget>[
                for (final ComboItem item in widget.fixedItems)
                  _ItemTile(
                    item: item,
                    selected: item.value == widget.selectedValue,
                  ),
                if (widget.fixedItems.isNotEmpty &&
                    (dynamic.isNotEmpty || widget.onAdd != null))
                  const Divider(height: 1),
                if (noResults)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 16,
                    ),
                    child: Text(
                      txt.t('combo.noResults'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                for (final ComboItem item in dynamic)
                  _ItemTile(
                    item: item,
                    selected: item.value == widget.selectedValue,
                  ),
                if (hasMore)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 16,
                    ),
                    child: Text(
                      '+ ${widget.items.length - _maxUnfilteredItems} more — search to find',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                if (widget.onAdd != null) ...<Widget>[
                  if (dynamic.isNotEmpty || widget.fixedItems.isNotEmpty)
                    const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: Text(
                      widget.addLabel ?? context.txt.t('combo.addNew'),
                    ),
                    onTap: () async {
                      final String? created = await widget.onAdd!(_query);
                      if (created != null && context.mounted) {
                        Navigator.of(context).pop(created);
                      }
                    },
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.selected});

  final ComboItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(item.label, overflow: TextOverflow.ellipsis),
      trailing: selected ? const Icon(Icons.check) : null,
      selected: selected,
      onTap: () => Navigator.of(context).pop(item.value),
    );
  }
}
