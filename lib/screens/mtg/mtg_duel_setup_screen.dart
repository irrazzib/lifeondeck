import 'package:flutter/material.dart';

import '../../models/app_settings.dart';
import 'dart:math';

@immutable
class MtgDuelSetupResult {
  const MtgDuelSetupResult({
    required this.playerCount,
    required this.initialLifePoints,
    required this.layoutMode,
  });

  final int playerCount;
  final int initialLifePoints;
  final MtgDuelLayoutMode layoutMode;
}

enum MtgDuelLayoutMode { standard, tableMode }

extension MtgDuelLayoutModeX on MtgDuelLayoutMode {
  String get label {
    switch (this) {
      case MtgDuelLayoutMode.standard:
        return 'Standard';
      case MtgDuelLayoutMode.tableMode:
        return 'Table Mode';
    }
  }

  String get subtitle {
    switch (this) {
      case MtgDuelLayoutMode.standard:
        return 'Opposite sides';
      case MtgDuelLayoutMode.tableMode:
        return 'Around the table';
    }
  }
}

typedef MtgLayoutRowSpec = ({List<int?> slots, int flex});

MtgDuelLayoutMode effectiveMtgLayoutMode({
  required int playerCount,
  required MtgDuelLayoutMode layoutMode,
}) {
  return playerCount == 2 ? MtgDuelLayoutMode.tableMode : layoutMode;
}

int mtgQuarterTurnsForPlayer({
  required int playerCount,
  required MtgDuelLayoutMode layoutMode,
  required int playerIndex,
}) {
  final MtgDuelLayoutMode effectiveMode = effectiveMtgLayoutMode(
    playerCount: playerCount,
    layoutMode: layoutMode,
  );

  if (effectiveMode == MtgDuelLayoutMode.standard) {
    if (playerCount == 3) {
      if (playerIndex == 1) {
        return 1;
      }
      return 3;
    }
    switch (playerCount) {
      case 4:
        return playerIndex <= 1 ? 1 : 3;
      case 5:
      case 6:
        return playerIndex <= 2 ? 1 : 3;
      case 2:
      default:
        return playerIndex == 0 ? 0 : 2;
    }
  }

  switch (playerCount) {
    case 2:
      return playerIndex == 0 ? 0 : 2;
    case 3:
      if (playerIndex == 0) {
        return 0;
      }
      return playerIndex == 1 ? 1 : 3;
    case 4:
      if (playerIndex == 0) {
        return 0;
      }
      if (playerIndex == 1) {
        return 1;
      }
      if (playerIndex == 2) {
        return 2;
      }
      return 3;
    case 5:
      if (playerIndex == 0) {
        return 0;
      }
      if (playerIndex == 1 || playerIndex == 2) {
        return 1;
      }
      if (playerIndex == 3) {
        return 2;
      }
      return 3;
    case 6:
      if (playerIndex == 0) {
        return 0;
      }
      if (playerIndex == 1 || playerIndex == 2) {
        return 1;
      }
      if (playerIndex == 3) {
        return 2;
      }
      if (playerIndex == 4 || playerIndex == 5) {
        return 3;
      }
      return 2;
    default:
      return 0;
  }
}

List<MtgLayoutRowSpec> mtgLayoutRows({
  required int playerCount,
  required MtgDuelLayoutMode layoutMode,
}) {
  final MtgDuelLayoutMode effectiveMode = effectiveMtgLayoutMode(
    playerCount: playerCount,
    layoutMode: layoutMode,
  );

  if (effectiveMode == MtgDuelLayoutMode.standard) {
    switch (playerCount) {
      case 3:
        return <MtgLayoutRowSpec>[
          (slots: <int?>[1, 2], flex: 48),
          (slots: <int?>[null, 0, null], flex: 52),
        ];
      case 4:
        return <MtgLayoutRowSpec>[
          (slots: <int?>[1, 3], flex: 50),
          (slots: <int?>[0, 2], flex: 50),
        ];
      case 5:
        return <MtgLayoutRowSpec>[
          (slots: <int?>[2, null, 4], flex: 33),
          (slots: <int?>[1, null, 3], flex: 33),
          (slots: <int?>[0, null, null], flex: 34),
        ];
      case 6:
        return <MtgLayoutRowSpec>[
          (slots: <int?>[2, null, 5], flex: 33),
          (slots: <int?>[1, null, 4], flex: 33),
          (slots: <int?>[0, null, 3], flex: 34),
        ];
      case 2:
      default:
        return <MtgLayoutRowSpec>[
          (slots: <int?>[1], flex: 50),
          (slots: <int?>[0], flex: 50),
        ];
    }
  }

  switch (playerCount) {
    case 3:
      return <MtgLayoutRowSpec>[
        (slots: <int?>[1, 2], flex: 60),
        (slots: <int?>[0], flex: 40),
      ];
    case 4:
      return <MtgLayoutRowSpec>[
        (slots: <int?>[2], flex: 26),
        (slots: <int?>[1, null, 3], flex: 48),
        (slots: <int?>[0], flex: 26),
      ];
    case 5:
      return <MtgLayoutRowSpec>[
        (slots: <int?>[null, 3, null], flex: 18),
        (slots: <int?>[1, null, 4], flex: 22),
        (slots: <int?>[2, null, null], flex: 21),
        (slots: <int?>[null, 0, null], flex: 21),
      ];
    case 6:
      return <MtgLayoutRowSpec>[
        (slots: <int?>[null, 3, null], flex: 22),
        (slots: <int?>[1, null, 4], flex: 28),
        (slots: <int?>[2, null, 5], flex: 28),
        (slots: <int?>[null, 0, null], flex: 22),
      ];
    case 2:
    default:
      return <MtgLayoutRowSpec>[
        (slots: <int?>[1], flex: 50),
        (slots: <int?>[0], flex: 50),
      ];
  }
}

List<int> slotFlexesForSlots(List<int?> slots) {
  if (slots.length <= 1) {
    return const <int>[1];
  }
  if (slots.length == 2) {
    return const <int>[1, 1];
  }

  final bool left = slots[0] != null;
  final bool center = slots[1] != null;
  final bool right = slots[2] != null;

  if (left && !center && right) {
    return const <int>[7, 1, 7];
  }
  if (!left && center && !right) {
    return const <int>[1, 8, 1];
  }
  if (left && !center && !right) {
    return const <int>[7, 1, 7];
  }
  if (!left && !center && right) {
    return const <int>[7, 1, 7];
  }
  if (!left && center && right) {
    return const <int>[1, 6, 6];
  }
  if (left && center && !right) {
    return const <int>[6, 6, 1];
  }
  return const <int>[1, 1, 1];
}

class MtgDuelSetupScreen extends StatefulWidget {
  const MtgDuelSetupScreen({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<MtgDuelSetupScreen> createState() => _MtgDuelSetupScreenState();
}

class _MtgDuelSetupScreenState extends State<MtgDuelSetupScreen> {
  int _playerCount = 2;
  int _initialLifePoints = 20;
  MtgDuelLayoutMode _layoutMode = MtgDuelLayoutMode.tableMode;

  MtgDuelLayoutMode get _effectiveLayoutMode =>
      _playerCount == 2 ? MtgDuelLayoutMode.tableMode : _layoutMode;

  void _startDuel() {
    Navigator.of(context).pop(
      MtgDuelSetupResult(
        playerCount: _playerCount,
        initialLifePoints: _initialLifePoints,
        layoutMode: _effectiveLayoutMode,
      ),
    );
  }

  Widget _buildChoiceCard({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
    required Color accentColor,
    double? width = 128,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? accentColor.withValues(alpha: 0.24)
                : const Color(0xFF1C1A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? accentColor
                  : Colors.white.withValues(alpha: 0.14),
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullWidthChoiceRows<T>({
    required List<T> values,
    required Widget Function(T value) itemBuilder,
    int maxColumns = 3,
    double spacing = 10,
  }) {
    final List<Widget> rows = <Widget>[];
    for (int start = 0; start < values.length; start += maxColumns) {
      final int end = min(start + maxColumns, values.length);
      final List<T> chunk = values.sublist(start, end);
      rows.add(
        Row(
          children: [
            for (int index = 0; index < chunk.length; index += 1) ...[
              Expanded(child: itemBuilder(chunk[index])),
              if (index < chunk.length - 1) SizedBox(width: spacing),
            ],
          ],
        ),
      );
      if (end < values.length) {
        rows.add(SizedBox(height: spacing));
      }
    }
    return Column(children: rows);
  }

  Widget _buildLayoutPreviewFrame({
    required double height,
    required Widget child,
  }) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: child,
    );
  }

  Widget _buildLayoutPreviewTile({
    required String label,
    required int quarterTurns,
  }) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double shortestSide = min(
          constraints.maxWidth,
          constraints.maxHeight,
        );
        final double iconSize = shortestSide.clamp(10.0, 16.0);
        final double fontSize = shortestSide < 26
            ? 7.4
            : (shortestSide < 38 ? 8.2 : 9.2);

        return Container(
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFF171717),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: RotatedBox(
              quarterTurns: quarterTurns,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 3,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.expand_less_rounded,
                          size: iconSize,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  int _previewQuarterTurnsForPlayer(int playerIndex) {
    return mtgQuarterTurnsForPlayer(
      playerCount: _playerCount,
      layoutMode: _effectiveLayoutMode,
      playerIndex: playerIndex,
    );
  }

  List<MtgLayoutRowSpec> _previewRows() {
    return mtgLayoutRows(
      playerCount: _playerCount,
      layoutMode: _effectiveLayoutMode,
    );
  }

  Widget _buildPreviewRow(List<int?> slots) {
    final List<int> slotFlexes = slotFlexesForSlots(slots);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int index = 0; index < slots.length; index += 1) ...[
          if (index > 0) const SizedBox(width: 4),
          Flexible(
            flex: slotFlexes[index],
            child: Builder(
              builder: (BuildContext context) {
                final int? playerIndex = slots[index];
                if (playerIndex == null) {
                  return const SizedBox.shrink();
                }
                return _buildLayoutPreviewTile(
                  label: 'P${playerIndex + 1}',
                  quarterTurns: _previewQuarterTurnsForPlayer(playerIndex),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLayoutPreview() {
    if (_effectiveLayoutMode == MtgDuelLayoutMode.standard &&
        _playerCount == 3) {
      return _buildThreePlayerStandardPreview();
    }
    if (_effectiveLayoutMode == MtgDuelLayoutMode.standard &&
        _playerCount == 5) {
      return _buildFivePlayerStandardPreview();
    }
    if (_effectiveLayoutMode == MtgDuelLayoutMode.standard &&
        _playerCount == 6) {
      return _buildSixPlayerStandardPreview();
    }
    if (_effectiveLayoutMode == MtgDuelLayoutMode.tableMode &&
        _playerCount == 4) {
      return _buildFourPlayerTablePreview();
    }
    if (_effectiveLayoutMode == MtgDuelLayoutMode.tableMode &&
        _playerCount == 5) {
      return _buildFivePlayerTablePreview();
    }
    if (_effectiveLayoutMode == MtgDuelLayoutMode.tableMode &&
        _playerCount == 6) {
      return _buildSixPlayerTablePreview();
    }

    final List<MtgLayoutRowSpec> rows = _previewRows();
    final double previewHeight = switch (rows.length) {
      2 => 120,
      3 => 144,
      4 => 172,
      5 => 198,
      _ => 132,
    };

    return _buildLayoutPreviewFrame(
      height: previewHeight,
      child: Column(
        children: [
          for (final MtgLayoutRowSpec row in rows)
            Expanded(flex: row.flex, child: _buildPreviewRow(row.slots)),
        ],
      ),
    );
  }

  Widget _buildThreePlayerStandardPreview() {
    return _buildLayoutPreviewFrame(
      height: 156,
      child: Row(
        children: [
          Expanded(
            child: _buildLayoutPreviewTile(
              label: 'P2',
              quarterTurns: _previewQuarterTurnsForPlayer(1),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _buildLayoutPreviewTile(
                    label: 'P3',
                    quarterTurns: _previewQuarterTurnsForPlayer(2),
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: _buildLayoutPreviewTile(
                    label: 'P1',
                    quarterTurns: _previewQuarterTurnsForPlayer(0),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFourPlayerTablePreview() {
    return _buildLayoutPreviewFrame(
      height: 164,
      child: Column(
        children: [
          Expanded(flex: 26, child: _buildPreviewRow(const <int?>[2])),
          const SizedBox(height: 4),
          Expanded(
            flex: 48,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildLayoutPreviewTile(
                    label: 'P2',
                    quarterTurns: _previewQuarterTurnsForPlayer(1),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      widthFactor: 1,
                      heightFactor: 0.94,
                      alignment: Alignment.bottomCenter,
                      child: _buildLayoutPreviewTile(
                        label: 'P4',
                        quarterTurns: _previewQuarterTurnsForPlayer(3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(flex: 26, child: _buildPreviewRow(const <int?>[0])),
        ],
      ),
    );
  }

  Widget _buildFivePlayerStandardPreview() {
    return _buildLayoutPreviewFrame(
      height: 188,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _buildLayoutPreviewTile(
                    label: 'P3',
                    quarterTurns: _previewQuarterTurnsForPlayer(2),
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: _buildLayoutPreviewTile(
                    label: 'P2',
                    quarterTurns: _previewQuarterTurnsForPlayer(1),
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: _buildLayoutPreviewTile(
                    label: 'P1',
                    quarterTurns: _previewQuarterTurnsForPlayer(0),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _buildLayoutPreviewTile(
                    label: 'P5',
                    quarterTurns: _previewQuarterTurnsForPlayer(4),
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: _buildLayoutPreviewTile(
                    label: 'P4',
                    quarterTurns: _previewQuarterTurnsForPlayer(3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFivePlayerTablePreview() {
    return _buildLayoutPreviewFrame(
      height: 188,
      child: Column(
        children: [
          Expanded(
            flex: 22,
            child: _buildPreviewRow(const <int?>[null, 3, null]),
          ),
          const SizedBox(height: 4),
          Expanded(
            flex: 56,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: _buildLayoutPreviewTile(
                          label: 'P2',
                          quarterTurns: _previewQuarterTurnsForPlayer(1),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: _buildLayoutPreviewTile(
                          label: 'P3',
                          quarterTurns: _previewQuarterTurnsForPlayer(2),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildLayoutPreviewTile(
                    label: 'P5',
                    quarterTurns: _previewQuarterTurnsForPlayer(4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            flex: 22,
            child: _buildPreviewRow(const <int?>[null, 0, null]),
          ),
        ],
      ),
    );
  }

  Widget _buildSixPlayerStandardPreview() {
    return _buildLayoutPreviewFrame(
      height: 188,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _buildLayoutPreviewTile(
                    label: 'P3',
                    quarterTurns: _previewQuarterTurnsForPlayer(2),
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: _buildLayoutPreviewTile(
                    label: 'P2',
                    quarterTurns: _previewQuarterTurnsForPlayer(1),
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: _buildLayoutPreviewTile(
                    label: 'P1',
                    quarterTurns: _previewQuarterTurnsForPlayer(0),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _buildLayoutPreviewTile(
                    label: 'P6',
                    quarterTurns: _previewQuarterTurnsForPlayer(5),
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: _buildLayoutPreviewTile(
                    label: 'P5',
                    quarterTurns: _previewQuarterTurnsForPlayer(4),
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: _buildLayoutPreviewTile(
                    label: 'P4',
                    quarterTurns: _previewQuarterTurnsForPlayer(3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSixPlayerTablePreview() {
    return _buildLayoutPreviewFrame(
      height: 196,
      child: Column(
        children: [
          Expanded(flex: 24, child: _buildPreviewRow(const <int?>[3])),
          const SizedBox(height: 4),
          Expanded(
            flex: 52,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: _buildLayoutPreviewTile(
                          label: 'P2',
                          quarterTurns: _previewQuarterTurnsForPlayer(1),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: _buildLayoutPreviewTile(
                          label: 'P3',
                          quarterTurns: _previewQuarterTurnsForPlayer(2),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: _buildLayoutPreviewTile(
                          label: 'P5',
                          quarterTurns: _previewQuarterTurnsForPlayer(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: _buildLayoutPreviewTile(
                          label: 'P6',
                          quarterTurns: _previewQuarterTurnsForPlayer(5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(flex: 24, child: _buildPreviewRow(const <int?>[0])),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MTG Game Setup'),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Number of players',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildFullWidthChoiceRows<int>(
                    values: const <int>[2, 3, 4, 5, 6],
                    maxColumns: 3,
                    itemBuilder: (int count) {
                      return _buildChoiceCard(
                        title: '$count Players',
                        subtitle: count <= 2 ? 'Classic setup' : 'Multiplayer',
                        selected: _playerCount == count,
                        onTap: () {
                          setState(() {
                            _playerCount = count;
                            if (count == 2) {
                              _layoutMode = MtgDuelLayoutMode.tableMode;
                            }
                          });
                        },
                        accentColor: const Color(0xFF5FB06A),
                        width: null,
                      );
                    },
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Starting life points',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildFullWidthChoiceRows<int>(
                    values: const <int>[20, 25, 40],
                    maxColumns: 3,
                    itemBuilder: (int lifePoints) {
                      return _buildChoiceCard(
                        title: '$lifePoints LP',
                        subtitle: lifePoints == 40
                            ? 'Commander-style'
                            : 'Standard setup',
                        selected: _initialLifePoints == lifePoints,
                        onTap: () {
                          setState(() {
                            _initialLifePoints = lifePoints;
                          });
                        },
                        accentColor: const Color(0xFF4C81D9),
                        width: null,
                      );
                    },
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Counter layout',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_playerCount == 2)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1A1A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: const Text(
                        'For 2 players only Table Mode is available.',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    )
                  else
                    _buildFullWidthChoiceRows<MtgDuelLayoutMode>(
                      values: MtgDuelLayoutMode.values,
                      maxColumns: 2,
                      itemBuilder: (MtgDuelLayoutMode mode) {
                        return _buildChoiceCard(
                          title: mode.label,
                          subtitle: mode.subtitle,
                          selected: _layoutMode == mode,
                          onTap: () {
                            setState(() {
                              _layoutMode = mode;
                            });
                          },
                          accentColor: const Color(0xFFE49F43),
                          width: null,
                        );
                      },
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'Preview',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildLayoutPreview(),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: FilledButton(
                onPressed: _startDuel,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: widget.settings.buttonColor,
                ),
                child: Text(
                  'Start MTG Game',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

