import 'package:flutter/material.dart';

import '../../models/sideboard.dart';
import '../../widgets/text_prompt_dialog.dart';

class SideboardPlanScreen extends StatefulWidget {
  const SideboardPlanScreen({super.key, required this.matchup});

  final SideboardMatchup matchup;

  @override
  State<SideboardPlanScreen> createState() => _SideboardPlanScreenState();
}

class _SideboardPlanScreenState extends State<SideboardPlanScreen> {
  late List<SideboardCardEntry> _sideIn;
  late List<SideboardCardEntry> _sideOut;

  @override
  void initState() {
    super.initState();
    _sideIn = List<SideboardCardEntry>.from(widget.matchup.sideIn);
    _sideOut = List<SideboardCardEntry>.from(widget.matchup.sideOut);
  }

  void _closeWithResult() {
    Navigator.of(context).pop(
      widget.matchup.copyWith(
        sideIn: List<SideboardCardEntry>.from(_sideIn),
        sideOut: List<SideboardCardEntry>.from(_sideOut),
      ),
    );
  }

  Future<String?> _promptText({
    required String title,
    required String hintText,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return TextPromptDialog(
          title: title,
          initialValue: '',
          hintText: hintText,
          maxLines: 1,
        );
      },
    );
  }

  Future<void> _addCard({required bool sideIn}) async {
    final String? rawName = await _promptText(
      title: sideIn ? 'Add Side In card' : 'Add Side Out card',
      hintText: 'Card name',
    );
    if (rawName == null) {
      return;
    }

    final String name = rawName.trim();
    if (name.isEmpty) {
      return;
    }

    setState(() {
      if (sideIn) {
        _sideIn.add(SideboardCardEntry(name: name, copies: 1));
      } else {
        _sideOut.add(SideboardCardEntry(name: name, copies: 1));
      }
    });
  }

  void _removeCard({required bool sideIn, required int index}) {
    setState(() {
      if (sideIn) {
        _sideIn.removeAt(index);
      } else {
        _sideOut.removeAt(index);
      }
    });
  }

  void _updateCopies({
    required bool sideIn,
    required int index,
    required int copies,
  }) {
    setState(() {
      if (sideIn) {
        _sideIn[index] = _sideIn[index].copyWith(copies: copies);
      } else {
        _sideOut[index] = _sideOut[index].copyWith(copies: copies);
      }
    });
  }

  Widget _buildSection({
    required String title,
    required List<SideboardCardEntry> items,
    required bool sideIn,
  }) {
    return Expanded(
      child: Card(
        color: const Color(0xFF1E1B1B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _addCard(sideIn: sideIn),
                    tooltip: 'Add card',
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF2B2424),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Text(
                          'No cards added yet',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.62),
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (BuildContext context, int index) =>
                            Divider(
                              color: Colors.white.withValues(alpha: 0.12),
                              height: 1,
                            ),
                        itemBuilder: (BuildContext context, int index) {
                          final SideboardCardEntry item = items[index];
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            title: Text(item.name),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: item.copies,
                                    dropdownColor: const Color(0xFF2B2424),
                                    borderRadius: BorderRadius.circular(10),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    items: const <int>[1, 2, 3, 4]
                                        .map(
                                          (int value) => DropdownMenuItem<int>(
                                            value: value,
                                            child: Text('$value'),
                                          ),
                                        )
                                        .toList(growable: false),
                                    onChanged: (int? value) {
                                      if (value == null) {
                                        return;
                                      }
                                      _updateCopies(
                                        sideIn: sideIn,
                                        index: index,
                                        copies: value,
                                      );
                                    },
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Remove card',
                                  onPressed: () =>
                                      _removeCard(sideIn: sideIn, index: index),
                                  icon: const Icon(
                                    Icons.remove_circle_outline_rounded,
                                    size: 20,
                                  ),
                                  color: const Color(0xFFFF8A8A),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          title: Text(widget.matchup.name),
          leading: IconButton(
            onPressed: _closeWithResult,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            children: [
              _buildSection(title: 'Side In', items: _sideIn, sideIn: true),
              const SizedBox(height: 10),
              _buildSection(title: 'Side Out', items: _sideOut, sideIn: false),
            ],
          ),
        ),
      ),
    );
  }
}

