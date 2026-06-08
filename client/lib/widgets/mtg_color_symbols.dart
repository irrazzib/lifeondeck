import 'package:flutter/material.dart';

import '../models/sideboard.dart';

class MtgColorTheme {
  const MtgColorTheme({
    required this.background,
    required this.foreground,
    required this.label,
  });

  final Color background;
  final Color foreground;
  final String label;
}

const Map<String, MtgColorTheme> _mtgColorThemes = <String, MtgColorTheme>{
  'W': MtgColorTheme(
    background: Color(0xFFF8F1D2),
    foreground: Color(0xFF4A3F1A),
    label: 'W',
  ),
  'U': MtgColorTheme(
    background: Color(0xFF1F6FB5),
    foreground: Color(0xFFEAF4FB),
    label: 'U',
  ),
  'B': MtgColorTheme(
    background: Color(0xFF2A1F1F),
    foreground: Color(0xFFE0D8D2),
    label: 'B',
  ),
  'R': MtgColorTheme(
    background: Color(0xFFD23636),
    foreground: Color(0xFFFFEDED),
    label: 'R',
  ),
  'G': MtgColorTheme(
    background: Color(0xFF1F7A4A),
    foreground: Color(0xFFE6F5EC),
    label: 'G',
  ),
  'C': MtgColorTheme(
    background: Color(0xFF8C8479),
    foreground: Color(0xFFF2EFE9),
    label: 'C',
  ),
};

MtgColorTheme? mtgColorTheme(String code) => _mtgColorThemes[code];

/// Compact, non-interactive row of mana color circles. Used in deck list
/// subtitles to indicate the deck colors without taking much space.
class MtgColorBadgeStrip extends StatelessWidget {
  const MtgColorBadgeStrip({
    super.key,
    required this.colors,
    this.size = 14,
    this.spacing = 2,
  });

  final List<String> colors;
  final double size;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (colors.isEmpty) return const SizedBox.shrink();
    final List<Widget> badges = <Widget>[];
    for (final String code in colors) {
      final MtgColorTheme? theme = mtgColorTheme(code);
      if (theme == null) continue;
      if (badges.isNotEmpty) {
        badges.add(SizedBox(width: spacing));
      }
      badges.add(_ColorDot(theme: theme, size: size));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: badges);
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.theme, required this.size});

  final MtgColorTheme theme;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.background,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.35),
          width: 0.6,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        theme.label,
        style: TextStyle(
          color: theme.foreground,
          fontSize: size * 0.62,
          fontWeight: FontWeight.w800,
          height: 1.0,
        ),
      ),
    );
  }
}

/// Interactive grid of mana color toggles. Zero-or-more selectable. Calls
/// [onChanged] with the new ordered list (canonical WUBRG+C order) on each
/// toggle.
class MtgColorSelector extends StatelessWidget {
  const MtgColorSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.symbolSize = 36,
  });

  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final double symbolSize;

  void _toggle(String code) {
    final Set<String> current = selected.toSet();
    if (!current.add(code)) {
      current.remove(code);
    }
    final List<String> ordered = <String>[
      for (final String c in mtgColorCodes)
        if (current.contains(c)) c,
    ];
    onChanged(ordered);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final String code in mtgColorCodes)
          _ColorToggle(
            code: code,
            size: symbolSize,
            selected: selected.contains(code),
            onTap: () => _toggle(code),
          ),
      ],
    );
  }
}

class _ColorToggle extends StatelessWidget {
  const _ColorToggle({
    required this.code,
    required this.size,
    required this.selected,
    required this.onTap,
  });

  final String code;
  final double size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MtgColorTheme? theme = mtgColorTheme(code);
    if (theme == null) return const SizedBox.shrink();
    final double opacity = selected ? 1.0 : 0.35;
    return Semantics(
      button: true,
      selected: selected,
      label: 'MTG color $code',
      child: InkResponse(
        onTap: onTap,
        radius: size * 0.7,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: theme.background.withValues(alpha: opacity),
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Colors.white.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.2),
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: theme.background.withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          alignment: Alignment.center,
          child: Text(
            theme.label,
            style: TextStyle(
              color: theme.foreground.withValues(alpha: opacity),
              fontSize: size * 0.5,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}
