import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../l10n/app_strings.dart';
import '../../models/app_settings.dart';

class CustomizeScreen extends StatefulWidget {
  const CustomizeScreen({super.key, required this.initialSettings});

  final AppSettings initialSettings;

  @override
  State<CustomizeScreen> createState() => _CustomizeScreenState();
}

class _CustomizeScreenState extends State<CustomizeScreen> {
  late final TextEditingController _playerOneController;
  late final ScrollController _customizeScrollController;

  late Color _backgroundStartColor;
  late Color _backgroundEndColor;
  late Color _buttonColor;
  late Color _lifePointsBackgroundColor;
  late Color _playerOneColor;
  late Color _playerTwoColor;
  late SupportedTcg _startupTcg;
  late AppLanguage _appLanguage;

  @override
  void initState() {
    super.initState();
    _playerOneController = TextEditingController(
      text: widget.initialSettings.playerOneName,
    );
    _backgroundStartColor = widget.initialSettings.backgroundStartColor;
    _backgroundEndColor = widget.initialSettings.backgroundEndColor;
    _buttonColor = widget.initialSettings.buttonColor;
    _lifePointsBackgroundColor =
        widget.initialSettings.lifePointsBackgroundColor;
    _playerOneColor = widget.initialSettings.playerOneColor;
    _playerTwoColor = widget.initialSettings.playerTwoColor;
    _startupTcg = SupportedTcgX.fromStorageKey(
      widget.initialSettings.startupTcgKey,
    );
    _appLanguage = AppLanguageX.fromStorageKey(
      widget.initialSettings.appLanguageKey,
    );
    _customizeScrollController = ScrollController();
  }

  @override
  void dispose() {
    _playerOneController.dispose();
    _customizeScrollController.dispose();
    super.dispose();
  }

  AppSettings _buildSettings() {
    final AppStrings txt = context.txt;
    final String playerOneName = _playerOneController.text.trim().isEmpty
        ? txt.t('customize.player1Name')
        : _playerOneController.text.trim();

    return widget.initialSettings.copyWith(
      playerOneName: playerOneName,
      playerTwoName: txt.t('labels.player2'),
      startupTcgKey: _startupTcg.storageKey,
      appLanguageKey: _appLanguage.storageKey,
      backgroundStartColor: _backgroundStartColor,
      backgroundEndColor: _backgroundEndColor,
      buttonColor: _buttonColor,
      lifePointsBackgroundColor: _lifePointsBackgroundColor,
      playerOneColor: _playerOneColor,
      playerTwoColor: _playerTwoColor,
    );
  }

  void _saveSettings() {
    Navigator.of(context).pop(_buildSettings());
  }

  Widget _buildColorPicker({
    required String label,
    required Color selectedColor,
    required ValueChanged<Color> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final Color color in appColorPalette)
              GestureDetector(
                onTap: () => onChanged(color),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selectedColor == color
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.2),
                      width: selectedColor == color ? 2.4 : 1,
                    ),
                  ),
                  child: selectedColor == color
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings txt = context.txt;
    final Color previewMiddle =
        Color.lerp(_backgroundStartColor, _backgroundEndColor, 0.45) ??
        _backgroundStartColor;
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final EdgeInsets contentPadding = EdgeInsets.fromLTRB(
      16,
      16,
      16,
      24 + mediaQuery.viewPadding.bottom + mediaQuery.viewInsets.bottom,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(txt.t('customize.title')),
        actions: [
          FilledButton(
            onPressed: _saveSettings,
            child: Text(txt.t('common.save')),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Scrollbar(
        controller: _customizeScrollController,
        child: ListView(
          controller: _customizeScrollController,
          primary: false,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: contentPadding,
          children: [
            Text(
              txt.t('customize.players'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _playerOneController,
              decoration: InputDecoration(
                labelText: txt.t('customize.player1Name'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            _buildColorPicker(
              label: txt.t('customize.player1Color'),
              selectedColor: _playerOneColor,
              onChanged: (Color color) {
                setState(() {
                  _playerOneColor = color;
                });
              },
            ),
            const SizedBox(height: 14),
            _buildColorPicker(
              label: txt.t('customize.player2Color'),
              selectedColor: _playerTwoColor,
              onChanged: (Color color) {
                setState(() {
                  _playerTwoColor = color;
                });
              },
            ),
            const SizedBox(height: 20),
            Text(
              txt.t('customize.startup'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<SupportedTcg>(
              initialValue: _startupTcg,
              decoration: InputDecoration(
                labelText: txt.t('customize.openWith'),
                border: const OutlineInputBorder(),
              ),
              items: supportedTcgAlphabeticalOrder
                  .map(
                    (SupportedTcg game) => DropdownMenuItem<SupportedTcg>(
                      value: game,
                      child: Text(txt.t('tcg.${game.storageKey}')),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (SupportedTcg? value) {
                if (value == null || value == _startupTcg) {
                  return;
                }
                setState(() {
                  _startupTcg = value;
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<AppLanguage>(
              initialValue: _appLanguage,
              decoration: InputDecoration(
                labelText: txt.t('customize.language'),
                border: const OutlineInputBorder(),
              ),
              items: <DropdownMenuItem<AppLanguage>>[
                DropdownMenuItem<AppLanguage>(
                  value: AppLanguage.system,
                  child: Text(txt.t('customize.languageSystem')),
                ),
                DropdownMenuItem<AppLanguage>(
                  value: AppLanguage.english,
                  child: Text(txt.t('customize.languageEnglish')),
                ),
                DropdownMenuItem<AppLanguage>(
                  value: AppLanguage.italian,
                  child: Text(txt.t('customize.languageItalian')),
                ),
              ],
              onChanged: (AppLanguage? value) {
                if (value == null || value == _appLanguage) {
                  return;
                }
                setState(() {
                  _appLanguage = value;
                });
              },
            ),
            const SizedBox(height: 20),
            Text(
              txt.t('customize.colors'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            _buildColorPicker(
              label: txt.t('customize.bgStart'),
              selectedColor: _backgroundStartColor,
              onChanged: (Color color) {
                setState(() {
                  _backgroundStartColor = color;
                });
              },
            ),
            const SizedBox(height: 12),
            _buildColorPicker(
              label: txt.t('customize.bgEnd'),
              selectedColor: _backgroundEndColor,
              onChanged: (Color color) {
                setState(() {
                  _backgroundEndColor = color;
                });
              },
            ),
            const SizedBox(height: 12),
            _buildColorPicker(
              label: txt.t('customize.buttonColor'),
              selectedColor: _buttonColor,
              onChanged: (Color color) {
                setState(() {
                  _buttonColor = color;
                });
              },
            ),
            const SizedBox(height: 12),
            _buildColorPicker(
              label: txt.t('customize.lpBg'),
              selectedColor: _lifePointsBackgroundColor,
              onChanged: (Color color) {
                setState(() {
                  _lifePointsBackgroundColor = color;
                });
              },
            ),
            const SizedBox(height: 20),
            Text(
              txt.t('customize.preview'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    _backgroundStartColor,
                    previewMiddle,
                    _backgroundEndColor,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_playerOneController.text.trim().isEmpty ? txt.t('customize.player1Name') : _playerOneController.text.trim()} vs ${txt.t('labels.player2')}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: () {},
                        style: FilledButton.styleFrom(
                          backgroundColor: _buttonColor,
                        ),
                        child: Text(txt.t('customize.button')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _lifePointsBackgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: const Text(
                      '8000',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
