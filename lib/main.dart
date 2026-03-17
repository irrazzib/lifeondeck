import 'dart:convert';
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

const Set<String> _supportedTcgStorageKeys = <String>{
  'yugioh',
  'mtg',
  'riftbound',
  'lorcana',
};
const String _appBuildTag = 'build 8286103';
const String _onboardingCompletedKey = 'onboarding_completed_v1';
const String _defaultGameSelectedKey = 'default_game_selected_v1';
const String _seenInfoTipsKey = 'seen_info_tips_v1';
const int _defaultDieSides = 6;
const Duration _diceResultVisibilityDuration = Duration(seconds: 3);
const List<Color> _appColorPalette = <Color>[
  Color(0xFF141414),
  Color(0xFF341212),
  Color(0xFF1E1B1B),
  Color(0xFF18321D),
  Color(0xFF15293B),
  Color(0xFF2E244A),
  Color(0xFF4A2A12),
  Color(0xFF5B2424),
  Color(0xFF1C5D35),
  Color(0xFF245D5A),
  Color(0xFF3B3B3B),
  Color(0xFF264653),
];

int _nextDieValue(Random random, {int sides = _defaultDieSides}) {
  return random.nextInt(sides) + 1;
}

enum AppLanguage { system, english, italian }

extension AppLanguageX on AppLanguage {
  static const Map<AppLanguage, String> _storageCodes = <AppLanguage, String>{
    AppLanguage.english: 'en',
    AppLanguage.italian: 'it',
  };

  String get storageKey => _storageCodes[this] ?? 'system';

  String get localeCode {
    if (this == AppLanguage.system) {
      final String systemCode = WidgetsBinding
          .instance.platformDispatcher.locale.languageCode
          .toLowerCase();
      return _storageCodes.values.firstWhere(
        (String code) => systemCode.startsWith(code),
        orElse: () => 'en',
      );
    }
    return _storageCodes[this] ?? 'en';
  }

  Locale? get materialLocale {
    final String? code = _storageCodes[this];
    return code == null ? null : Locale(code);
  }

  static AppLanguage fromStorageKey(String? raw) {
    final String normalized = (raw ?? '').trim().toLowerCase();
    return _storageCodes.entries
        .firstWhere(
          (MapEntry<AppLanguage, String> e) => e.value == normalized,
          orElse: () => const MapEntry<AppLanguage, String>(
            AppLanguage.system,
            'system',
          ),
        )
        .key;
  }
}

class AppRuntimeConfig {
  static final ValueNotifier<AppLanguage> language = ValueNotifier<AppLanguage>(
    AppLanguage.system,
  );
}

class AppOrientationLock {
  const AppOrientationLock._();

  static const List<DeviceOrientation> _mobilePortraitOnly =
      <DeviceOrientation>[DeviceOrientation.portraitUp];

  static bool get _shouldLockForCurrentPlatform {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }

  // The current mobile life-counter UX is designed for a fixed portrait canvas.
  // Keeping the lock centralized avoids fragile per-route orientation toggles.
  static Future<void> enforceMobilePortrait() async {
    if (!_shouldLockForCurrentPlatform) {
      return;
    }
    await SystemChrome.setPreferredOrientations(_mobilePortraitOnly);
  }
}

class InfoTipIds {
  static const String matchHistory = 'match_history';
  static const String statistics = 'statistics';
  static const String sideboardGuide = 'sideboard_guide';
  static const String opponentDeckSelection = 'opponent_deck_selection';
}

class AppUxStateStore {
  const AppUxStateStore._();

  static Future<bool> onboardingCompleted() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingCompletedKey) ?? false;
  }

  static Future<void> setOnboardingCompleted(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompletedKey, value);
  }

  static Future<bool> defaultGameSelected() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_defaultGameSelectedKey) ?? false;
  }

  static Future<void> setDefaultGameSelected(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_defaultGameSelectedKey, value);
  }

  static Future<Set<String>> loadSeenInfoTips() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> raw =
        prefs.getStringList(_seenInfoTipsKey) ?? <String>[];
    return raw
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toSet();
  }

  static Future<bool> hasSeenInfoTip(String tipId) async {
    final Set<String> seen = await loadSeenInfoTips();
    return seen.contains(tipId);
  }

  static Future<void> markInfoTipSeen(String tipId) async {
    final Set<String> seen = await loadSeenInfoTips();
    seen.add(tipId);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_seenInfoTipsKey, seen.toList(growable: false));
  }
}

@immutable
class AppStrings {
  const AppStrings(this.languageCode);

  final String languageCode;

  static const Map<String, Map<String, String>>
  _catalog = <String, Map<String, String>>{
    'en': <String, String>{
      'app.title': 'TCG Life Counter',
      'common.skip': 'Skip',
      'common.next': 'Next',
      'common.continue': 'Continue',
      'common.gotIt': 'Got it',
      'common.close': 'Close',
      'common.cancel': 'Cancel',
      'common.save': 'Save',
      'common.create': 'Create',
      'common.rename': 'Rename',
      'common.notes': 'Notes',
      'common.clear': 'Clear',
      'common.notNow': 'Not now',
      'common.premium': 'Premium feature',
      'tcg.yugioh': 'Yugioh',
      'tcg.mtg': 'MTG',
      'tcg.riftbound': 'Riftbound',
      'tcg.lorcana': 'Lorcana',
      'home.letsDuel': "Let's Duel",
      'home.gameHistory': 'Game History',
      'home.decksUtility': "Deck's Utility",
      'home.decksUtilitySubtitle': 'Decks, Sideboard and Plans',
      'home.customizeApp': 'Customize App',
      'home.topBottomPlayers': 'Top and bottom players',
      'home.savedMatches': '{count} saved matches',
      'home.premiumSaved': 'Premium feature • {count} saved',
      'home.namesAndColors': 'Names and colors',
      'home.comingSoon': "Coming soon! Contact me if you're interested.",
      'home.upgradeProTitle': 'Upgrade to Pro',
      'home.upgradeProBody':
          '{feature} is available only in Pro.\n\nAdd your real price later in App Store. For now you can test it with a demo unlock.',
      'home.buyProDemo': 'Buy Pro (demo)',
      'home.savedGamesToast': 'Saved {count} game(s) to Game History ({total})',
      'onboarding.title1': 'Track Games and Matches',
      'onboarding.body1':
          'Save single games and complete matches with a clear timeline.',
      'onboarding.title2': 'Save Decks, Opponents and Formats',
      'onboarding.body2':
          'Store deck, opponent deck, format and tags as match metadata.',
      'onboarding.title3': 'Review Statistics and Utilities',
      'onboarding.body3':
          'Open matchup history, statistics, notes and sideboard tools anytime.',
      'onboarding.chooseGame': 'Which game do you play the most?',
      'onboarding.chooseGameHint': 'You can change the main game in the options',
      'info.matchHistory.title': 'Match History',
      'info.matchHistory.body':
          'This area groups your saved matches and keeps game details in order.',
      'info.statistics.title': 'Statistics',
      'info.statistics.body':
          'Statistics are calculated from saved match results, not single life changes.',
      'info.sideboardGuide.title': 'Sideboard Guide',
      'info.sideboardGuide.body':
          'Open your saved side-in and side-out plans for the selected deck.',
      'info.opponentDeck.title': 'Opponent Deck',
      'info.opponentDeck.body':
          'Pick an existing opponent deck or create one quickly from the dropdown.',
      'sideboardGuide.dialogTitle': 'Sideboard Guide',
      'sideboardGuide.noDeckSelected': 'No deck selected.',
      'sideboardGuide.noPlansForDeck': 'No sideboard available for this deck.',
      'sideboardGuide.sideIn': 'Side In',
      'sideboardGuide.sideOut': 'Side Out',
      'customize.title': 'Customize App',
      'customize.players': 'Players',
      'customize.player1Name': 'Player',
      'customize.player2Name': 'Player 2 name',
      'customize.startup': 'Startup',
      'customize.openWith': 'Open app with',
      'customize.language': 'Language',
      'customize.languageSystem': 'System default',
      'customize.languageEnglish': 'English',
      'customize.languageItalian': 'Italiano',
      'customize.player1Color': 'Player 1 color',
      'customize.player2Color': 'Player 2 color',
      'customize.colors': 'Colors',
      'customize.bgStart': 'Background start',
      'customize.bgEnd': 'Background end',
      'customize.buttonColor': 'Button color',
      'customize.lpBg': 'Life Points background',
      'customize.preview': 'Preview',
      'customize.button': 'Button',
      'labels.player1': 'Player 1',
      'labels.player2': 'Player 2',
      'history.title': 'Game History',
      'history.empty':
          'No games tracked yet.\nStart a game or create one manually.',
      'history.sortFilter': 'Sort/filter',
      'history.sortBy': 'Sort by',
      'history.filters': 'Filters',
      'history.clearFilters': 'Clear filters',
      'history.byDate': 'By date',
      'history.byName': 'By name',
      'history.allDecks': 'All decks',
      'history.allOpponentDecks': 'All opponent decks',
      'history.allFormats': 'All formats',
      'history.opponentSearch': 'Opponent name',
      'history.byTag': 'By tag',
      'history.allTags': 'All tags',
      'history.noMatchesForTag': 'No matches for "{tag}".',
      'history.noMatchesWithFilters': 'No matches match the current filters.',
      'history.importTxt': 'Import .txt',
      'history.exportTxt': 'Export .txt',
      'history.addMatch': 'Add match',
      'history.addGame': 'Add game',
      'deckList.sortBy': 'Sort decks by',
      'deckList.filters': 'Deck filters',
      'deckList.sortAlphabetical': 'Alphabetical',
      'deckList.sortCreationDate': 'Creation date',
      'deckList.sortFormat': 'Format',
      'deckList.favoritesOnly': 'Favorites only',
      'deckList.allFormats': 'All formats',
      'deckList.allTags': 'All tags',
      'deckList.clearFilters': 'Clear filters',
      'deckList.empty': 'No decks yet.\nTap + to create your first deck.',
      'deckList.noDecksWithFilters': 'No decks match the current filters.',
      'statistics.title': 'Statistics',
      'statistics.empty': 'No match data for this deck yet.',
      'statistics.vs': 'vs {deck}',
      'statistics.matches': 'Matches: {count}',
      'statistics.wins': 'Wins: {count}',
      'statistics.losses': 'Losses: {count}',
      'statistics.draws': 'Draws: {count}',
      'statistics.winrate': 'Winrate: {value}%',
      'statistics.lossRate': 'Loss rate: {value}%',
      'section.userNotes': 'User Notes',
      'section.matchupHistory': 'Matchup History',
      'section.statistics': 'Statistics',
      'section.sideboardPlans': 'Sideboard Plans',
      'section.chooseSection': 'Choose a section',
      'field.opponent': 'Opponent',
      'field.deck': 'Deck',
      'field.opponentDeck': 'Opponent Deck',
      'field.format': 'Format',
      'field.tag': 'Tag',
      'field.gamesCount': '{count} game(s)',
      'field.matchName': 'Match name',
      'field.opponentName': 'Opponent name',
      'field.noFormat': 'No format',
      'field.addNewFormat': 'Add new format...',
      'field.noOpponentDeck': 'No opponent deck',
      'field.addNewDeck': 'Add new deck...',
      'field.deckInUse': 'Deck in use',
      'field.noDeck': 'No deck',
      'field.deckName': 'Deck name',
      'dialog.matchDetails': 'Match details',
      'dialog.gameDetails': 'Game details',
      'game.playerNames': 'Player names',
      'game.playerName': 'Player {n} name',
      'game.color': 'Color',
      'game.endOrResetMatch': 'End or reset match',
      'game.endOrResetGame': 'End or reset game',
      'game.saveAndExit': 'Save and exit',
      'game.sideboardGuide': 'Sideboard Guide',
      'game.resetWithoutSaving': 'Reset without saving',
      'game.discardAndExit': 'Discard current game and exit',
      'game.exitWithoutSaving': 'Exit without saving',
      'game.win': 'Win',
      'game.loss': 'Loss',
      'game.draw': 'Draw',
      'game.details': 'Details',
      'game.dice': 'Dice',
      'game.history': 'History',
      'game.histShort': 'Hist',
      'game.mana': 'Mana',
      'game.counters': 'Counters',
      'game.cntrShort': 'Cntr',
      'game.commander': 'Commander',
      'game.cmdShort': 'Cmd',
      'game.lpHistory': 'LP History',
      'common.loadMore': 'Load more',
    },
    'it': <String, String>{
      'app.title': 'TCG Life Counter',
      'common.skip': 'Salta',
      'common.next': 'Avanti',
      'common.continue': 'Continua',
      'common.gotIt': 'Capito',
      'common.close': 'Chiudi',
      'common.cancel': 'Annulla',
      'common.save': 'Salva',
      'common.create': 'Crea',
      'common.rename': 'Rinomina',
      'common.notes': 'Note',
      'common.clear': 'Pulisci',
      'common.notNow': 'Non ora',
      'common.premium': 'Funzionalita premium',
      'tcg.yugioh': 'Yugioh',
      'tcg.mtg': 'MTG',
      'tcg.riftbound': 'Riftbound',
      'tcg.lorcana': 'Lorcana',
      'home.letsDuel': 'Let\'s Duel',
      'home.gameHistory': 'Cronologia Partite',
      'home.decksUtility': 'Deck\'s Utility',
      'home.decksUtilitySubtitle': 'Deck, Sideboard e Piani',
      'home.customizeApp': 'Personalizza App',
      'home.topBottomPlayers': 'Giocatori alto e basso',
      'home.savedMatches': '{count} match salvati',
      'home.premiumSaved': 'Funzionalita premium • {count} salvati',
      'home.namesAndColors': 'Nomi e colori',
      'home.comingSoon': 'In arrivo! Contattami se sei interessato.',
      'home.upgradeProTitle': 'Passa a Pro',
      'home.upgradeProBody':
          '{feature} e disponibile solo nella Pro.\n\nAggiungerai il prezzo reale in App Store. Per ora puoi testare con lo sblocco demo.',
      'home.buyProDemo': 'Acquista Pro (demo)',
      'home.savedGamesToast': 'Salvati {count} game nella cronologia ({total})',
      'onboarding.title1': 'Traccia Game e Match',
      'onboarding.body1':
          'Salva game singoli e match completi con timeline ordinata.',
      'onboarding.title2': 'Salva Deck, Opponent e Format',
      'onboarding.body2':
          'Memorizza deck, opponent deck, format e tag nei dettagli match.',
      'onboarding.title3': 'Consulta Statistiche e Utility',
      'onboarding.body3':
          'Apri cronologia matchup, statistiche, note e strumenti in ogni momento.',
      'onboarding.chooseGame': 'Quale gioco giochi di più?',
      'onboarding.chooseGameHint': 'Puoi cambiare il gioco principale nelle opzioni',
      'info.matchHistory.title': 'Cronologia Match',
      'info.matchHistory.body':
          'Qui trovi i match salvati raggruppati con i dettagli dei game.',
      'info.statistics.title': 'Statistiche',
      'info.statistics.body':
          'Le statistiche sono calcolate sui risultati finali dei match.',
      'info.sideboardGuide.title': 'Guida Sideboard',
      'info.sideboardGuide.body':
          'Apri i piani side-in e side-out del deck selezionato.',
      'info.opponentDeck.title': 'Deck Avversario',
      'info.opponentDeck.body':
          'Seleziona un deck esistente o creane uno al volo dal menu.',
      'sideboardGuide.dialogTitle': 'Guida Sideboard',
      'sideboardGuide.noDeckSelected': 'Nessun deck selezionato.',
      'sideboardGuide.noPlansForDeck':
          'Nessuna sideboard disponibile per questo deck.',
      'sideboardGuide.sideIn': 'Side In',
      'sideboardGuide.sideOut': 'Side Out',
      'customize.title': 'Personalizza App',
      'customize.players': 'Giocatori',
      'customize.player1Name': 'Player',
      'customize.player2Name': 'Nome Player 2',
      'customize.startup': 'Avvio',
      'customize.openWith': 'Apri app con',
      'customize.language': 'Lingua',
      'customize.languageSystem': 'Default sistema',
      'customize.languageEnglish': 'English',
      'customize.languageItalian': 'Italiano',
      'customize.player1Color': 'Colore Player 1',
      'customize.player2Color': 'Colore Player 2',
      'customize.colors': 'Colori',
      'customize.bgStart': 'Sfondo iniziale',
      'customize.bgEnd': 'Sfondo finale',
      'customize.buttonColor': 'Colore pulsanti',
      'customize.lpBg': 'Sfondo Life Points',
      'customize.preview': 'Anteprima',
      'customize.button': 'Pulsante',
      'labels.player1': 'Player 1',
      'labels.player2': 'Player 2',
      'history.title': 'Cronologia Partite',
      'history.empty': 'Nessuna partita salvata.\nInizia un game o creane uno.',
      'history.sortFilter': 'Ordina/filtra',
      'history.sortBy': 'Ordina per',
      'history.filters': 'Filtri',
      'history.clearFilters': 'Azzera filtri',
      'history.byDate': 'Per data',
      'history.byName': 'Per nome',
      'history.allDecks': 'Tutti i deck',
      'history.allOpponentDecks': 'Tutti i deck avversari',
      'history.allFormats': 'Tutti i format',
      'history.opponentSearch': 'Nome avversario',
      'history.byTag': 'Per tag',
      'history.allTags': 'Tutti i tag',
      'history.noMatchesForTag': 'Nessun match per "{tag}".',
      'history.noMatchesWithFilters':
          'Nessun match corrisponde ai filtri attivi.',
      'history.importTxt': 'Importa .txt',
      'history.exportTxt': 'Esporta .txt',
      'history.addMatch': 'Aggiungi match',
      'history.addGame': 'Aggiungi game',
      'deckList.sortBy': 'Ordina i deck per',
      'deckList.filters': 'Filtri deck',
      'deckList.sortAlphabetical': 'Alfabetico',
      'deckList.sortCreationDate': 'Data creazione',
      'deckList.sortFormat': 'Format',
      'deckList.favoritesOnly': 'Solo preferiti',
      'deckList.allFormats': 'Tutti i format',
      'deckList.allTags': 'Tutti i tag',
      'deckList.clearFilters': 'Azzera filtri',
      'deckList.empty': 'Nessun deck.\nTocca + per creare il primo deck.',
      'deckList.noDecksWithFilters':
          'Nessun deck corrisponde ai filtri attivi.',
      'statistics.title': 'Statistiche',
      'statistics.empty': 'Nessun dato match per questo deck.',
      'statistics.vs': 'vs {deck}',
      'statistics.matches': 'Match: {count}',
      'statistics.wins': 'Vittorie: {count}',
      'statistics.losses': 'Sconfitte: {count}',
      'statistics.draws': 'Pareggi: {count}',
      'statistics.winrate': 'Winrate: {value}%',
      'statistics.lossRate': 'Loss rate: {value}%',
      'section.userNotes': 'User Notes',
      'section.matchupHistory': 'Matchup History',
      'section.statistics': 'Statistics',
      'section.sideboardPlans': 'Sideboard Plans',
      'section.chooseSection': 'Scegli una sezione',
      'field.opponent': 'Avversario',
      'field.deck': 'Deck',
      'field.opponentDeck': 'Deck Avversario',
      'field.format': 'Formato',
      'field.tag': 'Tag',
      'field.gamesCount': '{count} game',
      'field.matchName': 'Nome partita',
      'field.opponentName': 'Nome avversario',
      'field.noFormat': 'Nessun formato',
      'field.addNewFormat': 'Nuovo formato...',
      'field.noOpponentDeck': 'Nessun deck avversario',
      'field.addNewDeck': 'Nuovo deck...',
      'field.deckInUse': 'Deck in uso',
      'field.noDeck': 'Nessun deck',
      'field.deckName': 'Nome deck',
      'dialog.matchDetails': 'Dettagli della partita',
      'dialog.gameDetails': 'Dettagli del gioco',
      'game.playerNames': 'Nomi dei giocatori',
      'game.playerName': 'Nome Player {n}',
      'game.color': 'Colore',
      'game.endOrResetMatch': 'Termina o resetta la partita',
      'game.endOrResetGame': 'Termina o resetta il gioco',
      'game.saveAndExit': 'Salva ed esci',
      'game.sideboardGuide': 'Sideboard',
      'game.resetWithoutSaving': 'Azzera senza salvare',
      'game.discardAndExit': 'Scarta il gioco e esci',
      'game.exitWithoutSaving': 'Esci senza salvare',
      'game.win': 'Vittoria',
      'game.loss': 'Sconfitta',
      'game.draw': 'Pareggio',
      'game.details': 'Dettagli',
      'game.dice': 'Dado',
      'game.history': 'Storico',
      'game.histShort': 'Stor',
      'game.mana': 'Mana',
      'game.counters': 'Segnalini',
      'game.cntrShort': 'Segn',
      'game.commander': 'Commander',
      'game.cmdShort': 'Cmd',
      'game.lpHistory': 'Storico LP',
      'common.loadMore': 'Carica altri',
    },
  };

  String t(
    String key, {
    Map<String, Object?> params = const <String, Object?>{},
  }) {
    final String language = _catalog.containsKey(languageCode) ? languageCode : 'en';
    final String fallback = _catalog['en']?[key] ?? key;
    String value = _catalog[language]?[key] ?? fallback;
    if (params.isEmpty) {
      return value;
    }
    params.forEach((String name, Object? raw) {
      value = value.replaceAll('{$name}', '${raw ?? ''}');
    });
    return value;
  }
}

class AppTextScope extends InheritedWidget {
  const AppTextScope({super.key, required this.strings, required super.child});

  final AppStrings strings;

  static AppStrings of(BuildContext context) {
    final AppTextScope? scope = context
        .dependOnInheritedWidgetOfExactType<AppTextScope>();
    return scope?.strings ?? const AppStrings('en');
  }

  @override
  bool updateShouldNotify(AppTextScope oldWidget) {
    return oldWidget.strings.languageCode != strings.languageCode;
  }
}

extension AppTextX on BuildContext {
  AppStrings get txt => AppTextScope.of(this);
}

void _disposeTextControllersLater(Iterable<TextEditingController> controllers) {
  final List<TextEditingController> pending = controllers.toList(
    growable: false,
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    for (final TextEditingController controller in pending) {
      controller.dispose();
    }
  });
}

Future<void> showInfoTipOnce({
  required BuildContext context,
  required String tipId,
  required String titleKey,
  required String bodyKey,
  IconData icon = Icons.info_outline_rounded,
}) async {
  final bool alreadySeen = await AppUxStateStore.hasSeenInfoTip(tipId);
  if (alreadySeen || !context.mounted) {
    return;
  }
  final AppStrings txt = context.txt;
  await showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(txt.t(titleKey))),
          ],
        ),
        content: Text(txt.t(bodyKey)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(txt.t('common.gotIt')),
          ),
        ],
      );
    },
  );
  await AppUxStateStore.markInfoTipSeen(tipId);
}

String _normalizeTcgKey(String? raw, {String fallback = 'yugioh'}) {
  final String normalized = (raw ?? '').trim().toLowerCase();
  if (_supportedTcgStorageKeys.contains(normalized)) {
    return normalized;
  }
  return fallback;
}

String? _supportedTcgKeyOrNull(Object? raw) {
  if (raw is! String) {
    return null;
  }
  final String normalized = raw.trim().toLowerCase();
  if (_supportedTcgStorageKeys.contains(normalized)) {
    return normalized;
  }
  return null;
}

String _normalizeDeckName(String raw) {
  return raw.trim().toLowerCase();
}

SideboardDeck? _findUniqueDeckByName(
  Iterable<SideboardDeck> decks,
  String rawName,
) {
  final String normalized = _normalizeDeckName(rawName);
  if (normalized.isEmpty) {
    return null;
  }
  SideboardDeck? match;
  for (final SideboardDeck deck in decks) {
    if (_normalizeDeckName(deck.name) != normalized) {
      continue;
    }
    if (match != null) {
      return null;
    }
    match = deck;
  }
  return match;
}

bool _hasDeckNameConflict(
  Iterable<SideboardDeck> decks,
  String rawName, {
  String excludedDeckId = '',
}) {
  final String normalized = _normalizeDeckName(rawName);
  if (normalized.isEmpty) {
    return false;
  }
  final String trimmedExcludedId = excludedDeckId.trim();
  for (final SideboardDeck deck in decks) {
    if (trimmedExcludedId.isNotEmpty && deck.id == trimmedExcludedId) {
      continue;
    }
    if (_normalizeDeckName(deck.name) == normalized) {
      return true;
    }
  }
  return false;
}

bool _deckMatchesFormat(SideboardDeck deck, String format) {
  final String normalizedFormat = format.trim().toLowerCase();
  if (normalizedFormat.isEmpty) {
    return true;
  }
  return deck.format.trim().toLowerCase() == normalizedFormat;
}

List<SideboardDeck> _filterDecksByFormat(
  Iterable<SideboardDeck> decks,
  String format,
) {
  return decks
      .where((SideboardDeck deck) => _deckMatchesFormat(deck, format))
      .toList(growable: false);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppOrientationLock.enforceMobilePortrait();
  runApp(const YugiLifeCounterApp());
}

class YugiLifeCounterApp extends StatefulWidget {
  const YugiLifeCounterApp({super.key});

  @override
  State<YugiLifeCounterApp> createState() => _YugiLifeCounterAppState();
}

class _YugiLifeCounterAppState extends State<YugiLifeCounterApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(AppOrientationLock.enforceMobilePortrait());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(AppOrientationLock.enforceMobilePortrait());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppRuntimeConfig.language,
      builder: (BuildContext context, AppLanguage language, Widget? _) {
        final String localeCode = language.localeCode;
        return MaterialApp(
          title: const AppStrings('en').t('app.title'),
          debugShowCheckedModeBanner: false,
          locale: language.materialLocale,
          supportedLocales: const <Locale>[Locale('en'), Locale('it')],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFE53935),
              brightness: Brightness.dark,
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(foregroundColor: Colors.white),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(foregroundColor: Colors.white),
            ),
          ),
          builder: (BuildContext context, Widget? child) {
            return AppTextScope(
              strings: AppStrings(localeCode),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const HomeScreen(),
        );
      },
    );
  }
}

@immutable
class AppSettings {
  const AppSettings({
    required this.playerOneName,
    required this.playerTwoName,
    required this.startupTcgKey,
    required this.appLanguageKey,
    required this.backgroundStartColor,
    required this.backgroundEndColor,
    required this.buttonColor,
    required this.lifePointsBackgroundColor,
    required this.playerOneColor,
    required this.playerTwoColor,
  });

  factory AppSettings.defaults() {
    return const AppSettings(
      playerOneName: 'Player 1',
      playerTwoName: 'Player 2',
      startupTcgKey: 'yugioh',
      appLanguageKey: 'system',
      backgroundStartColor: Color(0xFF141414),
      backgroundEndColor: Color(0xFF341212),
      buttonColor: Color(0xFF2B2424),
      lifePointsBackgroundColor: Color(0xFF261E1E),
      playerOneColor: Color(0xFF261E1E),
      playerTwoColor: Color(0xFF1E2626),
    );
  }

  final String playerOneName;
  final String playerTwoName;
  final String startupTcgKey;
  final String appLanguageKey;
  final Color backgroundStartColor;
  final Color backgroundEndColor;
  final Color buttonColor;
  final Color lifePointsBackgroundColor;
  final Color playerOneColor;
  final Color playerTwoColor;

  AppSettings copyWith({
    String? playerOneName,
    String? playerTwoName,
    String? startupTcgKey,
    String? appLanguageKey,
    Color? backgroundStartColor,
    Color? backgroundEndColor,
    Color? buttonColor,
    Color? lifePointsBackgroundColor,
    Color? playerOneColor,
    Color? playerTwoColor,
  }) {
    return AppSettings(
      playerOneName: playerOneName ?? this.playerOneName,
      playerTwoName: playerTwoName ?? this.playerTwoName,
      startupTcgKey: startupTcgKey ?? this.startupTcgKey,
      appLanguageKey: appLanguageKey ?? this.appLanguageKey,
      backgroundStartColor: backgroundStartColor ?? this.backgroundStartColor,
      backgroundEndColor: backgroundEndColor ?? this.backgroundEndColor,
      buttonColor: buttonColor ?? this.buttonColor,
      lifePointsBackgroundColor:
          lifePointsBackgroundColor ?? this.lifePointsBackgroundColor,
      playerOneColor: playerOneColor ?? this.playerOneColor,
      playerTwoColor: playerTwoColor ?? this.playerTwoColor,
    );
  }

  Map<String, Object> toJson() {
    return <String, Object>{
      'playerOneName': playerOneName,
      'playerTwoName': playerTwoName,
      'startupTcgKey': startupTcgKey,
      'appLanguageKey': appLanguageKey,
      'backgroundStartColor': backgroundStartColor.toARGB32(),
      'backgroundEndColor': backgroundEndColor.toARGB32(),
      'buttonColor': buttonColor.toARGB32(),
      'lifePointsBackgroundColor': lifePointsBackgroundColor.toARGB32(),
      'playerOneColor': playerOneColor.toARGB32(),
      'playerTwoColor': playerTwoColor.toARGB32(),
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final AppSettings fallback = AppSettings.defaults();

    Color parseColor(String key, Color fallbackColor) {
      final Object? raw = json[key];
      if (raw is int) {
        return Color(raw);
      }
      if (raw is String) {
        final int? parsed = int.tryParse(raw);
        if (parsed != null) {
          return Color(parsed);
        }
      }
      return fallbackColor;
    }

    String parseName(String key, String fallbackName) {
      final Object? raw = json[key];
      if (raw is! String) {
        return fallbackName;
      }
      final String trimmed = raw.trim();
      if (trimmed.isEmpty) {
        return fallbackName;
      }
      return trimmed;
    }

    String parseTcgKey(String key, String fallbackKey) {
      final Object? raw = json[key];
      return _normalizeTcgKey(
        raw is String ? raw : null,
        fallback: fallbackKey,
      );
    }

    return AppSettings(
      playerOneName: parseName('playerOneName', fallback.playerOneName),
      playerTwoName: parseName('playerTwoName', fallback.playerTwoName),
      startupTcgKey: parseTcgKey('startupTcgKey', fallback.startupTcgKey),
      appLanguageKey: AppLanguageX.fromStorageKey(
        json['appLanguageKey'] as String?,
      ).storageKey,
      backgroundStartColor: parseColor(
        'backgroundStartColor',
        fallback.backgroundStartColor,
      ),
      backgroundEndColor: parseColor(
        'backgroundEndColor',
        fallback.backgroundEndColor,
      ),
      buttonColor: parseColor('buttonColor', fallback.buttonColor),
      lifePointsBackgroundColor: parseColor(
        'lifePointsBackgroundColor',
        fallback.lifePointsBackgroundColor,
      ),
      playerOneColor: parseColor('playerOneColor', fallback.playerOneColor),
      playerTwoColor: parseColor('playerTwoColor', fallback.playerTwoColor),
    );
  }
}

@immutable
class GameRecord {
  const GameRecord({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.gameStage,
    required this.notes,
    required this.lifePointHistory,
    this.tcgKey = 'yugioh',
    this.deckId = '',
    this.matchResult = '',
    this.opponentName = '',
    this.deckName = '',
    this.playerOneName = 'Player 1',
    this.playerTwoName = 'Player 2',
    this.playerCount = 2,
    this.matchId = '',
    this.matchName = '',
    this.matchFormat = '',
    this.opponentDeckId = '',
    this.opponentDeckName = '',
    this.matchTag = '',
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final String gameStage;
  final String notes;
  final List<String> lifePointHistory;
  final String tcgKey;
  final String deckId;
  final String matchResult;
  final String opponentName;
  final String deckName;
  final String playerOneName;
  final String playerTwoName;
  final int playerCount;
  final String matchId;
  final String matchName;
  final String matchFormat;
  final String opponentDeckId;
  final String opponentDeckName;
  final String matchTag;

  GameRecord copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    String? gameStage,
    String? notes,
    List<String>? lifePointHistory,
    String? tcgKey,
    String? deckId,
    String? matchResult,
    String? opponentName,
    String? deckName,
    String? playerOneName,
    String? playerTwoName,
    int? playerCount,
    String? matchId,
    String? matchName,
    String? matchFormat,
    String? opponentDeckId,
    String? opponentDeckName,
    String? matchTag,
  }) {
    return GameRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      gameStage: gameStage ?? this.gameStage,
      notes: notes ?? this.notes,
      lifePointHistory: lifePointHistory ?? this.lifePointHistory,
      tcgKey: tcgKey ?? this.tcgKey,
      deckId: deckId ?? this.deckId,
      matchResult: matchResult ?? this.matchResult,
      opponentName: opponentName ?? this.opponentName,
      deckName: deckName ?? this.deckName,
      playerOneName: playerOneName ?? this.playerOneName,
      playerTwoName: playerTwoName ?? this.playerTwoName,
      playerCount: playerCount ?? this.playerCount,
      matchId: matchId ?? this.matchId,
      matchName: matchName ?? this.matchName,
      matchFormat: matchFormat ?? this.matchFormat,
      opponentDeckId: opponentDeckId ?? this.opponentDeckId,
      opponentDeckName: opponentDeckName ?? this.opponentDeckName,
      matchTag: matchTag ?? this.matchTag,
    );
  }

  Map<String, Object> toJson() {
    return <String, Object>{
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'gameStage': gameStage,
      'notes': notes,
      'lifePointHistory': lifePointHistory,
      'tcgKey': tcgKey,
      'deckId': deckId,
      'matchResult': matchResult,
      'opponentName': opponentName,
      'deckName': deckName,
      'playerOneName': playerOneName,
      'playerTwoName': playerTwoName,
      'playerCount': playerCount,
      'matchId': matchId,
      'matchName': matchName,
      'matchFormat': matchFormat,
      'opponentDeckId': opponentDeckId,
      'opponentDeckName': opponentDeckName,
      'matchTag': matchTag,
    };
  }

  factory GameRecord.fromJson(Map<String, dynamic> json) {
    final String id = (json['id'] as String?)?.trim().isNotEmpty == true
        ? json['id'] as String
        : DateTime.now().microsecondsSinceEpoch.toString();
    final String title = (json['title'] as String?)?.trim().isNotEmpty == true
        ? json['title'] as String
        : 'Duel';
    final String rawGameStage = ((json['gameStage'] as String?) ?? '')
        .trim()
        .toUpperCase();
    final String gameStage = _supportedGameStages.contains(rawGameStage)
        ? rawGameStage
        : 'G1';
    final String notes = (json['notes'] as String?) ?? '';
    final String deckId = ((json['deckId'] as String?) ?? '').trim();
    final String rawResult = ((json['matchResult'] as String?) ?? '').trim();
    final String matchResult = _supportedMatchResults.contains(rawResult)
        ? rawResult
        : '';
    final String opponentName = ((json['opponentName'] as String?) ?? '')
        .trim();
    final String deckName = ((json['deckName'] as String?) ?? '').trim();
    final String playerOneName = ((json['playerOneName'] as String?) ?? '')
        .trim();
    final String playerTwoName = ((json['playerTwoName'] as String?) ?? '')
        .trim();
    final String matchId = ((json['matchId'] as String?) ?? '').trim();
    final String matchName = ((json['matchName'] as String?) ?? '').trim();
    final String matchFormat = ((json['matchFormat'] as String?) ?? '').trim();
    final String opponentDeckId = ((json['opponentDeckId'] as String?) ?? '')
        .trim();
    final String opponentDeckName =
        ((json['opponentDeckName'] as String?) ?? '').trim();
    final String matchTag = ((json['matchTag'] as String?) ?? '').trim();
    final bool hasRawTcgKey =
        json['tcgKey'] is String &&
        (json['tcgKey'] as String).trim().isNotEmpty;
    final String inferredTcgFallback = title.toLowerCase().startsWith('mtg')
        ? 'mtg'
        : 'yugioh';
    final String tcgKey = _normalizeTcgKey(
      hasRawTcgKey ? json['tcgKey'] as String : null,
      fallback: inferredTcgFallback,
    );
    final Object? rawHistory = json['lifePointHistory'];
    final List<String> lifePointHistory = rawHistory is List
        ? rawHistory
              .whereType<Object?>()
              .map((Object? entry) => entry?.toString() ?? '')
              .where((String entry) => entry.trim().isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    int parsedPlayerCount = 2;
    final Object? rawPlayerCount = json['playerCount'];
    if (rawPlayerCount is int) {
      parsedPlayerCount = rawPlayerCount;
    } else if (rawPlayerCount is String) {
      parsedPlayerCount = int.tryParse(rawPlayerCount.trim()) ?? 2;
    } else if (tcgKey == SupportedTcg.yugioh.storageKey) {
      parsedPlayerCount = 2;
    } else if (lifePointHistory.isNotEmpty) {
      if (lifePointHistory.first.contains('|')) {
        parsedPlayerCount = 2;
      } else {
        final RegExp playerPattern = RegExp(
          r'Player\s+(\d+)',
          caseSensitive: false,
        );
        int maxPlayerIndex = 0;
        for (final String line in lifePointHistory) {
          for (final RegExpMatch match in playerPattern.allMatches(line)) {
            final int? parsed = int.tryParse(match.group(1) ?? '');
            if (parsed != null && parsed > maxPlayerIndex) {
              maxPlayerIndex = parsed;
            }
          }
        }
        if (maxPlayerIndex >= 2) {
          parsedPlayerCount = maxPlayerIndex;
        }
      }
    }
    final int playerCount = parsedPlayerCount.clamp(2, 6).toInt();
    final String? rawDate = json['createdAt'] as String?;
    final DateTime createdAt =
        DateTime.tryParse(rawDate ?? '') ?? DateTime.now();

    return GameRecord(
      id: id,
      title: title,
      createdAt: createdAt,
      gameStage: gameStage,
      notes: notes,
      lifePointHistory: lifePointHistory,
      tcgKey: tcgKey,
      deckId: deckId,
      matchResult: matchResult,
      opponentName: opponentName,
      deckName: deckName,
      playerOneName: playerOneName.isEmpty ? 'Player 1' : playerOneName,
      playerTwoName: playerTwoName.isEmpty ? 'Player 2' : playerTwoName,
      playerCount: playerCount,
      matchId: matchId,
      matchName: matchName,
      matchFormat: matchFormat,
      opponentDeckId: opponentDeckId,
      opponentDeckName: opponentDeckName,
      matchTag: matchTag,
    );
  }
}

@immutable
class DuelCompletedGamePayload {
  const DuelCompletedGamePayload({
    required this.lifePointHistory,
    required this.gameStage,
    required this.opponentName,
    required this.deckId,
    required this.deckName,
    required this.opponentDeckId,
    required this.opponentDeckName,
    required this.matchFormat,
    required this.matchTag,
    required this.matchId,
    required this.matchName,
    required this.matchResult,
    required this.createdAt,
  });

  final List<String> lifePointHistory;
  final String gameStage;
  final String opponentName;
  final String deckId;
  final String deckName;
  final String opponentDeckId;
  final String opponentDeckName;
  final String matchFormat;
  final String matchTag;
  final String matchId;
  final String matchName;
  final String matchResult;
  final DateTime createdAt;
}

@immutable
class DuelResultPayload {
  const DuelResultPayload({
    required this.lifePointHistory,
    required this.gameStage,
    required this.opponentName,
    required this.deckId,
    required this.deckName,
    required this.opponentDeckId,
    required this.opponentDeckName,
    required this.matchFormat,
    required this.matchTag,
    required this.matchResult,
    required this.playerCount,
    this.shouldSave = true,
    this.completedGames = const <DuelCompletedGamePayload>[],
    this.createdDecks = const <SideboardDeck>[],
    this.matchId = '',
    this.matchName = '',
  });

  final List<String> lifePointHistory;
  final String gameStage;
  final String opponentName;
  final String deckId;
  final String deckName;
  final String opponentDeckId;
  final String opponentDeckName;
  final String matchFormat;
  final String matchTag;
  final String matchResult;
  final int playerCount;
  final bool shouldSave;
  final List<DuelCompletedGamePayload> completedGames;
  final List<SideboardDeck> createdDecks;
  final String matchId;
  final String matchName;
}

typedef DuelCheckpointCallback =
    Future<void> Function(DuelResultPayload payload);

@immutable
class TwoPlayerLifeEvent {
  const TwoPlayerLifeEvent({
    required this.player,
    required this.delta,
    required this.resultingLife,
  });

  final int player;
  final int delta;
  final int resultingLife;
}

List<String> _buildTwoPlayerHistoryTable({
  required String playerOneName,
  required String playerTwoName,
  required int initialPlayerOneLife,
  required int initialPlayerTwoLife,
  required List<TwoPlayerLifeEvent> events,
}) {
  String formatSigned(int value) => value > 0 ? '+$value' : '$value';

  final List<(String, String)> rows = <(String, String)>[
    (playerOneName, playerTwoName),
    ('$initialPlayerOneLife', '$initialPlayerTwoLife'),
    for (final TwoPlayerLifeEvent event in events)
      event.player == 1
          ? ('${formatSigned(event.delta)} = ${event.resultingLife}', '')
          : ('', '${formatSigned(event.delta)} = ${event.resultingLife}'),
  ];

  int leftWidth = 0;
  int rightWidth = 0;
  for (final (String left, String right) in rows) {
    leftWidth = max(leftWidth, left.length);
    rightWidth = max(rightWidth, right.length);
  }

  return rows
      .map(
        ((String, String) row) =>
            '${row.$1.padRight(leftWidth)} | ${row.$2.padRight(rightWidth)}',
      )
      .toList(growable: false);
}

bool _looksLikeTwoPlayerHistoryTable(List<String> lines) {
  if (lines.length < 2) {
    return false;
  }
  for (final String line in lines) {
    if (!line.contains('|')) {
      return false;
    }
  }
  return true;
}

List<(String, String)> _splitTwoPlayerHistoryRows(List<String> lines) {
  return lines
      .map(((String line) {
        final int separatorIndex = line.indexOf('|');
        if (separatorIndex < 0) {
          return (line.trim(), '');
        }
        final String left = line.substring(0, separatorIndex).trimRight();
        final String right = line.substring(separatorIndex + 1).trimLeft();
        return (left, right);
      }))
      .toList(growable: false);
}

({String playerName, String content})? _parseNamedLifeHistoryLine(String line) {
  final int separatorIndex = line.indexOf(':');
  if (separatorIndex <= 0) {
    return null;
  }
  final String playerName = line.substring(0, separatorIndex).trim();
  final String content = line.substring(separatorIndex + 1).trim();
  if (playerName.isEmpty || content.isEmpty) {
    return null;
  }
  return (playerName: playerName, content: content);
}

({List<String> headers, List<List<String>> rows})?
_buildThreeOrFourPlayerHistoryGrid({
  required List<String> lines,
  required int playerCount,
}) {
  if (playerCount < 3 || playerCount > 4 || lines.length < playerCount) {
    return null;
  }

  final List<String> headers = List<String>.generate(
    playerCount,
    (int index) => 'P${index + 1}',
  );
  final List<String> initialRow = List<String>.filled(playerCount, '');

  for (int index = 0; index < playerCount; index += 1) {
    final ({String playerName, String content})? parsed =
        _parseNamedLifeHistoryLine(lines[index]);
    if (parsed == null) {
      return null;
    }
    headers[index] = parsed.playerName;
    initialRow[index] = parsed.content;
  }

  final Map<String, int> playerIndexByName = <String, int>{
    for (int index = 0; index < headers.length; index += 1)
      headers[index].trim().toLowerCase(): index,
  };

  final List<List<String>> rows = <List<String>>[initialRow];
  for (final String line in lines.skip(playerCount)) {
    final ({String playerName, String content})? parsed =
        _parseNamedLifeHistoryLine(line);
    if (parsed == null) {
      return null;
    }
    final int? playerIndex =
        playerIndexByName[parsed.playerName.trim().toLowerCase()];
    if (playerIndex == null) {
      return null;
    }
    final List<String> row = List<String>.filled(playerCount, '');
    row[playerIndex] = parsed.content;
    rows.add(row);
  }

  return (headers: headers, rows: rows);
}

Widget _buildColumnarLifeHistoryView({
  required List<String> headers,
  required List<List<String>> rows,
  required Color dividerColor,
}) {
  final int playerCount = headers.length;
  final double headerFontSize = playerCount == 4 ? 11.0 : 12.2;
  final double bodyFontSize = playerCount == 4 ? 10.5 : 11.8;
  final double horizontalPadding = playerCount == 4 ? 6 : 8;
  final double minColumnWidth = playerCount == 4 ? 92 : 112;

  Widget buildGridRow(
    List<String> cells, {
    required bool isHeader,
    int? index,
  }) {
    final bool isOdd = index != null && index.isOdd;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: isHeader ? 8 : 7,
      ),
      decoration: isHeader
          ? BoxDecoration(
              border: Border(bottom: BorderSide(color: dividerColor, width: 1)),
            )
          : BoxDecoration(
              color: isOdd
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.transparent,
              border: Border(
                bottom: BorderSide(color: dividerColor.withValues(alpha: 0.45)),
              ),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int cellIndex = 0; cellIndex < cells.length; cellIndex += 1) ...[
            Expanded(
              child: Text(
                cells[cellIndex],
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: isHeader ? FontWeight.w800 : FontWeight.w500,
                  fontSize: isHeader ? headerFontSize : bodyFontSize,
                ),
              ),
            ),
            if (cellIndex < cells.length - 1)
              Container(
                width: 1,
                height: isHeader ? 24 : 20,
                color: dividerColor,
              ),
          ],
        ],
      ),
    );
  }

  return LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final double gridWidth = max(
        constraints.maxWidth,
        headers.length * minColumnWidth + (headers.length - 1),
      );
      return SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: gridWidth,
            child: Column(
              children: [
                buildGridRow(headers, isHeader: true),
                for (int index = 0; index < rows.length; index += 1)
                  buildGridRow(rows[index], isHeader: false, index: index),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _buildLifeHistoryView({
  required List<String> lines,
  required int playerCount,
  required Color dividerColor,
}) {
  if (playerCount >= 3 && playerCount <= 4) {
    final ({List<String> headers, List<List<String>> rows})? gridData =
        _buildThreeOrFourPlayerHistoryGrid(
          lines: lines,
          playerCount: playerCount,
        );
    if (gridData != null) {
      return _buildColumnarLifeHistoryView(
        headers: gridData.headers,
        rows: gridData.rows,
        dividerColor: dividerColor,
      );
    }
  }

  if (!_looksLikeTwoPlayerHistoryTable(lines)) {
    return SingleChildScrollView(
      child: SelectableText(
        lines.join('\n'),
        style: const TextStyle(height: 1.35, fontFamily: 'monospace'),
      ),
    );
  }

  final List<(String, String)> rows = _splitTwoPlayerHistoryRows(lines);
  final (String, String) header = rows.first;
  final List<(String, String)> bodyRows = rows.skip(1).toList(growable: false);

  Widget buildRow((String, String) row, {required bool isHeader, int? index}) {
    final bool isOdd = index != null && index.isOdd;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: isHeader ? 8 : 7),
      decoration: isHeader
          ? BoxDecoration(
              border: Border(bottom: BorderSide(color: dividerColor, width: 1)),
            )
          : BoxDecoration(
              color: isOdd
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.transparent,
              border: Border(
                bottom: BorderSide(color: dividerColor.withValues(alpha: 0.45)),
              ),
            ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              row.$1,
              textAlign: TextAlign.left,
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: isHeader ? FontWeight.w800 : FontWeight.w500,
                fontSize: isHeader ? 13 : 12.5,
              ),
            ),
          ),
          Container(width: 1, height: isHeader ? 24 : 20, color: dividerColor),
          Expanded(
            child: Text(
              row.$2,
              textAlign: TextAlign.left,
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: isHeader ? FontWeight.w800 : FontWeight.w500,
                fontSize: isHeader ? 13 : 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  return SingleChildScrollView(
    child: Column(
      children: [
        buildRow(header, isHeader: true),
        for (int index = 0; index < bodyRows.length; index += 1)
          buildRow(bodyRows[index], isHeader: false, index: index),
      ],
    ),
  );
}

@immutable
class SideboardCardEntry {
  const SideboardCardEntry({required this.name, required this.copies});

  final String name;
  final int copies;

  SideboardCardEntry copyWith({String? name, int? copies}) {
    return SideboardCardEntry(
      name: name ?? this.name,
      copies: copies ?? this.copies,
    );
  }

  Map<String, Object> toJson() {
    return <String, Object>{'name': name, 'copies': copies};
  }

  factory SideboardCardEntry.fromJson(Map<String, dynamic> json) {
    final String rawName = (json['name'] as String?)?.trim() ?? '';
    final String name = rawName.isEmpty ? 'Card' : rawName;

    int copies = 1;
    final Object? rawCopies = json['copies'];
    if (rawCopies is int) {
      copies = rawCopies;
    } else if (rawCopies is String) {
      copies = int.tryParse(rawCopies) ?? 1;
    }
    copies = copies.clamp(1, 4);

    return SideboardCardEntry(name: name, copies: copies);
  }
}

@immutable
class SideboardMatchup {
  const SideboardMatchup({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.sideIn,
    required this.sideOut,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final List<SideboardCardEntry> sideIn;
  final List<SideboardCardEntry> sideOut;

  SideboardMatchup copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    List<SideboardCardEntry>? sideIn,
    List<SideboardCardEntry>? sideOut,
  }) {
    return SideboardMatchup(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      sideIn: sideIn ?? this.sideIn,
      sideOut: sideOut ?? this.sideOut,
    );
  }

  Map<String, Object> toJson() {
    return <String, Object>{
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'sideIn': sideIn
          .map((SideboardCardEntry entry) => entry.toJson())
          .toList(growable: false),
      'sideOut': sideOut
          .map((SideboardCardEntry entry) => entry.toJson())
          .toList(growable: false),
    };
  }

  factory SideboardMatchup.fromJson(Map<String, dynamic> json) {
    final String id = (json['id'] as String?)?.trim().isNotEmpty == true
        ? json['id'] as String
        : DateTime.now().microsecondsSinceEpoch.toString();
    final String name = (json['name'] as String?)?.trim().isNotEmpty == true
        ? json['name'] as String
        : 'Matchup';
    final String rawCreatedAt = (json['createdAt'] as String?) ?? '';
    DateTime createdAt = DateTime.tryParse(rawCreatedAt) ?? DateTime.now();
    if (rawCreatedAt.trim().isEmpty) {
      final int? createdAtFromId = int.tryParse(id);
      if (createdAtFromId != null) {
        createdAt = DateTime.fromMicrosecondsSinceEpoch(createdAtFromId);
      }
    }

    List<SideboardCardEntry> parseCardList(String key) {
      final Object? raw = json[key];
      if (raw is! List) {
        return const <SideboardCardEntry>[];
      }

      final List<SideboardCardEntry> parsed = <SideboardCardEntry>[];
      for (final Object? item in raw) {
        if (item is Map) {
          parsed.add(
            SideboardCardEntry.fromJson(Map<String, dynamic>.from(item)),
          );
          continue;
        }

        final String asText = item?.toString().trim() ?? '';
        if (asText.isEmpty) {
          continue;
        }
        parsed.add(SideboardCardEntry(name: asText, copies: 1));
      }
      return parsed.toList(growable: false);
    }

    return SideboardMatchup(
      id: id,
      name: name,
      createdAt: createdAt,
      sideIn: parseCardList('sideIn'),
      sideOut: parseCardList('sideOut'),
    );
  }
}

@immutable
class SideboardDeck {
  const SideboardDeck({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.isFavorite,
    required this.userNotes,
    required this.matchups,
    this.format = '',
    this.tag = '',
    this.tcgKey = 'yugioh',
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final bool isFavorite;
  final String userNotes;
  final List<SideboardMatchup> matchups;
  final String format;
  final String tag;
  final String tcgKey;

  SideboardDeck copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    bool? isFavorite,
    String? userNotes,
    List<SideboardMatchup>? matchups,
    String? format,
    String? tag,
    String? tcgKey,
  }) {
    return SideboardDeck(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      isFavorite: isFavorite ?? this.isFavorite,
      userNotes: userNotes ?? this.userNotes,
      matchups: matchups ?? this.matchups,
      format: format ?? this.format,
      tag: tag ?? this.tag,
      tcgKey: tcgKey ?? this.tcgKey,
    );
  }

  Map<String, Object> toJson() {
    return <String, Object>{
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'isFavorite': isFavorite,
      'userNotes': userNotes,
      'matchups': matchups
          .map((SideboardMatchup matchup) => matchup.toJson())
          .toList(growable: false),
      'tag': tag,
      'format': format,
      'tcgKey': tcgKey,
    };
  }

  factory SideboardDeck.fromJson(Map<String, dynamic> json) {
    final String id = (json['id'] as String?)?.trim().isNotEmpty == true
        ? json['id'] as String
        : DateTime.now().microsecondsSinceEpoch.toString();
    final String name = (json['name'] as String?)?.trim().isNotEmpty == true
        ? json['name'] as String
        : 'Deck';
    final DateTime createdAt =
        DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
        DateTime.now();
    final bool isFavorite = json['isFavorite'] == true;
    final String userNotes = (json['userNotes'] as String?) ?? '';
    final String tag = ((json['tag'] as String?) ?? '').trim();
    final String format = ((json['format'] as String?) ?? '').trim();
    final String tcgKey = _normalizeTcgKey(json['tcgKey'] as String?);
    final Object? rawMatchups = json['matchups'];
    final List<SideboardMatchup> parsedMatchups = rawMatchups is List
        ? rawMatchups
              .whereType<Map>()
              .map(
                (Map item) =>
                    SideboardMatchup.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList(growable: false)
        : const <SideboardMatchup>[];

    return SideboardDeck(
      id: id,
      name: name,
      createdAt: createdAt,
      isFavorite: isFavorite,
      userNotes: userNotes,
      matchups: parsedMatchups,
      format: format.isNotEmpty ? format : tag,
      tag: tag,
      tcgKey: tcgKey,
    );
  }
}

@immutable
class SideboardBookResult {
  const SideboardBookResult({required this.decks, required this.records});

  final List<SideboardDeck> decks;
  final List<GameRecord> records;
}

@immutable
class SideboardDeckEditResult {
  const SideboardDeckEditResult({required this.deck, required this.records});

  final SideboardDeck deck;
  final List<GameRecord> records;
}

const List<String> _supportedGameStages = <String>['G1', 'G2', 'G3'];
const List<String> _supportedMatchResults = <String>['Win', 'Loss', 'Draw'];
const String _historyExportSchema = 'TCG_LIFE_COUNTER_HISTORY_V1';

enum SupportedTcg { yugioh, mtg, riftbound, lorcana }

const List<SupportedTcg> _supportedTcgAlphabeticalOrder = <SupportedTcg>[
  SupportedTcg.lorcana,
  SupportedTcg.mtg,
  SupportedTcg.riftbound,
  SupportedTcg.yugioh,
];

extension SupportedTcgX on SupportedTcg {
  String get label {
    switch (this) {
      case SupportedTcg.yugioh:
        return 'Yugioh';
      case SupportedTcg.mtg:
        return 'MTG';
      case SupportedTcg.riftbound:
        return 'Riftbound';
      case SupportedTcg.lorcana:
        return 'Lorcana';
    }
  }

  String get storageKey {
    switch (this) {
      case SupportedTcg.yugioh:
        return 'yugioh';
      case SupportedTcg.mtg:
        return 'mtg';
      case SupportedTcg.riftbound:
        return 'riftbound';
      case SupportedTcg.lorcana:
        return 'lorcana';
    }
  }

  static SupportedTcg fromStorageKey(String? raw) {
    final String normalized = (raw ?? '').trim().toLowerCase();
    switch (normalized) {
      case 'lorcana':
        return SupportedTcg.lorcana;
      case 'mtg':
        return SupportedTcg.mtg;
      case 'riftbound':
        return SupportedTcg.riftbound;
      case 'yugioh':
      default:
        return SupportedTcg.yugioh;
    }
  }

  ({Color bgStart, Color bgEnd}) get homePresetColors {
    switch (this) {
      case SupportedTcg.yugioh:
        return (bgStart: const Color(0xFF1A0A0A), bgEnd: const Color(0xFF3D1A1A));
      case SupportedTcg.mtg:
        return (bgStart: const Color(0xFF0A0F1A), bgEnd: const Color(0xFF1A2B3D));
      case SupportedTcg.riftbound:
        return (bgStart: const Color(0xFF0A1A0A), bgEnd: const Color(0xFF1A3A1A));
      case SupportedTcg.lorcana:
        return (bgStart: const Color(0xFF150A1A), bgEnd: const Color(0xFF3D1A50));
    }
  }
}

enum DuelRuleSet { yugioh, mtg }

String _formatDateTime(DateTime date, [BuildContext? context]) {
  final DateTime local = date.toLocal();
  if (context != null) {
    final MaterialLocalizations localizations = MaterialLocalizations.of(
      context,
    );
    final String datePart = localizations.formatCompactDate(local);
    final String timePart = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: true,
    );
    return '$datePart $timePart';
  }
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${twoDigits(local.day)}/${twoDigits(local.month)}/${local.year} ${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

int _gameStageSortKey(String rawStage) {
  final String normalized = rawStage.trim().toUpperCase();
  if (normalized.startsWith('G')) {
    final int? parsed = int.tryParse(normalized.substring(1));
    if (parsed != null) {
      return parsed;
    }
  }
  return 999;
}

enum MatchAggregateResult { pending, win, loss, draw }

enum MatchHistorySortMode { date, name }

@immutable
class _FilterOption {
  const _FilterOption({required this.value, required this.label});

  final String value;
  final String label;
}

String _normalizedMatchResultOrEmpty(String raw) {
  final String trimmed = raw.trim();
  return _supportedMatchResults.contains(trimmed) ? trimmed : '';
}

MatchAggregateResult _aggregateMatchResultFromGames(List<GameRecord> games) {
  int wins = 0;
  int losses = 0;
  int draws = 0;

  for (final GameRecord game in games) {
    switch (_normalizedMatchResultOrEmpty(game.matchResult)) {
      case 'Win':
        wins += 1;
        if (wins >= 2) {
          return MatchAggregateResult.win;
        }
        break;
      case 'Loss':
        losses += 1;
        if (losses >= 2) {
          return MatchAggregateResult.loss;
        }
        break;
      case 'Draw':
        draws += 1;
        break;
      default:
        break;
    }
  }

  if (wins == 0 && losses == 0 && draws > 0) {
    return MatchAggregateResult.draw;
  }
  if (draws > 0 && wins == losses && (wins + losses) > 0) {
    return MatchAggregateResult.draw;
  }
  return MatchAggregateResult.pending;
}

String _matchAggregateResultLabel(MatchAggregateResult result) {
  switch (result) {
    case MatchAggregateResult.win:
      return 'Win';
    case MatchAggregateResult.loss:
      return 'Loss';
    case MatchAggregateResult.draw:
      return 'Draw';
    case MatchAggregateResult.pending:
      return 'Pending';
  }
}

@immutable
class MatchMetadata {
  const MatchMetadata({
    required this.name,
    required this.opponentName,
    required this.deckId,
    required this.deckName,
    required this.opponentDeckId,
    required this.opponentDeckName,
    required this.format,
    required this.tag,
  });

  final String name;
  final String opponentName;
  final String deckId;
  final String deckName;
  final String opponentDeckId;
  final String opponentDeckName;
  final String format;
  final String tag;

  MatchMetadata copyWith({
    String? name,
    String? opponentName,
    String? deckId,
    String? deckName,
    String? opponentDeckId,
    String? opponentDeckName,
    String? format,
    String? tag,
  }) {
    return MatchMetadata(
      name: name ?? this.name,
      opponentName: opponentName ?? this.opponentName,
      deckId: deckId ?? this.deckId,
      deckName: deckName ?? this.deckName,
      opponentDeckId: opponentDeckId ?? this.opponentDeckId,
      opponentDeckName: opponentDeckName ?? this.opponentDeckName,
      format: format ?? this.format,
      tag: tag ?? this.tag,
    );
  }
}

@immutable
class MatchRecord {
  const MatchRecord({
    required this.id,
    required this.tcgKey,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
    required this.games,
    required this.aggregateResult,
  });

  final String id;
  final String tcgKey;
  final MatchMetadata metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<GameRecord> games;
  final MatchAggregateResult aggregateResult;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _premiumKey = 'premium_unlocked_v1';
  static const String _settingsKey = 'app_settings_v1';
  static const String _recordsKey = 'game_records_v1';
  static const String _sideboardDecksKey = 'sideboard_decks_v1';
  static const String _lastDeckByTcgKey = 'last_selected_deck_by_tcg_v1';

  bool _isLoading = true;
  bool _onboardingCompleted = true;
  bool _defaultGameSelected = true;
  bool _premiumUnlocked = false;
  AppSettings _settings = AppSettings.defaults();
  List<GameRecord> _gameRecords = <GameRecord>[];
  List<SideboardDeck> _sideboardDecks = <SideboardDeck>[];
  Map<String, String> _lastDeckByTcg = <String, String>{};
  SupportedTcg _selectedGame = SupportedTcg.yugioh;
  String _saveDebugStatus = 'idle';
  Future<void> _queuedCheckpointSave = Future<void>.value();

  String get _selectedTcgKey => _selectedGame.storageKey;
  bool get _isImplementedGame =>
      _selectedGame != SupportedTcg.riftbound &&
      _selectedGame != SupportedTcg.lorcana;

  List<GameRecord> _recordsForSelectedGame() {
    return _gameRecords
        .where((GameRecord record) => record.tcgKey == _selectedTcgKey)
        .toList(growable: false);
  }

  List<SideboardDeck> _decksForSelectedGame() {
    return _sideboardDecks
        .where((SideboardDeck deck) => deck.tcgKey == _selectedTcgKey)
        .toList(growable: false);
  }

  SideboardDeck? _findDeckByNameForSelectedGame(String rawName) {
    return _findUniqueDeckByName(_decksForSelectedGame(), rawName);
  }

  String _defaultDeckNameForSelectedGame() {
    final String stored = (_lastDeckByTcg[_selectedTcgKey] ?? '').trim();
    if (stored.isEmpty) {
      return '';
    }
    final SideboardDeck? linked = _findDeckByNameForSelectedGame(stored);
    return linked?.name ?? '';
  }

  int _nextTwoPlayerMatchNumberForTcg(String tcgKey) {
    final Set<String> uniqueMatchIds = <String>{};
    for (final GameRecord record in _gameRecords) {
      if (record.tcgKey != tcgKey || record.playerCount != 2) {
        continue;
      }
      final String matchId = record.matchId.trim().isNotEmpty
          ? record.matchId.trim()
          : 'legacy-${record.id}';
      uniqueMatchIds.add(matchId);
    }
    return uniqueMatchIds.length + 1;
  }

  String _defaultMatchNameFor({
    required SupportedTcg tcg,
    required int number,
  }) {
    final AppStrings txt = context.txt;
    final String prefix = tcg == SupportedTcg.mtg
        ? '${txt.t('tcg.mtg')} Match'
        : 'Match';
    return '$prefix $number';
  }

  String _gameRecordIdForPayload({
    required String tcgKey,
    required int playerCount,
    required DuelCompletedGamePayload payload,
    String? normalizedStage,
    String? normalizedMatchId,
  }) {
    final String resolvedStage = (normalizedStage ?? payload.gameStage)
        .trim()
        .toUpperCase();
    final String matchId = (normalizedMatchId ?? payload.matchId).trim();
    return [
      tcgKey,
      playerCount.toString(),
      payload.createdAt.toUtc().microsecondsSinceEpoch.toString(),
      matchId.isEmpty ? 'single' : matchId,
      resolvedStage.isEmpty ? 'G1' : resolvedStage,
    ].join('|');
  }

  List<GameRecord> _buildGameRecordsFromDuelResult({
    required SupportedTcg tcg,
    required String tcgKey,
    required String duelTitlePrefix,
    required DuelResultPayload duelResult,
    required List<SideboardDeck> availableDecks,
  }) {
    final List<DuelCompletedGamePayload> payloadGames =
        duelResult.completedGames.isNotEmpty
        ? List<DuelCompletedGamePayload>.from(duelResult.completedGames)
        : <DuelCompletedGamePayload>[
            DuelCompletedGamePayload(
              lifePointHistory: List<String>.from(duelResult.lifePointHistory),
              gameStage: duelResult.gameStage,
              opponentName: duelResult.opponentName,
              deckId: duelResult.deckId,
              deckName: duelResult.deckName,
              opponentDeckId: duelResult.opponentDeckId,
              opponentDeckName: duelResult.opponentDeckName,
              matchFormat: duelResult.matchFormat,
              matchTag: duelResult.matchTag,
              matchId: duelResult.matchId,
              matchName: duelResult.matchName,
              matchResult: duelResult.matchResult,
              createdAt: DateTime.now(),
            ),
          ];

    final int normalizedPlayerCount = duelResult.playerCount
        .clamp(2, 6)
        .toInt();
    final bool isTwoPlayerSession = normalizedPlayerCount == 2;
    String sessionMatchId = isTwoPlayerSession ? duelResult.matchId.trim() : '';
    if (isTwoPlayerSession && sessionMatchId.isEmpty) {
      sessionMatchId = 'match-${DateTime.now().microsecondsSinceEpoch}';
    }
    String sessionMatchName = isTwoPlayerSession
        ? duelResult.matchName.trim()
        : '';
    if (isTwoPlayerSession && sessionMatchName.isEmpty) {
      sessionMatchName = _defaultMatchNameFor(
        tcg: tcg,
        number: _nextTwoPlayerMatchNumberForTcg(tcgKey),
      );
    }

    int nextGeneratedMatchNumber = _nextTwoPlayerMatchNumberForTcg(tcgKey);
    final Map<String, String> generatedMatchNames = <String, String>{};
    final Map<String, GameRecord> existingById = <String, GameRecord>{
      for (final GameRecord record in _gameRecords) record.id: record,
    };
    final int scopedExistingCount = _gameRecords
        .where((GameRecord record) => record.tcgKey == tcgKey)
        .length;
    int nextGeneratedTitleIndex = scopedExistingCount + 1;
    final List<GameRecord> newRecords = <GameRecord>[];

    for (final DuelCompletedGamePayload payload in payloadGames) {
      final List<String> normalizedHistory = payload.lifePointHistory
          .map((String line) => line.trim())
          .where((String line) => line.isNotEmpty)
          .toList(growable: false);
      final String rawResult = payload.matchResult.trim();
      final String normalizedResult = _supportedMatchResults.contains(rawResult)
          ? rawResult
          : '';
      final String rawStage = payload.gameStage.trim().toUpperCase();
      final String normalizedStage = _supportedGameStages.contains(rawStage)
          ? rawStage
          : 'G1';
      if (normalizedHistory.isEmpty && normalizedResult.isEmpty) {
        continue;
      }

      final String rawDeckName = payload.deckName.trim();
      final String payloadDeckId = payload.deckId.trim();
      SideboardDeck? selectedDeck;
      if (payloadDeckId.isNotEmpty) {
        for (final SideboardDeck deck in availableDecks) {
          if (deck.id == payloadDeckId) {
            selectedDeck = deck;
            break;
          }
        }
      }
      selectedDeck ??= _findDeckByNameForSelectedGame(rawDeckName);
      final String resolvedDeckId = selectedDeck?.id ?? payloadDeckId;
      final String resolvedDeckName = selectedDeck?.name ?? rawDeckName;

      final String rawOpponentDeckName = payload.opponentDeckName.trim();
      final String payloadOpponentDeckId = payload.opponentDeckId.trim();
      SideboardDeck? selectedOpponentDeck;
      if (payloadOpponentDeckId.isNotEmpty) {
        for (final SideboardDeck deck in availableDecks) {
          if (deck.id == payloadOpponentDeckId) {
            selectedOpponentDeck = deck;
            break;
          }
        }
      }
      selectedOpponentDeck ??= _findDeckByNameForSelectedGame(
        rawOpponentDeckName,
      );
      final String resolvedOpponentDeckId =
          selectedOpponentDeck?.id ?? payloadOpponentDeckId;
      final String resolvedOpponentDeckName =
          selectedOpponentDeck?.name ?? rawOpponentDeckName;

      final String resolvedOpponentName = payload.opponentName.trim();
      final String resolvedMatchFormat = payload.matchFormat.trim().isNotEmpty
          ? payload.matchFormat.trim()
          : (selectedDeck?.format.trim() ?? '');
      final String resolvedMatchTag = payload.matchTag.trim();
      final DateTime createdAt = payload.createdAt;

      String resolvedMatchId = '';
      String resolvedMatchName = '';
      if (isTwoPlayerSession) {
        resolvedMatchId = payload.matchId.trim();
        if (resolvedMatchId.isEmpty) {
          resolvedMatchId = sessionMatchId;
        }
        if (resolvedMatchId.isEmpty) {
          resolvedMatchId = 'match-${createdAt.microsecondsSinceEpoch}';
        }
        resolvedMatchName = payload.matchName.trim();
        if (resolvedMatchName.isEmpty &&
            sessionMatchName.isNotEmpty &&
            (payload.matchId.trim().isEmpty ||
                payload.matchId.trim() == sessionMatchId)) {
          resolvedMatchName = sessionMatchName;
        }
        if (resolvedMatchName.isEmpty) {
          resolvedMatchName = generatedMatchNames.putIfAbsent(
            resolvedMatchId,
            () {
              final String generated = _defaultMatchNameFor(
                tcg: tcg,
                number: nextGeneratedMatchNumber,
              );
              nextGeneratedMatchNumber += 1;
              return generated;
            },
          );
        }
      }

      final String recordId = _gameRecordIdForPayload(
        tcgKey: tcgKey,
        playerCount: normalizedPlayerCount,
        payload: payload,
        normalizedStage: normalizedStage,
        normalizedMatchId: resolvedMatchId,
      );
      final GameRecord? existingRecord = existingById[recordId];
      final String title =
          existingRecord?.title ??
          '$duelTitlePrefix ${nextGeneratedTitleIndex++}';

      newRecords.add(
        GameRecord(
          id: recordId,
          title: title,
          createdAt: createdAt,
          gameStage: normalizedStage,
          notes: existingRecord?.notes ?? '',
          lifePointHistory: normalizedHistory,
          tcgKey: tcgKey,
          deckId: resolvedDeckId,
          matchResult: normalizedResult,
          opponentName: resolvedOpponentName,
          deckName: resolvedDeckName,
          playerOneName:
              existingRecord?.playerOneName ?? _settings.playerOneName,
          playerTwoName: resolvedOpponentName.isEmpty
              ? _settings.playerTwoName
              : resolvedOpponentName,
          playerCount: normalizedPlayerCount,
          matchId: resolvedMatchId,
          matchName: resolvedMatchName,
          matchFormat: resolvedMatchFormat,
          opponentDeckId: resolvedOpponentDeckId,
          opponentDeckName: resolvedOpponentDeckName,
          matchTag: resolvedMatchTag,
        ),
      );
    }

    return newRecords;
  }

  Future<int> _persistDuelResultRecords({
    required SupportedTcg tcg,
    required String tcgKey,
    required String duelTitlePrefix,
    required DuelResultPayload duelResult,
    required List<SideboardDeck> availableDecks,
    String debugPrefix = 'saved',
  }) async {
    final List<GameRecord> newRecords = _buildGameRecordsFromDuelResult(
      tcg: tcg,
      tcgKey: tcgKey,
      duelTitlePrefix: duelTitlePrefix,
      duelResult: duelResult,
      availableDecks: availableDecks,
    );

    if (newRecords.isEmpty) {
      setState(() {
        _saveDebugStatus = '$debugPrefix: no completed games to save';
      });
      await _persistState();
      return 0;
    }

    final Set<String> existingIds = _gameRecords
        .map((GameRecord record) => record.id)
        .toSet();
    final int insertedCount = newRecords
        .where((GameRecord record) => !existingIds.contains(record.id))
        .length;
    final int updatedCount = newRecords.length - insertedCount;

    final Map<String, GameRecord> mergedById = <String, GameRecord>{
      for (final GameRecord record in _gameRecords) record.id: record,
    };
    for (final GameRecord record in newRecords) {
      mergedById[record.id] = record;
    }

    final List<GameRecord> mergedRecords =
        mergedById.values.toList(growable: false)
          ..sort((GameRecord a, GameRecord b) {
            return b.createdAt.compareTo(a.createdAt);
          });

    setState(() {
      _gameRecords = mergedRecords;
      _saveDebugStatus =
          '$debugPrefix: +$insertedCount new, ~$updatedCount updated';
    });
    await _persistState();
    return insertedCount;
  }

  Map<String, String> _decodeLastDeckByTcg(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return <String, String>{};
    }
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return <String, String>{};
      }
      final Map<String, String> parsed = <String, String>{};
      for (final MapEntry<dynamic, dynamic> entry in decoded.entries) {
        final String key = entry.key is String ? entry.key as String : '';
        final String value = entry.value is String ? entry.value as String : '';
        final String normalizedKey = _normalizeTcgKey(
          key,
          fallback: SupportedTcg.yugioh.storageKey,
        );
        parsed[normalizedKey] = value.trim();
      }
      return parsed;
    } catch (_) {
      return <String, String>{};
    }
  }

  List<GameRecord> _mergeRecordsForGame(
    List<GameRecord> updatedRecords,
    String tcgKey,
  ) {
    final List<GameRecord> untouched = _gameRecords
        .where((GameRecord record) => record.tcgKey != tcgKey)
        .toList(growable: false);
    final List<GameRecord> updatedScoped = updatedRecords
        .map((GameRecord record) => record.copyWith(tcgKey: tcgKey))
        .toList(growable: false);
    final List<GameRecord> merged = <GameRecord>[
      ...untouched,
      ...updatedScoped,
    ];
    merged.sort((GameRecord a, GameRecord b) {
      return b.createdAt.compareTo(a.createdAt);
    });
    return merged;
  }

  List<SideboardDeck> _mergeDecksForGame(
    List<SideboardDeck> updatedDecks,
    String tcgKey,
  ) {
    final List<SideboardDeck> untouched = _sideboardDecks
        .where((SideboardDeck deck) => deck.tcgKey != tcgKey)
        .toList(growable: false);
    final List<SideboardDeck> updatedScoped = updatedDecks
        .map((SideboardDeck deck) => deck.copyWith(tcgKey: tcgKey))
        .toList(growable: false);
    return <SideboardDeck>[...untouched, ...updatedScoped];
  }

  List<SideboardDeck> _mergeDeckCollections({
    required List<SideboardDeck> existing,
    required List<SideboardDeck> incoming,
    required String tcgKey,
  }) {
    final List<SideboardDeck> merged = existing
        .map((SideboardDeck deck) => deck.copyWith(tcgKey: tcgKey))
        .toList(growable: true);
    final Set<String> ids = merged
        .map((SideboardDeck deck) => deck.id.trim())
        .where((String id) => id.isNotEmpty)
        .toSet();
    final Set<String> names = merged
        .map((SideboardDeck deck) => _normalizeDeckName(deck.name))
        .where((String name) => name.isNotEmpty)
        .toSet();
    for (final SideboardDeck deck in incoming) {
      final SideboardDeck normalized = deck.copyWith(tcgKey: tcgKey);
      final String id = normalized.id.trim();
      final String name = _normalizeDeckName(normalized.name);
      if (id.isNotEmpty && ids.contains(id)) {
        continue;
      }
      if (name.isNotEmpty && names.contains(name)) {
        continue;
      }
      if (id.isNotEmpty) {
        ids.add(id);
      }
      if (name.isNotEmpty) {
        names.add(name);
      }
      merged.add(normalized);
    }
    return merged.toList(growable: false);
  }

  List<SideboardDeck> _migrateDeckTcgUsingLinkedRecords(
    List<SideboardDeck> decks,
    List<GameRecord> records,
  ) {
    final Map<String, Set<String>> tcgByDeckId = <String, Set<String>>{};
    for (final GameRecord record in records) {
      final String deckId = record.deckId.trim();
      if (deckId.isEmpty) {
        continue;
      }
      tcgByDeckId.putIfAbsent(deckId, () => <String>{}).add(record.tcgKey);
    }

    return decks
        .map((SideboardDeck deck) {
          final Set<String>? linkedTcgs = tcgByDeckId[deck.id];
          if (linkedTcgs == null || linkedTcgs.length != 1) {
            return deck;
          }
          final String inferredTcg = linkedTcgs.first;
          if (inferredTcg == deck.tcgKey) {
            return deck;
          }
          return deck.copyWith(tcgKey: inferredTcg);
        })
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _loadStoredData();
  }

  Future<void> _loadStoredData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool premiumUnlocked = prefs.getBool(_premiumKey) ?? false;
    final bool onboardingCompleted =
        prefs.getBool(_onboardingCompletedKey) ?? false;
    final bool defaultGameSelected =
        prefs.getBool(_defaultGameSelectedKey) ?? false;
    final AppSettings settings = _decodeSettings(prefs.getString(_settingsKey));
    final List<GameRecord> records = _decodeRecords(
      prefs.getString(_recordsKey),
    );
    final List<SideboardDeck> sideboardDecks =
        _migrateDeckTcgUsingLinkedRecords(
          _decodeSideboardDecks(prefs.getString(_sideboardDecksKey)),
          records,
        );
    final Map<String, String> lastDeckByTcg = _decodeLastDeckByTcg(
      prefs.getString(_lastDeckByTcgKey),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _premiumUnlocked = premiumUnlocked;
      _onboardingCompleted = onboardingCompleted;
      _defaultGameSelected = defaultGameSelected;
      _settings = settings;
      _selectedGame = SupportedTcgX.fromStorageKey(settings.startupTcgKey);
      _gameRecords = records;
      _sideboardDecks = sideboardDecks;
      _lastDeckByTcg = lastDeckByTcg;
      _isLoading = false;
    });
    AppRuntimeConfig.language.value = AppLanguageX.fromStorageKey(
      settings.appLanguageKey,
    );
  }

  AppSettings _decodeSettings(String? rawSettings) {
    if (rawSettings == null || rawSettings.isEmpty) {
      return AppSettings.defaults();
    }

    try {
      final dynamic decoded = jsonDecode(rawSettings);
      if (decoded is Map) {
        return AppSettings.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      return AppSettings.defaults();
    }

    return AppSettings.defaults();
  }

  List<GameRecord> _decodeRecords(String? rawRecords) {
    if (rawRecords == null || rawRecords.isEmpty) {
      return <GameRecord>[];
    }

    try {
      final dynamic decoded = jsonDecode(rawRecords);
      if (decoded is! List<dynamic>) {
        return <GameRecord>[];
      }

      final List<GameRecord> parsed = <GameRecord>[];
      for (final dynamic entry in decoded) {
        if (entry is Map) {
          parsed.add(GameRecord.fromJson(Map<String, dynamic>.from(entry)));
        }
      }
      parsed.sort((GameRecord a, GameRecord b) {
        return b.createdAt.compareTo(a.createdAt);
      });
      return parsed;
    } catch (_) {
      return <GameRecord>[];
    }
  }

  List<SideboardDeck> _decodeSideboardDecks(String? rawDecks) {
    if (rawDecks == null || rawDecks.isEmpty) {
      return <SideboardDeck>[];
    }

    try {
      final dynamic decoded = jsonDecode(rawDecks);
      if (decoded is! List<dynamic>) {
        return <SideboardDeck>[];
      }

      final List<SideboardDeck> parsed = <SideboardDeck>[];
      for (final dynamic entry in decoded) {
        if (entry is Map) {
          parsed.add(SideboardDeck.fromJson(Map<String, dynamic>.from(entry)));
        }
      }
      return parsed;
    } catch (_) {
      return <SideboardDeck>[];
    }
  }

  Future<void> _persistState() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumKey, _premiumUnlocked);
    await prefs.setString(_settingsKey, jsonEncode(_settings.toJson()));
    await prefs.setString(
      _recordsKey,
      jsonEncode(
        _gameRecords
            .map((GameRecord record) => record.toJson())
            .toList(growable: false),
      ),
    );
    await prefs.setString(
      _sideboardDecksKey,
      jsonEncode(
        _sideboardDecks
            .map((SideboardDeck deck) => deck.toJson())
            .toList(growable: false),
      ),
    );
    await prefs.setString(_lastDeckByTcgKey, jsonEncode(_lastDeckByTcg));
  }

  Future<void> _completeOnboarding() async {
    setState(() {
      _onboardingCompleted = true;
    });
    await AppUxStateStore.setOnboardingCompleted(true);
  }

  Future<void> _completeGameSelection(SupportedTcg game) async {
    final AppSettings updated = _settings.copyWith(
      startupTcgKey: game.storageKey,
    );
    setState(() {
      _defaultGameSelected = true;
      _settings = updated;
      _selectedGame = game;
    });
    await _persistState();
    await AppUxStateStore.setDefaultGameSelected(true);
  }

  Future<bool> _ensurePremiumAccess({required String featureName}) async {
    if (_premiumUnlocked) {
      return true;
    }
    final AppStrings txt = context.txt;

    final bool? unlocked = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(txt.t('home.upgradeProTitle')),
          content: Text(
            txt.t(
              'home.upgradeProBody',
              params: <String, Object?>{'feature': featureName},
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(txt.t('common.notNow')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(txt.t('home.buyProDemo')),
            ),
          ],
        );
      },
    );

    if (unlocked != true) {
      return false;
    }

    setState(() {
      _premiumUnlocked = true;
    });
    await _persistState();
    return true;
  }

  Future<void> _startDuel() async {
    final AppStrings txt = context.txt;
    late final Widget duelScreen;
    String duelTitlePrefix = 'Duel';
    final SupportedTcg selectedGame = _selectedGame;
    final String selectedTcgKey = _selectedTcgKey;
    List<SideboardDeck> availableDecks = _decksForSelectedGame();
    final List<String> availableDeckNames = availableDecks
        .map((SideboardDeck deck) => deck.name)
        .toList(growable: false);
    final String defaultDeckName = _defaultDeckNameForSelectedGame();

    Future<void> mergeCreatedDecksFromPayload(DuelResultPayload payload) async {
      final List<SideboardDeck> newlyCreatedDecks = payload.createdDecks
          .where(
            (SideboardDeck deck) =>
                deck.name.trim().isNotEmpty && deck.tcgKey == selectedTcgKey,
          )
          .toList(growable: false);
      if (newlyCreatedDecks.isEmpty) {
        return;
      }
      availableDecks = _mergeDeckCollections(
        existing: availableDecks,
        incoming: newlyCreatedDecks,
        tcgKey: selectedTcgKey,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _sideboardDecks = _mergeDecksForGame(availableDecks, selectedTcgKey);
      });
    }

    Future<void> persistCheckpoint(DuelResultPayload payload) async {
      _queuedCheckpointSave = _queuedCheckpointSave.then((_) async {
        final String latestDeckName = payload.deckName.trim();
        if (latestDeckName.isNotEmpty && mounted) {
          setState(() {
            _lastDeckByTcg[selectedTcgKey] = latestDeckName;
          });
        }
        await mergeCreatedDecksFromPayload(payload);
        if (!payload.shouldSave || payload.completedGames.isEmpty) {
          await _persistState();
          return;
        }
        await _persistDuelResultRecords(
          tcg: selectedGame,
          tcgKey: selectedTcgKey,
          duelTitlePrefix: duelTitlePrefix,
          duelResult: payload,
          availableDecks: availableDecks,
          debugPrefix: 'checkpoint',
        );
      });
      await _queuedCheckpointSave;
    }

    if (selectedGame == SupportedTcg.yugioh) {
      duelScreen = DuelScreen(
        settings: _settings,
        availableDeckNames: availableDeckNames,
        availableDecks: availableDecks,
        initialDeckName: defaultDeckName,
        onCheckpoint: persistCheckpoint,
      );
    } else if (selectedGame == SupportedTcg.mtg) {
      final MtgDuelSetupResult? setupResult = await Navigator.of(context)
          .push<MtgDuelSetupResult>(
            MaterialPageRoute<MtgDuelSetupResult>(
              builder: (_) => MtgDuelSetupScreen(settings: _settings),
            ),
          );
      if (setupResult == null || !mounted) {
        return;
      }

      duelScreen = MtgDuelScreen(
        settings: _settings,
        playerCount: setupResult.playerCount,
        initialLifePoints: setupResult.initialLifePoints,
        layoutMode: setupResult.layoutMode,
        availableDeckNames: availableDeckNames,
        availableDecks: availableDecks,
        initialDeckName: defaultDeckName,
        onCheckpoint: persistCheckpoint,
      );
      duelTitlePrefix = 'MTG Game';
    } else {
      return;
    }

    if (!mounted) {
      return;
    }

    final DuelResultPayload? duelResult = await Navigator.of(context)
        .push<DuelResultPayload>(
          MaterialPageRoute<DuelResultPayload>(builder: (_) => duelScreen),
        );

    await _queuedCheckpointSave;

    if (!mounted) return;

    final String latestDeckName = duelResult?.deckName.trim() ?? '';
    if (duelResult != null) {
      setState(() {
        _lastDeckByTcg[selectedTcgKey] = latestDeckName;
      });
    }

    if (duelResult == null) {
      setState(() {
        _saveDebugStatus = 'duelResult=null -> nothing to save';
      });
      await _persistState();
      return;
    }

    await mergeCreatedDecksFromPayload(duelResult);

    if (!duelResult.shouldSave) {
      setState(() {
        _saveDebugStatus = 'current game discarded; confirmed games kept';
      });
      await _persistState();
      return;
    }

    final int insertedCount = await _persistDuelResultRecords(
      tcg: selectedGame,
      tcgKey: selectedTcgKey,
      duelTitlePrefix: duelTitlePrefix,
      duelResult: duelResult,
      availableDecks: availableDecks,
      debugPrefix: 'final save',
    );

    if (mounted && insertedCount > 0) {
      final int savedCount = _recordsForSelectedGame().length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            txt.t(
              'home.savedGamesToast',
              params: <String, Object?>{
                'count': insertedCount,
                'total': savedCount,
              },
            ),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _openGameHistory() async {
    final AppStrings txt = context.txt;
    final bool allowed = await _ensurePremiumAccess(
      featureName: txt.t('home.gameHistory'),
    );
    if (!allowed || !mounted) {
      return;
    }

    final String tcgKey = _selectedTcgKey;
    final List<GameRecord> scopedRecords = _recordsForSelectedGame();
    final List<SideboardDeck> scopedDecks = _decksForSelectedGame();

    final List<GameRecord>? updatedRecords = await Navigator.of(context)
        .push<List<GameRecord>>(
          MaterialPageRoute<List<GameRecord>>(
            builder: (_) => GameHistoryScreen(
              records: scopedRecords,
              decks: scopedDecks,
              tcg: _selectedGame,
            ),
          ),
        );

    if (updatedRecords == null) {
      return;
    }

    setState(() {
      _gameRecords = _mergeRecordsForGame(updatedRecords, tcgKey);
    });
    await _persistState();
  }

  Future<void> _openCustomize() async {
    final AppStrings txt = context.txt;
    final bool allowed = await _ensurePremiumAccess(
      featureName: txt.t('home.customizeApp'),
    );
    if (!allowed || !mounted) {
      return;
    }

    final AppSettings? updatedSettings = await Navigator.of(context)
        .push<AppSettings>(
          MaterialPageRoute<AppSettings>(
            builder: (_) => CustomizeScreen(initialSettings: _settings),
          ),
        );

    if (updatedSettings == null) {
      return;
    }

    setState(() {
      _settings = updatedSettings;
      _selectedGame = SupportedTcgX.fromStorageKey(
        updatedSettings.startupTcgKey,
      );
    });
    AppRuntimeConfig.language.value = AppLanguageX.fromStorageKey(
      updatedSettings.appLanguageKey,
    );
    await _persistState();
  }

  Future<void> _openSideboardBook() async {
    final AppStrings txt = context.txt;
    final bool allowed = await _ensurePremiumAccess(
      featureName: txt.t('home.decksUtility'),
    );
    if (!allowed || !mounted) {
      return;
    }

    final String tcgKey = _selectedTcgKey;
    final List<SideboardDeck> scopedDecks = _decksForSelectedGame();
    final List<GameRecord> scopedRecords = _recordsForSelectedGame();

    final SideboardBookResult? result = await Navigator.of(context)
        .push<SideboardBookResult>(
          MaterialPageRoute<SideboardBookResult>(
            builder: (_) => SideboardDeckListScreen(
              decks: scopedDecks,
              records: scopedRecords,
              settings: _settings,
              tcg: _selectedGame,
            ),
          ),
        );

    if (result == null) {
      return;
    }

    setState(() {
      _sideboardDecks = _mergeDecksForGame(result.decks, tcgKey);
      _gameRecords = _mergeRecordsForGame(result.records, tcgKey);
    });
    await _persistState();
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings txt = context.txt;
    final AppSettings activeSettings = _settings;
    final int savedMatchesForGame = _recordsForSelectedGame().length;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              _selectedGame.homePresetColors.bgStart,
              _selectedGame.homePresetColors.bgEnd,
            ],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : !_defaultGameSelected
              ? _GameSelectionScreen(onCompleted: _completeGameSelection)
              : !_onboardingCompleted
              ? _AppOnboardingScreen(onCompleted: _completeOnboarding)
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(),
                      Text(
                        txt.t('app.title'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_appBuildTag • $_saveDebugStatus',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<SupportedTcg>(
                            value: _selectedGame,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF241C1C),
                            style: const TextStyle(color: Colors.white),
                            iconEnabledColor: Colors.white,
                            items: _supportedTcgAlphabeticalOrder
                                .map(
                                  (SupportedTcg game) =>
                                      DropdownMenuItem<SupportedTcg>(
                                        value: game,
                                        child: Text(
                                          txt.t('tcg.${game.storageKey}'),
                                        ),
                                      ),
                                )
                                .toList(growable: false),
                            onChanged: (SupportedTcg? value) {
                              if (value == null || value == _selectedGame) {
                                return;
                              }
                              setState(() {
                                _selectedGame = value;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_isImplementedGame) ...[
                        const Spacer(),
                        _ModeButton(
                          icon: Icons.splitscreen,
                          title: txt.t('home.letsDuel'),
                          subtitle: txt.t('home.topBottomPlayers'),
                          backgroundColor: activeSettings.buttonColor,
                          onPressed: _startDuel,
                        ),
                        const SizedBox(height: 12),
                        _ModeButton(
                          icon: Icons.history_rounded,
                          title: txt.t('home.gameHistory'),
                          subtitle: _premiumUnlocked
                              ? txt.t(
                                  'home.savedMatches',
                                  params: <String, Object?>{
                                    'count': savedMatchesForGame,
                                  },
                                )
                              : txt.t(
                                  'home.premiumSaved',
                                  params: <String, Object?>{
                                    'count': savedMatchesForGame,
                                  },
                                ),
                          backgroundColor: activeSettings.buttonColor,
                          onPressed: _openGameHistory,
                          locked: !_premiumUnlocked,
                        ),
                        const SizedBox(height: 12),
                        _ModeButton(
                          icon: Icons.menu_book_rounded,
                          title: txt.t('home.decksUtility'),
                          subtitle: _premiumUnlocked
                              ? txt.t('home.decksUtilitySubtitle')
                              : txt.t('common.premium'),
                          backgroundColor: activeSettings.buttonColor,
                          onPressed: _openSideboardBook,
                          locked: !_premiumUnlocked,
                        ),
                        const SizedBox(height: 12),
                        _ModeButton(
                          icon: Icons.tune_rounded,
                          title: txt.t('home.customizeApp'),
                          subtitle: _premiumUnlocked
                              ? txt.t('home.namesAndColors')
                              : txt.t('common.premium'),
                          backgroundColor: activeSettings.buttonColor,
                          onPressed: _openCustomize,
                          locked: !_premiumUnlocked,
                        ),
                        const Spacer(),
                      ] else ...[
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            txt.t('home.comingSoon'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Spacer(),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _AppOnboardingScreen extends StatefulWidget {
  const _AppOnboardingScreen({required this.onCompleted});

  final Future<void> Function() onCompleted;

  @override
  State<_AppOnboardingScreen> createState() => _AppOnboardingScreenState();
}

class _AppOnboardingScreenState extends State<_AppOnboardingScreen> {
  final PageController _pageController = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await widget.onCompleted();
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings txt = context.txt;
    final List<({IconData icon, String title, String body})> pages =
        <({IconData icon, String title, String body})>[
          (
            icon: Icons.history_rounded,
            title: txt.t('onboarding.title1'),
            body: txt.t('onboarding.body1'),
          ),
          (
            icon: Icons.style_rounded,
            title: txt.t('onboarding.title2'),
            body: txt.t('onboarding.body2'),
          ),
          (
            icon: Icons.query_stats_rounded,
            title: txt.t('onboarding.title3'),
            body: txt.t('onboarding.body3'),
          ),
        ];
    final bool isLast = _index == pages.length - 1;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _finish,
              child: Text(txt.t('common.skip')),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: pages.length,
              onPageChanged: (int value) {
                setState(() {
                  _index = value;
                });
              },
              itemBuilder: (BuildContext context, int index) {
                final page = pages[index];
                return Card(
                  color: const Color(0xFF1E1B1B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(page.icon, size: 52),
                        const SizedBox(height: 18),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          page.body,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.84),
                            height: 1.35,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List<Widget>.generate(pages.length, (int i) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 8,
                width: _index == i ? 22 : 8,
                decoration: BoxDecoration(
                  color: _index == i
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(99),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () async {
              if (isLast) {
                await _finish();
                return;
              }
              await _pageController.nextPage(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
              );
            },
            child: Text(txt.t(isLast ? 'common.continue' : 'common.next')),
          ),
        ],
      ),
    );
  }
}

class _GameSelectionScreen extends StatelessWidget {
  const _GameSelectionScreen({required this.onCompleted});

  final Future<void> Function(SupportedTcg) onCompleted;

  @override
  Widget build(BuildContext context) {
    final AppStrings txt = context.txt;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            txt.t('onboarding.chooseGame'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 32),
          _GameSelectionCard(
            icon: Icons.flash_on_rounded,
            label: txt.t('tcg.yugioh'),
            onTap: () => onCompleted(SupportedTcg.yugioh),
          ),
          const SizedBox(height: 16),
          _GameSelectionCard(
            icon: Icons.style_rounded,
            label: txt.t('tcg.mtg'),
            onTap: () => onCompleted(SupportedTcg.mtg),
          ),
          const SizedBox(height: 32),
          Text(
            txt.t('onboarding.chooseGameHint'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _GameSelectionCard extends StatelessWidget {
  const _GameSelectionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1E1B1B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 32),
              const SizedBox(width: 16),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.backgroundColor,
    required this.onPressed,
    this.locked = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color backgroundColor;
  final VoidCallback onPressed;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (locked) ...[
                const Icon(Icons.workspace_premium_outlined, size: 18),
                const SizedBox(width: 8),
              ],
              const Icon(Icons.arrow_forward_ios_rounded, size: 18),
            ],
          ),
        ],
      ),
    );
  }
}

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

typedef _MtgLayoutRowSpec = ({List<int?> slots, int flex});

MtgDuelLayoutMode _effectiveMtgLayoutMode({
  required int playerCount,
  required MtgDuelLayoutMode layoutMode,
}) {
  return playerCount == 2 ? MtgDuelLayoutMode.tableMode : layoutMode;
}

int _mtgQuarterTurnsForPlayer({
  required int playerCount,
  required MtgDuelLayoutMode layoutMode,
  required int playerIndex,
}) {
  final MtgDuelLayoutMode effectiveMode = _effectiveMtgLayoutMode(
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

List<_MtgLayoutRowSpec> _mtgLayoutRows({
  required int playerCount,
  required MtgDuelLayoutMode layoutMode,
}) {
  final MtgDuelLayoutMode effectiveMode = _effectiveMtgLayoutMode(
    playerCount: playerCount,
    layoutMode: layoutMode,
  );

  if (effectiveMode == MtgDuelLayoutMode.standard) {
    switch (playerCount) {
      case 3:
        return <_MtgLayoutRowSpec>[
          (slots: <int?>[1, 2], flex: 48),
          (slots: <int?>[null, 0, null], flex: 52),
        ];
      case 4:
        return <_MtgLayoutRowSpec>[
          (slots: <int?>[1, 3], flex: 50),
          (slots: <int?>[0, 2], flex: 50),
        ];
      case 5:
        return <_MtgLayoutRowSpec>[
          (slots: <int?>[2, null, 4], flex: 33),
          (slots: <int?>[1, null, 3], flex: 33),
          (slots: <int?>[0, null, null], flex: 34),
        ];
      case 6:
        return <_MtgLayoutRowSpec>[
          (slots: <int?>[2, null, 5], flex: 33),
          (slots: <int?>[1, null, 4], flex: 33),
          (slots: <int?>[0, null, 3], flex: 34),
        ];
      case 2:
      default:
        return <_MtgLayoutRowSpec>[
          (slots: <int?>[1], flex: 50),
          (slots: <int?>[0], flex: 50),
        ];
    }
  }

  switch (playerCount) {
    case 3:
      return <_MtgLayoutRowSpec>[
        (slots: <int?>[1, 2], flex: 60),
        (slots: <int?>[0], flex: 40),
      ];
    case 4:
      return <_MtgLayoutRowSpec>[
        (slots: <int?>[2], flex: 26),
        (slots: <int?>[1, null, 3], flex: 48),
        (slots: <int?>[0], flex: 26),
      ];
    case 5:
      return <_MtgLayoutRowSpec>[
        (slots: <int?>[null, 3, null], flex: 18),
        (slots: <int?>[1, null, 4], flex: 22),
        (slots: <int?>[2, null, null], flex: 21),
        (slots: <int?>[null, 0, null], flex: 21),
      ];
    case 6:
      return <_MtgLayoutRowSpec>[
        (slots: <int?>[null, 3, null], flex: 22),
        (slots: <int?>[1, null, 4], flex: 28),
        (slots: <int?>[2, null, 5], flex: 28),
        (slots: <int?>[null, 0, null], flex: 22),
      ];
    case 2:
    default:
      return <_MtgLayoutRowSpec>[
        (slots: <int?>[1], flex: 50),
        (slots: <int?>[0], flex: 50),
      ];
  }
}

List<int> _slotFlexesForSlots(List<int?> slots) {
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
    return _mtgQuarterTurnsForPlayer(
      playerCount: _playerCount,
      layoutMode: _effectiveLayoutMode,
      playerIndex: playerIndex,
    );
  }

  List<_MtgLayoutRowSpec> _previewRows() {
    return _mtgLayoutRows(
      playerCount: _playerCount,
      layoutMode: _effectiveLayoutMode,
    );
  }

  Widget _buildPreviewRow(List<int?> slots) {
    final List<int> slotFlexes = _slotFlexesForSlots(slots);
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

    final List<_MtgLayoutRowSpec> rows = _previewRows();
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
          for (final _MtgLayoutRowSpec row in rows)
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

enum _MtgResourceCounter { white, blue, black, red, green, colorless, storm }

extension _MtgResourceCounterX on _MtgResourceCounter {
  String get label {
    switch (this) {
      case _MtgResourceCounter.white:
        return 'White mana';
      case _MtgResourceCounter.blue:
        return 'Blue mana';
      case _MtgResourceCounter.black:
        return 'Black mana';
      case _MtgResourceCounter.red:
        return 'Red mana';
      case _MtgResourceCounter.green:
        return 'Green mana';
      case _MtgResourceCounter.colorless:
        return 'Colorless mana';
      case _MtgResourceCounter.storm:
        return 'Storm count';
    }
  }

  Color get accentColor {
    switch (this) {
      case _MtgResourceCounter.white:
        return const Color(0xFFF3F1E8);
      case _MtgResourceCounter.blue:
        return const Color(0xFF4C81D9);
      case _MtgResourceCounter.black:
        return const Color(0xFF232323);
      case _MtgResourceCounter.red:
        return const Color(0xFFD94C4C);
      case _MtgResourceCounter.green:
        return const Color(0xFF3FA55A);
      case _MtgResourceCounter.colorless:
        return const Color(0xFF9B9B9B);
      case _MtgResourceCounter.storm:
        return const Color(0xFFE6A23C);
    }
  }
}

enum _MtgStatusCounter { poison, experience }

extension _MtgStatusCounterX on _MtgStatusCounter {
  String get label {
    switch (this) {
      case _MtgStatusCounter.poison:
        return 'Poison counters (\u03A6)';
      case _MtgStatusCounter.experience:
        return 'Experience counters';
    }
  }
}

class MtgDuelScreen extends StatefulWidget {
  const MtgDuelScreen({
    super.key,
    required this.settings,
    required this.playerCount,
    required this.initialLifePoints,
    required this.layoutMode,
    this.availableDeckNames = const <String>[],
    this.availableDecks = const <SideboardDeck>[],
    this.initialDeckName = '',
    this.onCheckpoint,
  });

  final AppSettings settings;
  final int playerCount;
  final int initialLifePoints;
  final MtgDuelLayoutMode layoutMode;
  final List<String> availableDeckNames;
  final List<SideboardDeck> availableDecks;
  final String initialDeckName;
  final DuelCheckpointCallback? onCheckpoint;

  @override
  State<MtgDuelScreen> createState() => _MtgDuelScreenState();
}

class _MtgDuelScreenState extends State<MtgDuelScreen> {
  static const Duration _aggregationWindow = Duration(seconds: 2);

  final Random _random = Random();

  late final List<int> _lifePoints;
  late final List<int> _pendingDeltas;
  late final List<Timer?> _pendingTimers;
  late final List<int?> _diceValues;
  late final List<Map<_MtgResourceCounter, int>> _resourceCounters;
  late final List<Map<_MtgStatusCounter, int>> _statusCounters;
  late final List<List<int>> _commanderDamageReceived;

  bool _isRollingDice = false;
  Timer? _diceRollTimer;
  Timer? _diceResultTimer;
  int _diceRollTicks = 0;
  bool _showDiceResults = false;

  late final List<String> _historyEntries;
  late final List<TwoPlayerLifeEvent> _twoPlayerLifeEvents;
  late final List<String> _playerNames;
  late List<Color> _playerCardBackgroundColors;

  String _opponentName = '';
  String _opponentDeckInUse = '';
  String _selectedOpponentDeckId = '';
  String _matchFormat = '';
  String _matchTag = '';
  String _matchName = '';
  String _selectedGameStage = 'G1';
  String _deckInUse = '';
  String _selectedDeckId = '';
  int _bo3Wins = 0;
  int _bo3Losses = 0;
  String _lastCompletedOpponentName = '';
  String _lastRecordedOpponentName = '';
  final List<DuelCompletedGamePayload> _completedGamesForSession =
      <DuelCompletedGamePayload>[];
  final List<SideboardDeck> _createdDecksForSession = <SideboardDeck>[];
  late List<SideboardDeck> _sessionAvailableDecks;
  late String _currentMatchId;

  bool get _isMultiplayer => widget.playerCount >= 3;

  MtgDuelLayoutMode get _effectiveLayoutMode => _effectiveMtgLayoutMode(
    playerCount: widget.playerCount,
    layoutMode: widget.layoutMode,
  );

  bool get _isTableMode => _effectiveLayoutMode == MtgDuelLayoutMode.tableMode;

  int _quarterTurnsForPlayer(int playerIndex) {
    return _mtgQuarterTurnsForPlayer(
      playerCount: widget.playerCount,
      layoutMode: _effectiveLayoutMode,
      playerIndex: playerIndex,
    );
  }

  Offset _beginOffsetForQuarterTurns(int quarterTurns) {
    switch (quarterTurns % 4) {
      case 1:
        return const Offset(-1, 0);
      case 2:
        return const Offset(0, -1);
      case 3:
        return const Offset(1, 0);
      default:
        return const Offset(0, 1);
    }
  }

  Alignment _alignmentForQuarterTurns(int quarterTurns) {
    switch (quarterTurns % 4) {
      case 1:
        return Alignment.centerLeft;
      case 2:
        return Alignment.topCenter;
      case 3:
        return Alignment.centerRight;
      default:
        return Alignment.bottomCenter;
    }
  }

  String _playerName(int playerIndex) {
    if (widget.playerCount == 2 && playerIndex == 1) {
      final String opponent = _opponentName.trim();
      if (opponent.isNotEmpty) {
        return opponent;
      }
    }
    return _playerNames[playerIndex];
  }

  String _defaultPlayerName(int playerIndex) {
    if (playerIndex == 0) {
      final String name = widget.settings.playerOneName.trim();
      return name.isEmpty ? 'Player 1' : name;
    }
    if (playerIndex == 1) {
      final String name = widget.settings.playerTwoName.trim();
      return name.isEmpty ? 'Player 2' : name;
    }
    return 'Player ${playerIndex + 1}';
  }

  String _sanitizePlayerName(String value, int playerIndex) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return _defaultPlayerName(playerIndex);
    }
    return trimmed;
  }

  Color _playerCardBackgroundColor(int playerIndex) {
    if (playerIndex < 0 || playerIndex >= _playerCardBackgroundColors.length) {
      return widget.settings.lifePointsBackgroundColor;
    }
    return _playerCardBackgroundColors[playerIndex];
  }

  Future<Color?> _promptPlayerCardColor({
    required String title,
    required Color selectedColor,
  }) async {
    return showDialog<Color>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final Color color in _appColorPalette)
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(color),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selectedColor == color
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.2),
                        width: selectedColor == color ? 2.4 : 1,
                      ),
                    ),
                    child: selectedColor == color
                        ? const Icon(Icons.check, size: 18, color: Colors.white)
                        : null,
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.txt.t('common.cancel')),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(
                context,
              ).pop(widget.settings.lifePointsBackgroundColor),
              child: const Text('Default'),
            ),
          ],
        );
      },
    );
  }

  String _resolveInitialDeckName() {
    final String normalizedInitial = widget.initialDeckName
        .trim()
        .toLowerCase();
    if (normalizedInitial.isEmpty) {
      return '';
    }
    for (final String raw in widget.availableDeckNames) {
      final String trimmed = raw.trim();
      if (trimmed.toLowerCase() == normalizedInitial) {
        return trimmed;
      }
    }
    for (final SideboardDeck deck in _sessionAvailableDecks) {
      final String trimmed = deck.name.trim();
      if (trimmed.toLowerCase() == normalizedInitial) {
        return trimmed;
      }
    }
    return '';
  }

  SideboardDeck? _deckById(String deckId) {
    final String trimmedId = deckId.trim();
    if (trimmedId.isEmpty) {
      return null;
    }
    for (final SideboardDeck deck in _sessionAvailableDecks) {
      if (deck.id == trimmedId) {
        return deck;
      }
    }
    return null;
  }

  SideboardDeck? _deckByName(String deckName) {
    return _findUniqueDeckByName(_sessionAvailableDecks, deckName);
  }

  SideboardDeck? _selectedDeckForGuide() {
    return _deckById(_selectedDeckId) ?? _deckByName(_deckInUse);
  }

  String _selectedDeckIdForHistory() {
    return _selectedDeckForGuide()?.id ?? '';
  }

  String _deckIdByName(String deckName) {
    return _deckByName(deckName)?.id ?? '';
  }

  String _selectedOpponentDeckIdForHistory() {
    return _deckById(_selectedOpponentDeckId)?.id ??
        _deckIdByName(_opponentDeckInUse);
  }

  bool _hasConfiguredSideboard(SideboardMatchup matchup) {
    bool hasNamedCards(List<SideboardCardEntry> entries) {
      for (final SideboardCardEntry entry in entries) {
        if (entry.name.trim().isNotEmpty) {
          return true;
        }
      }
      return false;
    }

    return hasNamedCards(matchup.sideIn) || hasNamedCards(matchup.sideOut);
  }

  List<SideboardMatchup> _configuredMatchupsForGuide(SideboardDeck deck) {
    return deck.matchups.where(_hasConfiguredSideboard).toList(growable: false);
  }

  String _formatSideboardEntries(List<SideboardCardEntry> entries) {
    if (entries.isEmpty) {
      return '-';
    }
    return entries
        .map((SideboardCardEntry entry) {
          final String name = entry.name.trim().isEmpty
              ? 'Unnamed card'
              : entry.name.trim();
          final int copies = entry.copies.clamp(1, 99).toInt();
          return '$copies x $name';
        })
        .join(', ');
  }

  Future<void> _openSideboardGuideDialog() async {
    if (widget.playerCount != 2) {
      return;
    }
    final AppStrings txt = context.txt;
    final SideboardDeck? deck = _selectedDeckForGuide();
    if (deck == null) {
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(txt.t('sideboardGuide.dialogTitle')),
            content: Text(txt.t('sideboardGuide.noDeckSelected')),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(txt.t('common.close')),
              ),
            ],
          );
        },
      );
      return;
    }
    await showInfoTipOnce(
      context: context,
      tipId: InfoTipIds.sideboardGuide,
      titleKey: 'info.sideboardGuide.title',
      bodyKey: 'info.sideboardGuide.body',
      icon: Icons.menu_book_rounded,
    );
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        final List<SideboardMatchup> configuredMatchups =
            _configuredMatchupsForGuide(deck);
        final bool hasMatchups = configuredMatchups.isNotEmpty;
        return AlertDialog(
          title: Text('${deck.name} - ${txt.t('sideboardGuide.dialogTitle')}'),
          content: SizedBox(
            width: double.maxFinite,
            child: hasMatchups
                ? SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (
                          int index = 0;
                          index < configuredMatchups.length;
                          index += 1
                        ) ...[
                          if (index > 0) const SizedBox(height: 12),
                          Text(
                            configuredMatchups[index].name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${txt.t('sideboardGuide.sideIn')}: ${_formatSideboardEntries(configuredMatchups[index].sideIn)}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${txt.t('sideboardGuide.sideOut')}: ${_formatSideboardEntries(configuredMatchups[index].sideOut)}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : Text(txt.t('sideboardGuide.noPlansForDeck')),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(txt.t('common.close')),
            ),
          ],
        );
      },
    );
  }

  void _registerCurrentGameResultForBo3() {
    if (widget.playerCount != 2) {
      return;
    }
    if (_lifePoints[0] == _lifePoints[1]) {
      return;
    }
    if (_lifePoints[0] > _lifePoints[1]) {
      _bo3Wins += 1;
    } else {
      _bo3Losses += 1;
    }
  }

  void _registerDeclaredGameResultForBo3(String result) {
    if (widget.playerCount != 2) {
      return;
    }
    if (result == 'Win') {
      _bo3Wins += 1;
      return;
    }
    if (result == 'Loss') {
      _bo3Losses += 1;
    }
  }

  void _advanceBo3AfterRestart({String? declaredResult}) {
    if (widget.playerCount != 2) {
      return;
    }

    final String currentStage = _selectedGameStage;
    if (!_supportedGameStages.contains(currentStage)) {
      _selectedGameStage = 'G1';
      _bo3Wins = 0;
      _bo3Losses = 0;
      return;
    }

    final String explicitResult = (declaredResult ?? '').trim();
    if (explicitResult.isEmpty) {
      _registerCurrentGameResultForBo3();
    } else {
      _registerDeclaredGameResultForBo3(explicitResult);
    }

    String nextStage = 'G1';
    if (currentStage == 'G1') {
      nextStage = 'G2';
    } else if (currentStage == 'G2') {
      final bool matchClosed = _bo3Wins >= 2 || _bo3Losses >= 2;
      nextStage = matchClosed ? 'G1' : 'G3';
    } else {
      nextStage = 'G1';
    }

    _selectedGameStage = nextStage;
    if (nextStage == 'G1') {
      final String completedOpponent = _opponentName.trim();
      if (completedOpponent.isNotEmpty) {
        _lastCompletedOpponentName = completedOpponent;
      }
      _bo3Wins = 0;
      _bo3Losses = 0;
      _opponentName = '';
      _opponentDeckInUse = '';
      _selectedOpponentDeckId = '';
      _matchFormat = '';
      _matchTag = '';
      _matchName = '';
      _currentMatchId = 'match-${DateTime.now().microsecondsSinceEpoch}';
    }
  }

  String _resolvedOpponentForHistory() {
    final String trimmedOpponent = _opponentName.trim();
    if (trimmedOpponent.isNotEmpty) {
      return trimmedOpponent;
    }
    final String rememberedOpponent = _lastRecordedOpponentName.trim();
    if (rememberedOpponent.isNotEmpty) {
      return rememberedOpponent;
    }
    return _lastCompletedOpponentName.trim();
  }

  bool _hasActiveGameProgress() {
    for (int index = 0; index < widget.playerCount; index += 1) {
      if (_lifePoints[index] != widget.initialLifePoints) {
        return true;
      }
      if (_pendingDeltas[index] != 0) {
        return true;
      }
      for (final _MtgResourceCounter counter in _MtgResourceCounter.values) {
        if ((_resourceCounters[index][counter] ?? 0) != 0) {
          return true;
        }
      }
      for (final _MtgStatusCounter counter in _MtgStatusCounter.values) {
        if ((_statusCounters[index][counter] ?? 0) != 0) {
          return true;
        }
      }
      for (
        int sourceIndex = 0;
        sourceIndex < widget.playerCount;
        sourceIndex += 1
      ) {
        if (_commanderDamageReceived[index][sourceIndex] != 0) {
          return true;
        }
      }
    }
    if (widget.playerCount == 2) {
      return _twoPlayerLifeEvents.isNotEmpty;
    }
    return _historyEntries.length > widget.playerCount;
  }

  DuelCompletedGamePayload _buildCompletedGamePayload({
    required String matchResult,
  }) {
    final String rawStage = _selectedGameStage.trim().toUpperCase();
    final String normalizedStage = _supportedGameStages.contains(rawStage)
        ? rawStage
        : 'G1';
    final String rawResult = matchResult.trim();
    final String normalizedResult = _supportedMatchResults.contains(rawResult)
        ? rawResult
        : '';
    return DuelCompletedGamePayload(
      lifePointHistory: _historySnapshotWithPending(),
      gameStage: normalizedStage,
      opponentName: _resolvedOpponentForHistory(),
      deckId: _selectedDeckIdForHistory(),
      deckName: _deckInUse.trim(),
      opponentDeckId: _selectedOpponentDeckIdForHistory(),
      opponentDeckName: _opponentDeckInUse.trim(),
      matchFormat: _matchFormat.trim(),
      matchTag: _matchTag.trim(),
      matchId: widget.playerCount == 2 ? _currentMatchId : '',
      matchName: _matchName.trim(),
      matchResult: normalizedResult,
      createdAt: DateTime.now(),
    );
  }

  @override
  void initState() {
    super.initState();
    unawaited(WakelockPlus.enable());
    _sessionAvailableDecks = List<SideboardDeck>.from(widget.availableDecks);
    _deckInUse = _resolveInitialDeckName();
    _selectedDeckId = _selectedDeckForGuide()?.id ?? '';
    _matchFormat = _selectedDeckForGuide()?.format.trim() ?? '';
    _currentMatchId = 'match-${DateTime.now().microsecondsSinceEpoch}';
    _playerNames = List<String>.generate(
      widget.playerCount,
      (int index) => _defaultPlayerName(index),
    );
    _playerCardBackgroundColors = List<Color>.filled(
      widget.playerCount,
      widget.settings.lifePointsBackgroundColor,
    );
    _lifePoints = List<int>.filled(
      widget.playerCount,
      widget.initialLifePoints,
    );
    _pendingDeltas = List<int>.filled(widget.playerCount, 0);
    _pendingTimers = List<Timer?>.filled(widget.playerCount, null);
    _diceValues = List<int?>.filled(widget.playerCount, null);
    _resourceCounters = List<Map<_MtgResourceCounter, int>>.generate(
      widget.playerCount,
      (_) => <_MtgResourceCounter, int>{
        for (final _MtgResourceCounter counter in _MtgResourceCounter.values)
          counter: 0,
      },
    );
    _statusCounters = List<Map<_MtgStatusCounter, int>>.generate(
      widget.playerCount,
      (_) => <_MtgStatusCounter, int>{
        for (final _MtgStatusCounter counter in _MtgStatusCounter.values)
          counter: 0,
      },
    );
    _commanderDamageReceived = List<List<int>>.generate(
      widget.playerCount,
      (_) => List<int>.filled(widget.playerCount, 0),
    );
    _historyEntries = List<String>.generate(
      widget.playerCount,
      (int index) => '${_playerName(index)}: ${widget.initialLifePoints}',
    );
    _twoPlayerLifeEvents = <TwoPlayerLifeEvent>[];
  }

  String _formatSigned(int value) {
    return value > 0 ? '+$value' : '$value';
  }

  ({
    Alignment alignment,
    Offset beginOffset,
    int quarterTurns,
    double widthFactor,
    double heightFactor,
  })
  _placementForPlayer(int playerIndex) {
    final int quarterTurns = _quarterTurnsForPlayer(playerIndex);
    final bool longSide = quarterTurns == 1 || quarterTurns == 3;
    return (
      alignment: _alignmentForQuarterTurns(quarterTurns),
      beginOffset: _beginOffsetForQuarterTurns(quarterTurns),
      quarterTurns: quarterTurns,
      widthFactor: longSide ? 0.72 : 0.96,
      heightFactor: longSide ? 0.94 : 0.58,
    );
  }

  void _cancelPendingTimer(int playerIndex) {
    _pendingTimers[playerIndex]?.cancel();
    _pendingTimers[playerIndex] = null;
  }

  void _startPendingTimer(int playerIndex) {
    _cancelPendingTimer(playerIndex);
    _pendingTimers[playerIndex] = Timer(_aggregationWindow, () {
      _commitPendingDelta(playerIndex);
    });
  }

  void _commitPendingDelta(int playerIndex) {
    if (!mounted) {
      return;
    }
    final int pending = _pendingDeltas[playerIndex];
    if (pending == 0) {
      return;
    }
    final int currentLp = _lifePoints[playerIndex];
    setState(() {
      if (widget.playerCount == 2 && playerIndex < 2) {
        _twoPlayerLifeEvents.add(
          TwoPlayerLifeEvent(
            player: playerIndex + 1,
            delta: pending,
            resultingLife: currentLp,
          ),
        );
      }
      _historyEntries.add(
        '${_playerName(playerIndex)}: ${_formatSigned(pending)} = $currentLp',
      );
      _pendingDeltas[playerIndex] = 0;
    });
  }

  void _applySignedDelta({required int playerIndex, required int delta}) {
    final int currentLp = _lifePoints[playerIndex];
    final int nextLp = max(0, currentLp + delta);
    final int effectiveDelta = nextLp - currentLp;
    if (effectiveDelta == 0) {
      return;
    }

    setState(() {
      _lifePoints[playerIndex] = nextLp;
      _pendingDeltas[playerIndex] += effectiveDelta;
    });
    _startPendingTimer(playerIndex);
  }

  List<String> _historySnapshotWithPending() {
    if (widget.playerCount == 2) {
      final List<TwoPlayerLifeEvent> events = List<TwoPlayerLifeEvent>.from(
        _twoPlayerLifeEvents,
      );
      for (int index = 0; index < 2; index += 1) {
        final int pending = _pendingDeltas[index];
        if (pending == 0) {
          continue;
        }
        events.add(
          TwoPlayerLifeEvent(
            player: index + 1,
            delta: pending,
            resultingLife: _lifePoints[index],
          ),
        );
      }
      return _buildTwoPlayerHistoryTable(
        playerOneName: _playerName(0),
        playerTwoName: _playerName(1),
        initialPlayerOneLife: widget.initialLifePoints,
        initialPlayerTwoLife: widget.initialLifePoints,
        events: events,
      );
    }

    final List<String> snapshot = List<String>.from(_historyEntries);
    for (int index = 0; index < widget.playerCount; index += 1) {
      final int pending = _pendingDeltas[index];
      if (pending == 0) {
        continue;
      }
      snapshot.add(
        '${_playerName(index)}: ${_formatSigned(pending)} = ${_lifePoints[index]}',
      );
    }
    return snapshot;
  }

  void _closeWithHistory({String matchResult = '', bool shouldSave = true}) {
    _diceRollTimer?.cancel();
    _diceResultTimer?.cancel();
    for (int index = 0; index < widget.playerCount; index += 1) {
      _cancelPendingTimer(index);
    }
    Navigator.of(context).pop(
      _buildDuelResultPayload(matchResult: matchResult, shouldSave: shouldSave),
    );
  }

  DuelResultPayload _buildDuelResultPayload({
    String matchResult = '',
    bool shouldSave = true,
    bool includeCurrentGameIfNeeded = true,
  }) {
    final String explicitMatchResult = matchResult.trim();
    final DuelCompletedGamePayload currentSnapshot = _buildCompletedGamePayload(
      matchResult: explicitMatchResult,
    );
    List<DuelCompletedGamePayload> gamesToSave =
        const <DuelCompletedGamePayload>[];
    if (shouldSave) {
      gamesToSave = List<DuelCompletedGamePayload>.from(
        _completedGamesForSession,
      );
      final bool includeCurrentGame =
          includeCurrentGameIfNeeded &&
          (explicitMatchResult.isNotEmpty || _hasActiveGameProgress());
      if (includeCurrentGame) {
        gamesToSave.add(currentSnapshot);
      }
    }
    final DuelCompletedGamePayload payloadSource = gamesToSave.isNotEmpty
        ? gamesToSave.last
        : currentSnapshot;
    return DuelResultPayload(
      lifePointHistory: List<String>.from(payloadSource.lifePointHistory),
      gameStage: payloadSource.gameStage,
      opponentName: payloadSource.opponentName,
      deckId: payloadSource.deckId,
      deckName: payloadSource.deckName,
      opponentDeckId: payloadSource.opponentDeckId,
      opponentDeckName: payloadSource.opponentDeckName,
      matchFormat: payloadSource.matchFormat,
      matchTag: payloadSource.matchTag,
      matchResult: payloadSource.matchResult,
      playerCount: widget.playerCount,
      shouldSave: shouldSave && gamesToSave.isNotEmpty,
      completedGames: gamesToSave,
      createdDecks: List<SideboardDeck>.from(_createdDecksForSession),
      matchId: widget.playerCount == 2 ? _currentMatchId : '',
      matchName: _matchName.trim(),
    );
  }

  Future<void> _openHistoryForPlayer(int playerIndex) async {
    final List<String> historySnapshot = _historySnapshotWithPending();
    final placement = _placementForPlayer(playerIndex);

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close history',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (BuildContext context, _, _) {
        return SafeArea(
          child: RotatedBox(
            quarterTurns: placement.quarterTurns,
            child: Material(
              color: const Color(0xFF141414),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'LP History',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.08,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF101010),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: _buildLifeHistoryView(
                          lines: historySnapshot,
                          playerCount: widget.playerCount,
                          dividerColor: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> _,
            Widget child,
          ) {
            final Animation<Offset> offsetAnimation =
                Tween<Offset>(
                  begin: placement.beginOffset,
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                );

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: offsetAnimation, child: child),
            );
          },
    );
  }

  Map<_MtgResourceCounter, int> _resourceCountersForPlayer(int playerIndex) {
    return _resourceCounters[playerIndex];
  }

  Map<_MtgStatusCounter, int> _statusCountersForPlayer(int playerIndex) {
    return _statusCounters[playerIndex];
  }

  int _poisonCountersForPlayer(int playerIndex) {
    return _statusCountersForPlayer(playerIndex)[_MtgStatusCounter.poison] ?? 0;
  }

  int _experienceCountersForPlayer(int playerIndex) {
    return _statusCountersForPlayer(
          playerIndex,
        )[_MtgStatusCounter.experience] ??
        0;
  }

  int _commanderDamageFromPlayer({
    required int receiverIndex,
    required int sourceIndex,
  }) {
    return _commanderDamageReceived[receiverIndex][sourceIndex];
  }

  int _commanderDamageTotalForPlayer(int playerIndex) {
    final List<int> values = _commanderDamageReceived[playerIndex];
    int total = 0;
    for (int index = 0; index < values.length; index += 1) {
      if (index == playerIndex) {
        continue;
      }
      total += values[index];
    }
    return total;
  }

  void _changeCommanderDamage({
    required int receiverIndex,
    required int sourceIndex,
    required int delta,
  }) {
    if (receiverIndex == sourceIndex) {
      return;
    }

    final int current = _commanderDamageFromPlayer(
      receiverIndex: receiverIndex,
      sourceIndex: sourceIndex,
    );
    final int next = max(0, current + delta);
    final int effective = next - current;
    if (effective == 0) {
      return;
    }

    setState(() {
      _commanderDamageReceived[receiverIndex][sourceIndex] = next;
    });
    _applySignedDelta(playerIndex: receiverIndex, delta: -effective);
  }

  void _changeMtgResourceCounter({
    required int playerIndex,
    required _MtgResourceCounter counter,
    required int delta,
  }) {
    final Map<_MtgResourceCounter, int> counters = _resourceCountersForPlayer(
      playerIndex,
    );
    final int current = counters[counter] ?? 0;
    final int next = max(0, current + delta);
    if (next == current) {
      return;
    }
    setState(() {
      counters[counter] = next;
    });
  }

  void _changeMtgStatusCounter({
    required int playerIndex,
    required _MtgStatusCounter counter,
    required int delta,
  }) {
    final Map<_MtgStatusCounter, int> counters = _statusCountersForPlayer(
      playerIndex,
    );
    final int current = counters[counter] ?? 0;
    final int next = max(0, current + delta);
    if (next == current) {
      return;
    }
    setState(() {
      counters[counter] = next;
    });
  }

  Future<void> _openMtgCountersPanel({
    required int playerIndex,
    required String title,
    required Widget Function(StateSetter setModalState) contentBuilder,
  }) async {
    final placement = _placementForPlayer(playerIndex);

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close counters',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (BuildContext context, _, _) {
        return SafeArea(
          child: RotatedBox(
            quarterTurns: placement.quarterTurns,
            child: Material(
              color: const Color(0xFF141414),
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setModalState) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close_rounded),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.08,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(child: contentBuilder(setModalState)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
      transitionBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> _,
            Widget child,
          ) {
            final Animation<Offset> offsetAnimation =
                Tween<Offset>(
                  begin: placement.beginOffset,
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                );

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: offsetAnimation, child: child),
            );
          },
    );
  }

  Widget _buildMtgCounterRow({
    required Widget label,
    required int value,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
    bool compact = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: compact ? 6 : 8),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Expanded(child: label),
          IconButton(
            onPressed: onDecrement,
            icon: const Icon(Icons.remove_rounded),
            style: IconButton.styleFrom(
              minimumSize: Size.square(compact ? 30 : 32),
              backgroundColor: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 32,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: compact ? 15 : 16,
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: onIncrement,
            icon: const Icon(Icons.add_rounded),
            style: IconButton.styleFrom(
              minimumSize: Size.square(compact ? 30 : 32),
              backgroundColor: Colors.white.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMtgResourceCountersForPlayer(int playerIndex) async {
    await _openMtgCountersPanel(
      playerIndex: playerIndex,
      title: '${_playerName(playerIndex)} - Mana & Storm',
      contentBuilder: (StateSetter setModalState) {
        final Map<_MtgResourceCounter, int> counters =
            _resourceCountersForPlayer(playerIndex);
        return Column(
          children: [
            for (final _MtgResourceCounter counter
                in _MtgResourceCounter.values)
              Expanded(
                child: _buildMtgCounterRow(
                  compact: true,
                  label: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: counter.accentColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          counter.label,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  value: counters[counter] ?? 0,
                  onDecrement: () {
                    _changeMtgResourceCounter(
                      playerIndex: playerIndex,
                      counter: counter,
                      delta: -1,
                    );
                    setModalState(() {});
                  },
                  onIncrement: () {
                    _changeMtgResourceCounter(
                      playerIndex: playerIndex,
                      counter: counter,
                      delta: 1,
                    );
                    setModalState(() {});
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _openMtgStatusCountersForPlayer(int playerIndex) async {
    await _openMtgCountersPanel(
      playerIndex: playerIndex,
      title: '${_playerName(playerIndex)} - Poison & Experience',
      contentBuilder: (StateSetter setModalState) {
        final Map<_MtgStatusCounter, int> counters = _statusCountersForPlayer(
          playerIndex,
        );
        return Column(
          children: [
            for (final _MtgStatusCounter counter in _MtgStatusCounter.values)
              _buildMtgCounterRow(
                label: Row(
                  children: [
                    if (counter == _MtgStatusCounter.poison) ...[
                      Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1D5F2A),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          '\u03A6',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        counter.label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                value: counters[counter] ?? 0,
                onDecrement: () {
                  _changeMtgStatusCounter(
                    playerIndex: playerIndex,
                    counter: counter,
                    delta: -1,
                  );
                  setModalState(() {});
                },
                onIncrement: () {
                  _changeMtgStatusCounter(
                    playerIndex: playerIndex,
                    counter: counter,
                    delta: 1,
                  );
                  setModalState(() {});
                },
              ),
            const Spacer(),
          ],
        );
      },
    );
  }

  Future<void> _openCommanderDamageForPlayer(int playerIndex) async {
    await _openMtgCountersPanel(
      playerIndex: playerIndex,
      title: '${_playerName(playerIndex)} - Commander Damage',
      contentBuilder: (StateSetter setModalState) {
        final List<int> opponents = List<int>.generate(
          widget.playerCount,
          (int index) => index,
        ).where((int index) => index != playerIndex).toList(growable: false);

        if (opponents.isEmpty) {
          return const Center(
            child: Text(
              'No opponents in this match.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          );
        }

        return ListView(
          children: [
            for (final int sourceIndex in opponents)
              _buildMtgCounterRow(
                label: Row(
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      size: 18,
                      color: const Color(0xFFFF7A7A),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'From ${_playerName(sourceIndex)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                value: _commanderDamageFromPlayer(
                  receiverIndex: playerIndex,
                  sourceIndex: sourceIndex,
                ),
                onDecrement: () {
                  _changeCommanderDamage(
                    receiverIndex: playerIndex,
                    sourceIndex: sourceIndex,
                    delta: -1,
                  );
                  setModalState(() {});
                },
                onIncrement: () {
                  _changeCommanderDamage(
                    receiverIndex: playerIndex,
                    sourceIndex: sourceIndex,
                    delta: 1,
                  );
                  setModalState(() {});
                },
              ),
          ],
        );
      },
    );
  }

  Future<void> _openMatchDetailsEditor() async {
    if (!_isMultiplayer) {
      await showInfoTipOnce(
        context: context,
        tipId: InfoTipIds.opponentDeckSelection,
        titleKey: 'info.opponentDeck.title',
        bodyKey: 'info.opponentDeck.body',
        icon: Icons.arrow_drop_down_circle_outlined,
      );
      if (!mounted) {
        return;
      }
    }
    final TextEditingController matchNameController = TextEditingController(
      text: _matchName,
    );
    final TextEditingController opponentController = TextEditingController(
      text: _opponentName,
    );
    final TextEditingController tagController = TextEditingController(
      text: _matchTag,
    );
    final List<TextEditingController> playerNameControllers =
        List<TextEditingController>.generate(
          widget.playerCount,
          (int index) => TextEditingController(text: _playerName(index)),
        );
    final List<Color> selectedPlayerCardColors = List<Color>.from(
      _playerCardBackgroundColors,
    );
    String stage = _selectedGameStage;
    String selectedDeckId = _selectedDeckIdForHistory();
    if (selectedDeckId.isEmpty && _deckInUse.trim().isNotEmpty) {
      selectedDeckId = _deckByName(_deckInUse)?.id ?? '';
    }
    if (selectedDeckId.isNotEmpty && _deckById(selectedDeckId) == null) {
      selectedDeckId = '';
    }
    String selectedFormat = _matchFormat.trim();
    String selectedOpponentDeckId = _selectedOpponentDeckIdForHistory();

    Future<String?> promptText({
      required String title,
      required String initialValue,
      required String hintText,
    }) async {
      return showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          return _TextPromptDialog(
            title: title,
            initialValue: initialValue,
            hintText: hintText,
            maxLines: 1,
          );
        },
      );
    }

    List<SideboardDeck> deckOptions() {
      return _filterDecksByFormat(_sessionAvailableDecks, selectedFormat);
    }

    List<String> formatOptions() {
      final Set<String> unique = <String>{};
      for (final SideboardDeck deck in _sessionAvailableDecks) {
        final String format = deck.format.trim();
        if (format.isEmpty) {
          continue;
        }
        unique.add(format);
      }
      if (selectedFormat.isNotEmpty) {
        unique.add(selectedFormat);
      }
      final List<String> options = unique.toList(growable: false);
      options.sort((String a, String b) {
        return a.toLowerCase().compareTo(b.toLowerCase());
      });
      return options;
    }

    List<SideboardDeck> opponentDeckOptions() {
      return _filterDecksByFormat(_sessionAvailableDecks, selectedFormat);
    }

    void normalizeSelectedDeck() {
      if (selectedDeckId.isEmpty) {
        return;
      }
      final SideboardDeck? selectedDeck = _deckById(selectedDeckId);
      if (selectedDeck == null ||
          !_deckMatchesFormat(selectedDeck, selectedFormat)) {
        selectedDeckId = '';
      }
    }

    void normalizeSelectedOpponentDeck() {
      if (selectedOpponentDeckId.isEmpty) {
        return;
      }
      final SideboardDeck? selectedOpponentDeck = _deckById(
        selectedOpponentDeckId,
      );
      if (selectedOpponentDeck == null) {
        selectedOpponentDeckId = '';
        return;
      }
      if (!_deckMatchesFormat(selectedOpponentDeck, selectedFormat)) {
        selectedOpponentDeckId = '';
      }
    }

    if (selectedOpponentDeckId.isEmpty &&
        _opponentDeckInUse.trim().isNotEmpty) {
      selectedOpponentDeckId = _deckByName(_opponentDeckInUse)?.id ?? '';
    }
    normalizeSelectedDeck();
    normalizeSelectedOpponentDeck();

    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(context.txt.t(_isMultiplayer ? 'dialog.gameDetails' : 'dialog.matchDetails')),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              Future<void> pickPlayerColor(int playerIndex) async {
                final Color? picked = await _promptPlayerCardColor(
                  title: 'Player ${playerIndex + 1} card color',
                  selectedColor: selectedPlayerCardColors[playerIndex],
                );
                if (picked == null || !mounted) {
                  return;
                }
                setDialogState(() {
                  selectedPlayerCardColors[playerIndex] = picked;
                });
              }

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isMultiplayer) ...[
                      TextField(
                        controller: matchNameController,
                        decoration: InputDecoration(
                          labelText: context.txt.t('field.matchName'),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: opponentController,
                        decoration: InputDecoration(
                          labelText: context.txt.t('field.opponentName'),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: selectedFormat,
                        decoration: InputDecoration(
                          labelText: context.txt.t('field.format'),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: <DropdownMenuItem<String>>[
                          DropdownMenuItem<String>(
                            value: '',
                            child: Text(context.txt.t('field.noFormat')),
                          ),
                          ...formatOptions().map((String format) {
                            return DropdownMenuItem<String>(
                              value: format,
                              child: Text(format),
                            );
                          }),
                          DropdownMenuItem<String>(
                            value: '__add_format__',
                            child: Text(context.txt.t('field.addNewFormat')),
                          ),
                        ],
                        onChanged: (String? value) async {
                          if (value == null) {
                            return;
                          }
                          if (value == '__add_format__') {
                            final String? created = await promptText(
                              title: 'New format',
                              initialValue: '',
                              hintText: 'Modern, Edison, Commander...',
                            );
                            if (created == null) {
                              return;
                            }
                            final String trimmed = created.trim();
                            if (trimmed.isEmpty) {
                              return;
                            }
                            setDialogState(() {
                              selectedFormat = trimmed;
                              normalizeSelectedDeck();
                              normalizeSelectedOpponentDeck();
                            });
                            return;
                          }
                          setDialogState(() {
                            selectedFormat = value.trim();
                            normalizeSelectedDeck();
                            normalizeSelectedOpponentDeck();
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: selectedOpponentDeckId,
                        decoration: InputDecoration(
                          labelText: context.txt.t('field.opponentDeck'),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: <DropdownMenuItem<String>>[
                          DropdownMenuItem<String>(
                            value: '',
                            child: Text(context.txt.t('field.noOpponentDeck')),
                          ),
                          ...opponentDeckOptions().map((SideboardDeck deck) {
                            return DropdownMenuItem<String>(
                              value: deck.id,
                              child: Text(
                                deck.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                          DropdownMenuItem<String>(
                            value: '__add_opponent_deck__',
                            child: Text(context.txt.t('field.addNewDeck')),
                          ),
                        ],
                        onChanged: (String? value) async {
                          if (value == null) {
                            return;
                          }
                          if (value == '__add_opponent_deck__') {
                            final String? createdName = await promptText(
                              title: 'New opponent deck',
                              initialValue: '',
                              hintText: 'Deck name',
                            );
                            if (createdName == null) {
                              return;
                            }
                            final String trimmedName = createdName.trim();
                            if (trimmedName.isEmpty) {
                              return;
                            }
                            final SideboardDeck? existing = _deckByName(
                              trimmedName,
                            );
                            if (existing != null) {
                              setDialogState(() {
                                selectedOpponentDeckId = existing.id;
                                normalizeSelectedOpponentDeck();
                              });
                              return;
                            }
                            final SideboardDeck newDeck = SideboardDeck(
                              id: DateTime.now().microsecondsSinceEpoch
                                  .toString(),
                              name: trimmedName,
                              createdAt: DateTime.now(),
                              isFavorite: false,
                              userNotes: '',
                              matchups: const <SideboardMatchup>[],
                              format: selectedFormat.trim(),
                              tag: '',
                              tcgKey: SupportedTcg.mtg.storageKey,
                            );
                            setDialogState(() {
                              _sessionAvailableDecks = <SideboardDeck>[
                                newDeck,
                                ..._sessionAvailableDecks,
                              ];
                              _createdDecksForSession.add(newDeck);
                              selectedOpponentDeckId = newDeck.id;
                              normalizeSelectedOpponentDeck();
                            });
                            return;
                          }
                          setDialogState(() {
                            selectedOpponentDeckId = value.trim();
                            normalizeSelectedOpponentDeck();
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: tagController,
                        decoration: const InputDecoration(
                          labelText: 'Tag',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (!_isMultiplayer) ...[
                      DropdownButtonFormField<String>(
                        initialValue: stage,
                        decoration: const InputDecoration(
                          labelText: 'Game',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: _supportedGameStages
                            .map((String item) {
                              return DropdownMenuItem<String>(
                                value: item,
                                child: Text(item),
                              );
                            })
                            .toList(growable: false),
                        onChanged: (String? value) {
                          if (value == null) {
                            return;
                          }
                          setDialogState(() {
                            stage = value;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                    DropdownButtonFormField<String>(
                      initialValue: selectedDeckId,
                      decoration: InputDecoration(
                        labelText: context.txt.t('field.deckInUse'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(
                          value: '',
                          child: Text(context.txt.t('field.noDeck')),
                        ),
                        ...deckOptions().map((SideboardDeck deck) {
                          return DropdownMenuItem<String>(
                            value: deck.id,
                            child: Text(deck.name),
                          );
                        }),
                      ],
                      onChanged: (String? value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() {
                          selectedDeckId = value.trim();
                          if (selectedDeckId.isEmpty) {
                            return;
                          }
                          final SideboardDeck? linkedDeck = _deckById(
                            selectedDeckId,
                          );
                          if (linkedDeck != null &&
                              selectedFormat.trim().isEmpty &&
                              linkedDeck.format.trim().isNotEmpty) {
                            selectedFormat = linkedDeck.format.trim();
                          }
                          normalizeSelectedDeck();
                          normalizeSelectedOpponentDeck();
                        });
                      },
                    ),
                    if (_isMultiplayer) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          context.txt.t('game.playerNames'),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (
                        int playerIndex = 0;
                        playerIndex < widget.playerCount;
                        playerIndex += 1
                      ) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: playerNameControllers[playerIndex],
                                decoration: InputDecoration(
                                  labelText: context.txt.t('game.playerName', params: <String, Object?>{'n': playerIndex + 1}),
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 76,
                              child: Tooltip(
                                message:
                                    'Change Player ${playerIndex + 1} card color',
                                child: FilledButton.tonal(
                                  onPressed: () => pickPlayerColor(playerIndex),
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(76, 48),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 6,
                                    ),
                                    backgroundColor:
                                        selectedPlayerCardColors[playerIndex],
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(
                                        color: Colors.white.withValues(
                                          alpha: 0.24,
                                        ),
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.palette_outlined, size: 18),
                                      const SizedBox(height: 2),
                                      Text(
                                        context.txt.t('game.color'),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (playerIndex != widget.playerCount - 1)
                          const SizedBox(height: 8),
                      ],
                    ],
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.txt.t('common.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.txt.t('common.save')),
            ),
          ],
        );
      },
    );

    if (shouldSave != true) {
      _disposeTextControllersLater(<TextEditingController>[
        matchNameController,
        opponentController,
        tagController,
        ...playerNameControllers,
      ]);
      return;
    }

    if (!mounted) {
      _disposeTextControllersLater(<TextEditingController>[
        matchNameController,
        opponentController,
        tagController,
        ...playerNameControllers,
      ]);
      return;
    }

    setState(() {
      _matchName = matchNameController.text.trim();
      _opponentName = opponentController.text.trim();
      _matchFormat = selectedFormat.trim();
      final SideboardDeck? selectedDeckObject = _deckById(selectedDeckId);
      final SideboardDeck? selectedOpponentDeck = _deckById(
        selectedOpponentDeckId,
      );
      _selectedOpponentDeckId = selectedOpponentDeck?.id ?? '';
      _opponentDeckInUse = selectedOpponentDeck?.name ?? '';
      _matchTag = tagController.text.trim();
      if (_opponentName.isNotEmpty) {
        _lastCompletedOpponentName = _opponentName;
        _lastRecordedOpponentName = _opponentName;
      }
      _selectedDeckId = selectedDeckObject?.id ?? '';
      _deckInUse = selectedDeckObject?.name ?? '';
      if (!_isMultiplayer) {
        _selectedGameStage = stage;
      }
      if (widget.playerCount == 2 && stage == 'G1') {
        _bo3Wins = 0;
        _bo3Losses = 0;
      }
      if (_isMultiplayer) {
        for (
          int playerIndex = 0;
          playerIndex < widget.playerCount;
          playerIndex += 1
        ) {
          _playerNames[playerIndex] = _sanitizePlayerName(
            playerNameControllers[playerIndex].text,
            playerIndex,
          );
        }
        _playerCardBackgroundColors = List<Color>.from(
          selectedPlayerCardColors,
        );
      }
    });
    _disposeTextControllersLater(<TextEditingController>[
      matchNameController,
      opponentController,
      tagController,
      ...playerNameControllers,
    ]);
  }

  void _rollDice() {
    if (_isRollingDice) {
      return;
    }
    const int totalTicks = 12;
    const Duration tickDuration = Duration(milliseconds: 85);
    _diceRollTimer?.cancel();
    _diceResultTimer?.cancel();
    _diceResultTimer = null;
    setState(() {
      _isRollingDice = true;
      _diceRollTicks = 0;
      _showDiceResults = true;
      for (int index = 0; index < widget.playerCount; index += 1) {
        _diceValues[index] = _nextDieValue(_random);
      }
    });

    _diceRollTimer = Timer.periodic(tickDuration, (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      bool shouldStop = false;
      setState(() {
        for (int index = 0; index < widget.playerCount; index += 1) {
          _diceValues[index] = _nextDieValue(_random);
        }
        _diceRollTicks += 1;
        if (_diceRollTicks >= totalTicks) {
          _isRollingDice = false;
          shouldStop = true;
        }
      });
      if (shouldStop) {
        timer.cancel();
        _diceRollTimer = null;
        _scheduleDiceResultDismissal();
      }
    });
  }

  void _scheduleDiceResultDismissal() {
    _diceResultTimer?.cancel();
    _diceResultTimer = Timer(_diceResultVisibilityDuration, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _showDiceResults = false;
        for (int index = 0; index < widget.playerCount; index += 1) {
          _diceValues[index] = null;
        }
      });
      _diceResultTimer = null;
    });
  }

  Future<void> _confirmReset({bool fromHome = false}) async {
    const Color resetColor = Color(0xFF232323);
    const Color saveExitColor = Color(0xFF244A67);
    const Color winColor = Color(0xFF163825);
    const Color lossColor = Color(0xFF4A1E1E);
    const Color drawColor = Color(0xFF4D4220);
    final String? action = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            widget.playerCount == 2
                ? context.txt.t('game.endOrResetMatch')
                : context.txt.t('game.endOrResetGame'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (fromHome) ...[
                FilledButton.tonal(
                  onPressed: () => Navigator.of(context).pop('save_exit'),
                  style: FilledButton.styleFrom(backgroundColor: saveExitColor),
                  child: Text(context.txt.t('game.saveAndExit')),
                ),
                const SizedBox(height: 8),
              ],
              if (widget.playerCount == 2) ...[
                FilledButton.tonal(
                  onPressed: () => Navigator.of(context).pop('sideboard'),
                  style: FilledButton.styleFrom(
                    backgroundColor: widget.settings.buttonColor,
                  ),
                  child: Text(context.txt.t('game.sideboardGuide')),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton.tonal(
                onPressed: () => Navigator.of(context).pop('reset'),
                style: FilledButton.styleFrom(backgroundColor: resetColor),
                child: Text(
                  fromHome
                      ? (_completedGamesForSession.isNotEmpty
                            ? context.txt.t('game.discardAndExit')
                            : context.txt.t('game.exitWithoutSaving'))
                      : context.txt.t('game.resetWithoutSaving'),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.of(context).pop('Win'),
                style: FilledButton.styleFrom(backgroundColor: winColor),
                child: Text(context.txt.t('game.win')),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.of(context).pop('Loss'),
                style: FilledButton.styleFrom(backgroundColor: lossColor),
                child: Text(context.txt.t('game.loss')),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.of(context).pop('Draw'),
                style: FilledButton.styleFrom(backgroundColor: drawColor),
                child: Text(context.txt.t('game.draw')),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.txt.t('common.cancel')),
            ),
          ],
        );
      },
    );
    if (action == null || !mounted) {
      return;
    }
    if (action == 'sideboard' && widget.playerCount == 2) {
      await _openSideboardGuideDialog();
      return;
    }
    if (action == 'save_exit') {
      _closeWithHistory();
      return;
    }
    if (action == 'Win' || action == 'Loss' || action == 'Draw') {
      if (widget.playerCount != 2) {
        _closeWithHistory(matchResult: action);
        return;
      }

      _diceRollTimer?.cancel();
      _diceRollTimer = null;
      _diceResultTimer?.cancel();
      _diceResultTimer = null;
      for (int index = 0; index < widget.playerCount; index += 1) {
        _cancelPendingTimer(index);
      }
      setState(() {
        _completedGamesForSession.add(
          _buildCompletedGamePayload(matchResult: action),
        );
        final String completedOpponent = _opponentName.trim();
        if (completedOpponent.isNotEmpty) {
          _lastCompletedOpponentName = completedOpponent;
          _lastRecordedOpponentName = completedOpponent;
        }
        _advanceBo3AfterRestart(declaredResult: action);
        for (int index = 0; index < widget.playerCount; index += 1) {
          _lifePoints[index] = widget.initialLifePoints;
          _pendingDeltas[index] = 0;
          _diceValues[index] = null;
          for (final _MtgResourceCounter counter
              in _MtgResourceCounter.values) {
            _resourceCounters[index][counter] = 0;
          }
          for (final _MtgStatusCounter counter in _MtgStatusCounter.values) {
            _statusCounters[index][counter] = 0;
          }
          for (
            int sourceIndex = 0;
            sourceIndex < widget.playerCount;
            sourceIndex += 1
          ) {
            _commanderDamageReceived[index][sourceIndex] = 0;
          }
        }
        _isRollingDice = false;
        _diceRollTicks = 0;
        _showDiceResults = false;
        _twoPlayerLifeEvents.clear();
        _historyEntries
          ..clear()
          ..addAll(
            List<String>.generate(
              widget.playerCount,
              (int index) =>
                  '${_playerName(index)}: ${widget.initialLifePoints}',
            ),
          );
      });
      final DuelResultPayload checkpointPayload = _buildDuelResultPayload(
        shouldSave: true,
        includeCurrentGameIfNeeded: false,
      );
      if (widget.onCheckpoint != null) {
        await widget.onCheckpoint!(checkpointPayload);
      }
      return;
    }
    if (action != 'reset') {
      return;
    }
    if (fromHome) {
      _closeWithHistory(shouldSave: false);
      return;
    }

    _diceRollTimer?.cancel();
    _diceRollTimer = null;
    _diceResultTimer?.cancel();
    _diceResultTimer = null;
    for (int index = 0; index < widget.playerCount; index += 1) {
      _cancelPendingTimer(index);
    }
    setState(() {
      _lastRecordedOpponentName = '';
      _advanceBo3AfterRestart();
      for (int index = 0; index < widget.playerCount; index += 1) {
        _lifePoints[index] = widget.initialLifePoints;
        _pendingDeltas[index] = 0;
        _diceValues[index] = null;
        for (final _MtgResourceCounter counter in _MtgResourceCounter.values) {
          _resourceCounters[index][counter] = 0;
        }
        for (final _MtgStatusCounter counter in _MtgStatusCounter.values) {
          _statusCounters[index][counter] = 0;
        }
        for (
          int sourceIndex = 0;
          sourceIndex < widget.playerCount;
          sourceIndex += 1
        ) {
          _commanderDamageReceived[index][sourceIndex] = 0;
        }
      }
      _isRollingDice = false;
      _diceRollTicks = 0;
      _showDiceResults = false;
      _twoPlayerLifeEvents.clear();
      _historyEntries
        ..clear()
        ..addAll(
          List<String>.generate(
            widget.playerCount,
            (int index) => '${_playerName(index)}: ${widget.initialLifePoints}',
          ),
        );
    });
  }

  List<Alignment> _diePipAlignments(int value) {
    switch (value) {
      case 1:
        return const <Alignment>[Alignment.center];
      case 2:
        return const <Alignment>[Alignment.topLeft, Alignment.bottomRight];
      case 3:
        return const <Alignment>[
          Alignment.topLeft,
          Alignment.center,
          Alignment.bottomRight,
        ];
      case 4:
        return const <Alignment>[
          Alignment.topLeft,
          Alignment.topRight,
          Alignment.bottomLeft,
          Alignment.bottomRight,
        ];
      case 5:
        return const <Alignment>[
          Alignment.topLeft,
          Alignment.topRight,
          Alignment.center,
          Alignment.bottomLeft,
          Alignment.bottomRight,
        ];
      default:
        return const <Alignment>[
          Alignment.topLeft,
          Alignment.centerLeft,
          Alignment.bottomLeft,
          Alignment.topRight,
          Alignment.centerRight,
          Alignment.bottomRight,
        ];
    }
  }

  Widget _buildDieFace(
    int value, {
    required bool compact,
    required bool isRolling,
    bool prominent = false,
  }) {
    final double size = prominent ? (compact ? 34 : 42) : (compact ? 26 : 32);
    final double pipSize = prominent ? size * 0.16 : size * 0.145;
    final double inset = prominent ? size * 0.14 : size * 0.13;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isRolling ? const Color(0xFFFFE9B3) : const Color(0xFFEEEDED),
        borderRadius: BorderRadius.circular(prominent ? 12 : (compact ? 7 : 9)),
        border: Border.all(
          color: isRolling ? const Color(0xFFE7C061) : const Color(0xFFB0AFAF),
          width: prominent ? (isRolling ? 1.9 : 1.2) : (isRolling ? 1.6 : 1),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(inset),
        child: Stack(
          children: [
            for (final Alignment align in _diePipAlignments(value))
              Align(
                alignment: align,
                child: Container(
                  width: pipSize,
                  height: pipSize,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A1A1A),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedDieResult({required int value, required bool compact}) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1).animate(animation),
            child: child,
          ),
        );
      },
      child: !_showDiceResults
          ? const SizedBox.shrink(key: ValueKey<String>('dice-hidden'))
          : Container(
              key: ValueKey<String>(
                'dice-$value-${compact ? 'compact' : 'regular'}-${_isRollingDice ? 'rolling' : 'final'}',
              ),
              padding: EdgeInsets.all(compact ? 4 : 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(compact ? 14 : 18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: _buildDieFace(
                value,
                compact: compact,
                isRolling: _isRollingDice,
                prominent: true,
              ),
            ),
    );
  }

  Widget _buildPendingDeltaBadge({
    required int playerIndex,
    required bool compact,
  }) {
    final int value = _pendingDeltas[playerIndex];
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 140),
      child: value == 0
          ? const SizedBox.shrink(key: ValueKey<String>('empty-delta'))
          : Container(
              key: ValueKey<String>('pending-$playerIndex-$value'),
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 6 : 8,
                vertical: compact ? 2 : 3,
              ),
              decoration: BoxDecoration(
                color: value > 0
                    ? const Color(0xFF245D32)
                    : const Color(0xFF6A2323),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _formatSigned(value),
                style: TextStyle(
                  fontSize: compact ? 10 : 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
    );
  }

  Widget _buildInlineLpTapHint({
    required bool isPositive,
    required bool compact,
  }) {
    return Container(
      width: compact ? 24 : 30,
      height: compact ? 24 : 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: widget.settings.buttonColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Icon(
        isPositive ? Icons.add_rounded : Icons.remove_rounded,
        size: compact ? 16 : 19,
        weight: 700,
      ),
    );
  }

  Widget _buildPanelActionButton({
    required String tooltip,
    required Widget icon,
    required VoidCallback onPressed,
    required bool compact,
    double? side,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: icon,
      style: IconButton.styleFrom(
        backgroundColor: widget.settings.buttonColor,
        minimumSize: Size.square(side ?? (compact ? 26 : 30)),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildLabeledPanelAction({
    required String label,
    required String tooltip,
    required Widget icon,
    required VoidCallback onPressed,
    required bool compact,
    double? side,
    double? slotWidth,
  }) {
    final double labelSize = compact ? 8.5 : 9.5;
    final Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPanelActionButton(
          tooltip: tooltip,
          icon: icon,
          onPressed: onPressed,
          compact: compact,
          side: side,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: labelSize,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.82),
            height: 1.0,
          ),
        ),
      ],
    );

    if (slotWidth == null) {
      return content;
    }

    return SizedBox(width: slotWidth, child: content);
  }

  Widget _playerPanel({
    required int playerIndex,
    required bool compact,
    required bool longSide,
  }) {
    final int? dieValue = _diceValues[playerIndex];
    final bool showDieResult = _showDiceResults && dieValue != null;
    final int dieResultValue = dieValue ?? 0;
    final int lifePoints = _lifePoints[playerIndex];
    final int poisonCounters = _poisonCountersForPlayer(playerIndex);
    final int experienceCounters = _experienceCountersForPlayer(playerIndex);
    final int commanderDamage = _commanderDamageTotalForPlayer(playerIndex);
    final bool dense = compact || longSide;
    final bool useEqualShortSideActionSlots =
        !longSide && widget.playerCount == 2;
    final double? actionSlotWidth = useEqualShortSideActionSlots ? 58 : null;
    final bool tight = longSide && widget.playerCount >= 4;
    final bool ultraTight = longSide && widget.playerCount >= 5;
    final double actionSide = longSide
        ? (ultraTight ? 26 : (tight ? 29 : 33))
        : (dense ? 27 : 30);
    final double actionIconSize = longSide
        ? (ultraTight ? 16 : (tight ? 18 : 20))
        : (dense ? 15 : 16);
    final String panelPlayerName = ultraTight
        ? 'P${playerIndex + 1}'
        : _playerName(playerIndex).toUpperCase();
    final String lpOwnerLabel = _playerName(playerIndex);
    final double lpHorizontalPadding = longSide
        ? (ultraTight ? 12 : (tight ? 14 : 18))
        : (dense ? 22 : 16);
    final AppStrings txt = context.txt;
    final String historyLabel = ultraTight ? txt.t('game.histShort') : txt.t('game.history');
    final String manaLabel = txt.t('game.mana');
    final String statusLabel = ultraTight ? txt.t('game.cntrShort') : txt.t('game.counters');
    final String commanderLabel = ultraTight ? txt.t('game.cmdShort') : txt.t('game.commander');
    final List<String> statusFragments = <String>[
      if (poisonCounters > 0) 'Poison $poisonCounters',
      if (experienceCounters > 0) 'Exp $experienceCounters',
      if (commanderDamage > 0) 'Cmd $commanderDamage',
    ];

    final Widget historyButton = _buildLabeledPanelAction(
      label: historyLabel,
      tooltip: 'Open history',
      onPressed: () => _openHistoryForPlayer(playerIndex),
      compact: dense,
      side: actionSide,
      slotWidth: actionSlotWidth,
      icon: Icon(Icons.format_list_bulleted_rounded, size: actionIconSize),
    );
    final Widget manaButton = _buildLabeledPanelAction(
      label: manaLabel,
      tooltip: 'Open mana and storm counters',
      onPressed: () => _openMtgResourceCountersForPlayer(playerIndex),
      compact: dense,
      side: actionSide,
      slotWidth: actionSlotWidth,
      icon: Icon(Icons.blur_circular_rounded, size: actionIconSize),
    );
    final Widget statusButton = _buildLabeledPanelAction(
      label: statusLabel,
      tooltip: 'Open poison and experience counters',
      onPressed: () => _openMtgStatusCountersForPlayer(playerIndex),
      compact: dense,
      side: actionSide,
      slotWidth: actionSlotWidth,
      icon: Text(
        '\u03A6',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: actionIconSize - 1,
        ),
      ),
    );
    final Widget commanderButton = _buildLabeledPanelAction(
      label: commanderLabel,
      tooltip: 'Open commander damage counters',
      onPressed: () => _openCommanderDamageForPlayer(playerIndex),
      compact: dense,
      side: actionSide,
      slotWidth: actionSlotWidth,
      icon: Icon(Icons.local_fire_department_rounded, size: actionIconSize),
    );
    final Widget panelHeader = longSide
        ? Align(
            alignment: Alignment.centerLeft,
            child: Text(
              panelPlayerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.86),
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                fontSize: dense ? 11 : 13,
              ),
            ),
          )
        : Row(
            children: [
              Expanded(
                child: Text(
                  panelPlayerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    fontSize: dense ? 11 : 13,
                  ),
                ),
              ),
              SizedBox(width: dense ? 4 : 6),
              historyButton,
              SizedBox(width: dense ? 4 : 6),
              manaButton,
              SizedBox(width: dense ? 4 : 6),
              statusButton,
              SizedBox(width: dense ? 4 : 6),
              commanderButton,
            ],
          );

    Widget? statusInfo;
    if (!longSide &&
        (poisonCounters > 0 || experienceCounters > 0 || commanderDamage > 0)) {
      statusInfo = Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            if (poisonCounters > 0)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: dense ? 9 : 11,
                  vertical: dense ? 3 : 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF6A2323),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFFF8A8A)),
                ),
                child: Text(
                  'Poison: $poisonCounters',
                  style: TextStyle(
                    color: const Color(0xFFFFA3A3),
                    fontWeight: FontWeight.w700,
                    fontSize: dense ? 11 : 13,
                  ),
                ),
              ),
            if (experienceCounters > 0)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: dense ? 9 : 11,
                  vertical: dense ? 3 : 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF234A6A),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFF7AC7FF)),
                ),
                child: Text(
                  'Exp: $experienceCounters',
                  style: TextStyle(
                    color: const Color(0xFFBEE8FF),
                    fontWeight: FontWeight.w700,
                    fontSize: dense ? 11 : 13,
                  ),
                ),
              ),
            if (commanderDamage > 0)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: dense ? 9 : 11,
                  vertical: dense ? 3 : 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF5A1E1E),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFFF7575)),
                ),
                child: Text(
                  'Commander: $commanderDamage',
                  style: TextStyle(
                    color: const Color(0xFFFFA9A9),
                    fontWeight: FontWeight.w700,
                    fontSize: dense ? 11 : 13,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    final Widget lpCard = Stack(
      children: [
        Align(
          alignment: Alignment.center,
          child: Container(
            width: double.infinity,
            height: longSide ? double.infinity : null,
            padding: EdgeInsets.symmetric(
              horizontal: dense ? 8 : 12,
              vertical: dense ? 5 : 8,
            ),
            decoration: BoxDecoration(
              color: _playerCardBackgroundColor(playerIndex),
              borderRadius: BorderRadius.circular(longSide ? 8 : 14),
              border: Border.all(
                color: Colors.white.withValues(alpha: longSide ? 0.07 : 0.12),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(longSide ? 8 : 12),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Row(
                      children: [
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _applySignedDelta(
                                playerIndex: playerIndex,
                                delta: -1,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _applySignedDelta(
                                playerIndex: playerIndex,
                                delta: 1,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: EdgeInsets.only(left: dense ? 5 : 8),
                                child: _buildInlineLpTapHint(
                                  isPositive: false,
                                  compact: dense,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: EdgeInsets.only(right: dense ? 5 : 8),
                                child: _buildInlineLpTapHint(
                                  isPositive: true,
                                  compact: dense,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: lpHorizontalPadding,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '$lifePoints',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: longSide ? 320 : 360,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: showDieResult ? (dense ? 40 : 48) : (dense ? 2 : 4),
          child: _buildPendingDeltaBadge(
            playerIndex: playerIndex,
            compact: dense,
          ),
        ),
        Positioned(
          right: 0,
          top: dense ? 0 : 2,
          child: showDieResult
              ? _buildAnimatedDieResult(value: dieResultValue, compact: true)
              : const SizedBox.shrink(),
        ),
        if (longSide && statusFragments.isNotEmpty)
          Positioned(
            left: dense ? 6 : 8,
            top: dense ? 4 : 6,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: dense ? 8 : 10,
                vertical: dense ? 3 : 4,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Text(
                statusFragments.join(' • '),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: ultraTight ? 11 : 13,
                ),
              ),
            ),
          ),
        if (longSide)
          Positioned(
            right: dense ? 6 : 8,
            bottom: dense ? 4 : 6,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: ultraTight ? 78 : 128),
              child: Text(
                lpOwnerLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontWeight: FontWeight.w700,
                  fontSize: ultraTight ? 9 : 11,
                ),
              ),
            ),
          ),
      ],
    );

    final Widget? quickTenControls = (longSide || widget.playerCount > 2)
        ? null
        : Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: () =>
                      _applySignedDelta(playerIndex: playerIndex, delta: -10),
                  style: FilledButton.styleFrom(
                    backgroundColor: widget.settings.buttonColor,
                    minimumSize: const Size.fromHeight(34),
                  ),
                  child: const Text(
                    '-10',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: () =>
                      _applySignedDelta(playerIndex: playerIndex, delta: 10),
                  style: FilledButton.styleFrom(
                    backgroundColor: widget.settings.buttonColor,
                    minimumSize: const Size.fromHeight(34),
                  ),
                  child: const Text(
                    '+10',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ),
              ),
            ],
          );

    if (longSide) {
      final double actionGap = ultraTight ? 3 : (tight ? 4 : 6);
      final List<Widget> actionRail = <Widget>[
        historyButton,
        SizedBox(height: actionGap),
        manaButton,
        SizedBox(height: actionGap),
        statusButton,
        SizedBox(height: actionGap),
        commanderButton,
      ];
      final BorderRadius railRadius = BorderRadius.circular(
        ultraTight ? 8 : 12,
      );

      return Padding(
        padding: EdgeInsets.all(ultraTight ? 1 : 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: lpCard),
            SizedBox(width: ultraTight ? 2 : 4),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: ultraTight ? 1 : 2,
                vertical: ultraTight ? 4 : 6,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: railRadius,
                border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: actionRail,
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: EdgeInsets.all(longSide ? (ultraTight ? 2 : 3) : (dense ? 6 : 8)),
      padding: EdgeInsets.all(
        longSide ? (ultraTight ? 4 : 6) : (dense ? 6 : 8),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF221818),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          panelHeader,
          if (statusInfo != null) ...[
            SizedBox(height: ultraTight ? 2 : (dense ? 4 : 6)),
            statusInfo,
          ],
          SizedBox(height: dense ? 2 : 4),
          Expanded(child: lpCard),
          if (quickTenControls != null) ...[
            SizedBox(height: dense ? 2 : 4),
            quickTenControls,
          ],
        ],
      ),
    );
  }

  Widget _buildCenterControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Card(
        color: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              const double spacing = 8;
              const int buttonsCount = 5;
              final double buttonWidth =
                  ((constraints.maxWidth - spacing * (buttonsCount - 1)) /
                          buttonsCount)
                      .clamp(54.0, 78.0);
              final double controlsWidth =
                  buttonWidth * buttonsCount + spacing * (buttonsCount - 1);

              Widget controlButton({
                required VoidCallback? onPressed,
                required Widget icon,
              }) {
                return SizedBox(
                  width: buttonWidth,
                  child: FilledButton.tonal(
                    onPressed: onPressed,
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.settings.buttonColor,
                      minimumSize: const Size.fromHeight(46),
                      padding: EdgeInsets.zero,
                    ),
                    child: Center(child: icon),
                  ),
                );
              }

              return Center(
                child: SizedBox(
                  width: controlsWidth,
                  child: Row(
                    children: [
                      controlButton(
                        onPressed: () => _confirmReset(fromHome: true),
                        icon: const Icon(Icons.home_outlined, size: 28),
                      ),
                      const SizedBox(width: spacing),
                      controlButton(
                        onPressed: _confirmReset,
                        icon: const Icon(Icons.restart_alt, size: 28),
                      ),
                      const SizedBox(width: spacing),
                      controlButton(
                        onPressed: _openMatchDetailsEditor,
                        icon: const Icon(Icons.edit_outlined, size: 28),
                      ),
                      const SizedBox(width: spacing),
                      controlButton(
                        onPressed: () {
                          unawaited(_openSideboardGuideDialog());
                        },
                        icon: const Icon(Icons.menu_book_outlined, size: 28),
                      ),
                      const SizedBox(width: spacing),
                      controlButton(
                        onPressed: _isRollingDice ? null : _rollDice,
                        icon: const Icon(Icons.casino_outlined, size: 28),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerRow({
    required List<int?> slots,
    bool forceCompact = false,
  }) {
    final int activePlayers = slots.whereType<int>().length;
    final List<int> slotFlexes = _slotFlexesForSlots(slots);

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

                final int quarterTurns = _quarterTurnsForPlayer(playerIndex);
                final bool longSide = quarterTurns == 1 || quarterTurns == 3;
                final bool compact =
                    forceCompact ||
                    longSide ||
                    activePlayers > 1 ||
                    widget.playerCount >= 5;

                Widget panel = _playerPanel(
                  playerIndex: playerIndex,
                  compact: compact,
                  longSide: longSide,
                );
                if (quarterTurns != 0) {
                  panel = RotatedBox(quarterTurns: quarterTurns, child: panel);
                }
                return panel;
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPlayerPanelSlot({
    required int playerIndex,
    required int quarterTurns,
    required bool longSide,
    bool forceCompact = false,
  }) {
    final bool compact = forceCompact || longSide || widget.playerCount >= 5;
    Widget panel = _playerPanel(
      playerIndex: playerIndex,
      compact: compact,
      longSide: longSide,
    );
    if (quarterTurns != 0) {
      panel = RotatedBox(quarterTurns: quarterTurns, child: panel);
    }
    return panel;
  }

  Widget _buildThreePlayerStandardLayout() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
        child: Stack(
          children: [
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: _buildPlayerPanelSlot(
                      playerIndex: 1,
                      quarterTurns: 1,
                      longSide: true,
                      forceCompact: true,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: _buildPlayerPanelSlot(
                            playerIndex: 2,
                            quarterTurns: 3,
                            longSide: true,
                            forceCompact: true,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: _buildPlayerPanelSlot(
                            playerIndex: 0,
                            quarterTurns: 3,
                            longSide: true,
                            forceCompact: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.center,
              child: _buildLongSideControlsLauncher(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiplayerRowsLayout({required List<_MtgLayoutRowSpec> rows}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
        child: Stack(
          children: [
            Column(
              children: [
                for (final _MtgLayoutRowSpec row in rows)
                  Expanded(
                    flex: row.flex,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: _buildPlayerRow(slots: row.slots),
                    ),
                  ),
              ],
            ),
            Align(
              alignment: Alignment.center,
              child: _buildLongSideControlsLauncher(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStandardMultiplayerLayout() {
    if (widget.playerCount == 3) {
      return _buildThreePlayerStandardLayout();
    }
    if (widget.playerCount == 5) {
      return _buildFivePlayerStandardLayout();
    }
    if (widget.playerCount == 6) {
      return _buildSixPlayerStandardLayout();
    }

    return _buildMultiplayerRowsLayout(
      rows: _mtgLayoutRows(
        playerCount: widget.playerCount,
        layoutMode: MtgDuelLayoutMode.standard,
      ),
    );
  }

  Widget _buildFivePlayerStandardLayout() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Column(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: _buildPlayerPanelSlot(
                              playerIndex: 2,
                              quarterTurns: _quarterTurnsForPlayer(2),
                              longSide: true,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: _buildPlayerPanelSlot(
                              playerIndex: 1,
                              quarterTurns: _quarterTurnsForPlayer(1),
                              longSide: true,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: _buildPlayerPanelSlot(
                              playerIndex: 0,
                              quarterTurns: _quarterTurnsForPlayer(0),
                              longSide: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Column(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: _buildPlayerPanelSlot(
                              playerIndex: 4,
                              quarterTurns: _quarterTurnsForPlayer(4),
                              longSide: true,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: _buildPlayerPanelSlot(
                              playerIndex: 3,
                              quarterTurns: _quarterTurnsForPlayer(3),
                              longSide: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.center,
              child: _buildLongSideControlsLauncher(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSixPlayerStandardLayout() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Column(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: _buildPlayerPanelSlot(
                              playerIndex: 2,
                              quarterTurns: _quarterTurnsForPlayer(2),
                              longSide: true,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: _buildPlayerPanelSlot(
                              playerIndex: 1,
                              quarterTurns: _quarterTurnsForPlayer(1),
                              longSide: true,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: _buildPlayerPanelSlot(
                              playerIndex: 0,
                              quarterTurns: _quarterTurnsForPlayer(0),
                              longSide: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Column(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: _buildPlayerPanelSlot(
                              playerIndex: 5,
                              quarterTurns: _quarterTurnsForPlayer(5),
                              longSide: true,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: _buildPlayerPanelSlot(
                              playerIndex: 4,
                              quarterTurns: _quarterTurnsForPlayer(4),
                              longSide: true,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: _buildPlayerPanelSlot(
                              playerIndex: 3,
                              quarterTurns: _quarterTurnsForPlayer(3),
                              longSide: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.center,
              child: _buildLongSideControlsLauncher(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFourPlayerTableLayout() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  flex: 26,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: _buildPlayerRow(slots: const <int?>[2]),
                  ),
                ),
                Expanded(
                  flex: 48,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: _buildPlayerPanelSlot(
                              playerIndex: 1,
                              quarterTurns: _quarterTurnsForPlayer(1),
                              longSide: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                widthFactor: 1,
                                heightFactor: 0.94,
                                alignment: Alignment.bottomCenter,
                                child: _buildPlayerPanelSlot(
                                  playerIndex: 3,
                                  quarterTurns: _quarterTurnsForPlayer(3),
                                  longSide: true,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 26,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: _buildPlayerRow(slots: const <int?>[0]),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.center,
              child: _buildLongSideControlsLauncher(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFivePlayerTableLayout() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  flex: 22,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: _buildPlayerRow(slots: const <int?>[3]),
                  ),
                ),
                Expanded(
                  flex: 56,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 9,
                          child: Column(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 1,
                                  ),
                                  child: _buildPlayerPanelSlot(
                                    playerIndex: 1,
                                    quarterTurns: _quarterTurnsForPlayer(1),
                                    longSide: true,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 1,
                                  ),
                                  child: _buildPlayerPanelSlot(
                                    playerIndex: 2,
                                    quarterTurns: _quarterTurnsForPlayer(2),
                                    longSide: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          flex: 10,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: Align(
                              alignment: Alignment.center,
                              child: _buildPlayerPanelSlot(
                                playerIndex: 4,
                                quarterTurns: _quarterTurnsForPlayer(4),
                                longSide: true,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 22,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: _buildPlayerRow(slots: const <int?>[0]),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.center,
              child: _buildLongSideControlsLauncher(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableMultiplayerLayout() {
    if (widget.playerCount == 4) {
      return _buildFourPlayerTableLayout();
    }
    if (widget.playerCount == 5) {
      return _buildFivePlayerTableLayout();
    }
    if (widget.playerCount == 6) {
      return _buildSixPlayerTableLayout();
    }
    return _buildMultiplayerRowsLayout(
      rows: _mtgLayoutRows(
        playerCount: widget.playerCount,
        layoutMode: MtgDuelLayoutMode.tableMode,
      ),
    );
  }

  Widget _buildSixPlayerTableLayout() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  flex: 24,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: _buildPlayerRow(slots: const <int?>[3]),
                  ),
                ),
                Expanded(
                  flex: 52,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 1,
                                  ),
                                  child: _buildPlayerPanelSlot(
                                    playerIndex: 1,
                                    quarterTurns: _quarterTurnsForPlayer(1),
                                    longSide: true,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 1,
                                  ),
                                  child: _buildPlayerPanelSlot(
                                    playerIndex: 2,
                                    quarterTurns: _quarterTurnsForPlayer(2),
                                    longSide: true,
                                  ),
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
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 1,
                                  ),
                                  child: _buildPlayerPanelSlot(
                                    playerIndex: 4,
                                    quarterTurns: _quarterTurnsForPlayer(4),
                                    longSide: true,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 1,
                                  ),
                                  child: _buildPlayerPanelSlot(
                                    playerIndex: 5,
                                    quarterTurns: _quarterTurnsForPlayer(5),
                                    longSide: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 24,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: _buildPlayerRow(slots: const <int?>[0]),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.center,
              child: _buildLongSideControlsLauncher(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTwoPlayerTableLayout() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
            child: _buildPlayerRow(slots: const <int?>[1]),
          ),
        ),
        _buildCenterControls(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
            child: _buildPlayerRow(slots: const <int?>[0]),
          ),
        ),
      ],
    );
  }

  Future<void> _openLongSideControlsMenu() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        Widget menuButton({
          required String label,
          required IconData icon,
          required VoidCallback? onPressed,
        }) {
          return FilledButton.tonal(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: widget.settings.buttonColor,
              minimumSize: const Size(164, 44),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          );
        }

        return Dialog(
          backgroundColor: const Color(0xFF181818),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 40,
            vertical: 24,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                menuButton(
                  label: 'Home',
                  icon: Icons.home_outlined,
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _confirmReset(fromHome: true);
                  },
                ),
                const SizedBox(height: 8),
                menuButton(
                  label: 'Reset',
                  icon: Icons.restart_alt,
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _confirmReset();
                  },
                ),
                const SizedBox(height: 8),
                menuButton(
                  label: dialogContext.txt.t('game.details'),
                  icon: Icons.edit_outlined,
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _openMatchDetailsEditor();
                  },
                ),
                const SizedBox(height: 8),
                menuButton(
                  label: dialogContext.txt.t('game.dice'),
                  icon: Icons.casino_outlined,
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _rollDice();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLongSideControlsLauncher() {
    return SizedBox(
      width: 48,
      child: FilledButton.tonal(
        onPressed: _openLongSideControlsMenu,
        style: FilledButton.styleFrom(
          backgroundColor: widget.settings.buttonColor,
          minimumSize: const Size(48, 52),
          padding: EdgeInsets.zero,
        ),
        child: const Icon(Icons.home_outlined, size: 26),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color duelMiddle =
        Color.lerp(
          widget.settings.backgroundStartColor,
          widget.settings.backgroundEndColor,
          0.45,
        ) ??
        widget.settings.backgroundStartColor;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        _closeWithHistory();
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                widget.settings.backgroundStartColor,
                duelMiddle,
                widget.settings.backgroundEndColor,
              ],
            ),
          ),
          child: SafeArea(
            child: _isMultiplayer
                ? Column(
                    children: [
                      _isTableMode
                          ? _buildTableMultiplayerLayout()
                          : _buildStandardMultiplayerLayout(),
                    ],
                  )
                : _buildTwoPlayerTableLayout(),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    unawaited(WakelockPlus.disable());
    _diceRollTimer?.cancel();
    _diceResultTimer?.cancel();
    for (int index = 0; index < _pendingTimers.length; index += 1) {
      _pendingTimers[index]?.cancel();
    }
    super.dispose();
  }
}

class DuelScreen extends StatefulWidget {
  const DuelScreen({
    super.key,
    required this.settings,
    this.ruleset = DuelRuleSet.yugioh,
    this.initialLifePoints = 8000,
    this.availableDeckNames = const <String>[],
    this.availableDecks = const <SideboardDeck>[],
    this.initialDeckName = '',
    this.onCheckpoint,
  });

  final AppSettings settings;
  final DuelRuleSet ruleset;
  final int initialLifePoints;
  final List<String> availableDeckNames;
  final List<SideboardDeck> availableDecks;
  final String initialDeckName;
  final DuelCheckpointCallback? onCheckpoint;

  @override
  State<DuelScreen> createState() => _DuelScreenState();
}

class _DuelScreenState extends State<DuelScreen> {
  static const Duration _aggregationWindow = Duration(seconds: 2);

  final Random _random = Random();

  late int _playerOneLp;
  late int _playerTwoLp;

  bool _isRollingDice = false;

  int? _playerOneDie;
  int? _playerTwoDie;

  int _playerOnePendingDelta = 0;
  int _playerTwoPendingDelta = 0;

  Timer? _diceRollTimer;
  Timer? _diceResultTimer;
  int _diceRollTicks = 0;
  bool _showDiceResults = false;
  Timer? _playerOnePendingTimer;
  Timer? _playerTwoPendingTimer;

  late final Map<_MtgResourceCounter, int> _playerOneResourceCounters;
  late final Map<_MtgResourceCounter, int> _playerTwoResourceCounters;
  late final Map<_MtgStatusCounter, int> _playerOneStatusCounters;
  late final Map<_MtgStatusCounter, int> _playerTwoStatusCounters;

  late final List<TwoPlayerLifeEvent> _twoPlayerLifeEvents;

  String _opponentName = '';
  String _opponentDeckInUse = '';
  String _selectedOpponentDeckId = '';
  String _matchFormat = '';
  String _matchTag = '';
  String _matchName = '';
  String _selectedGameStage = 'G1';
  String _deckInUse = '';
  String _selectedDeckId = '';
  int _bo3Wins = 0;
  int _bo3Losses = 0;
  String _lastCompletedOpponentName = '';
  String _lastRecordedOpponentName = '';
  final List<DuelCompletedGamePayload> _completedGamesForSession =
      <DuelCompletedGamePayload>[];
  final List<SideboardDeck> _createdDecksForSession = <SideboardDeck>[];
  late List<SideboardDeck> _sessionAvailableDecks;
  late String _currentMatchId;

  bool get _isMtgRules => widget.ruleset == DuelRuleSet.mtg;

  String _playerName(int player) {
    if (player == 2) {
      final String opponent = _opponentName.trim();
      if (opponent.isNotEmpty) {
        return opponent;
      }
    }
    return player == 1
        ? widget.settings.playerOneName
        : widget.settings.playerTwoName;
  }

  String _resolveInitialDeckName() {
    final String normalizedInitial = widget.initialDeckName
        .trim()
        .toLowerCase();
    if (normalizedInitial.isEmpty) {
      return '';
    }
    for (final String raw in widget.availableDeckNames) {
      final String trimmed = raw.trim();
      if (trimmed.toLowerCase() == normalizedInitial) {
        return trimmed;
      }
    }
    for (final SideboardDeck deck in _sessionAvailableDecks) {
      final String trimmed = deck.name.trim();
      if (trimmed.toLowerCase() == normalizedInitial) {
        return trimmed;
      }
    }
    return '';
  }

  SideboardDeck? _deckById(String deckId) {
    final String trimmedId = deckId.trim();
    if (trimmedId.isEmpty) {
      return null;
    }
    for (final SideboardDeck deck in _sessionAvailableDecks) {
      if (deck.id == trimmedId) {
        return deck;
      }
    }
    return null;
  }

  SideboardDeck? _deckByName(String deckName) {
    return _findUniqueDeckByName(_sessionAvailableDecks, deckName);
  }

  SideboardDeck? _selectedDeckForGuide() {
    return _deckById(_selectedDeckId) ?? _deckByName(_deckInUse);
  }

  String _selectedDeckIdForHistory() {
    return _selectedDeckForGuide()?.id ?? '';
  }

  String _deckIdByName(String deckName) {
    return _deckByName(deckName)?.id ?? '';
  }

  String _selectedOpponentDeckIdForHistory() {
    return _deckById(_selectedOpponentDeckId)?.id ??
        _deckIdByName(_opponentDeckInUse);
  }

  bool _hasConfiguredSideboard(SideboardMatchup matchup) {
    bool hasNamedCards(List<SideboardCardEntry> entries) {
      for (final SideboardCardEntry entry in entries) {
        if (entry.name.trim().isNotEmpty) {
          return true;
        }
      }
      return false;
    }

    return hasNamedCards(matchup.sideIn) || hasNamedCards(matchup.sideOut);
  }

  List<SideboardMatchup> _configuredMatchupsForGuide(SideboardDeck deck) {
    return deck.matchups.where(_hasConfiguredSideboard).toList(growable: false);
  }

  String _formatSideboardEntries(List<SideboardCardEntry> entries) {
    if (entries.isEmpty) {
      return '-';
    }
    return entries
        .map((SideboardCardEntry entry) {
          final String name = entry.name.trim().isEmpty
              ? 'Unnamed card'
              : entry.name.trim();
          final int copies = entry.copies.clamp(1, 99).toInt();
          return '$copies x $name';
        })
        .join(', ');
  }

  Future<void> _openSideboardGuideDialog() async {
    final AppStrings txt = context.txt;
    final SideboardDeck? deck = _selectedDeckForGuide();
    if (deck == null) {
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(txt.t('sideboardGuide.dialogTitle')),
            content: Text(txt.t('sideboardGuide.noDeckSelected')),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(txt.t('common.close')),
              ),
            ],
          );
        },
      );
      return;
    }
    await showInfoTipOnce(
      context: context,
      tipId: InfoTipIds.sideboardGuide,
      titleKey: 'info.sideboardGuide.title',
      bodyKey: 'info.sideboardGuide.body',
      icon: Icons.menu_book_rounded,
    );
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        final List<SideboardMatchup> configuredMatchups =
            _configuredMatchupsForGuide(deck);
        final bool hasMatchups = configuredMatchups.isNotEmpty;
        return AlertDialog(
          title: Text('${deck.name} - ${txt.t('sideboardGuide.dialogTitle')}'),
          content: SizedBox(
            width: double.maxFinite,
            child: hasMatchups
                ? SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (
                          int index = 0;
                          index < configuredMatchups.length;
                          index += 1
                        ) ...[
                          if (index > 0) const SizedBox(height: 12),
                          Text(
                            configuredMatchups[index].name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${txt.t('sideboardGuide.sideIn')}: ${_formatSideboardEntries(configuredMatchups[index].sideIn)}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${txt.t('sideboardGuide.sideOut')}: ${_formatSideboardEntries(configuredMatchups[index].sideOut)}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : Text(txt.t('sideboardGuide.noPlansForDeck')),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(txt.t('common.close')),
            ),
          ],
        );
      },
    );
  }

  void _registerCurrentGameResultForBo3() {
    if (_playerOneLp == _playerTwoLp) {
      return;
    }
    if (_playerOneLp > _playerTwoLp) {
      _bo3Wins += 1;
    } else {
      _bo3Losses += 1;
    }
  }

  void _registerDeclaredGameResultForBo3(String result) {
    if (result == 'Win') {
      _bo3Wins += 1;
      return;
    }
    if (result == 'Loss') {
      _bo3Losses += 1;
    }
  }

  void _advanceBo3AfterRestart({String? declaredResult}) {
    final String currentStage = _selectedGameStage;
    if (!_supportedGameStages.contains(currentStage)) {
      _selectedGameStage = 'G1';
      _bo3Wins = 0;
      _bo3Losses = 0;
      return;
    }

    final String explicitResult = (declaredResult ?? '').trim();
    if (explicitResult.isEmpty) {
      _registerCurrentGameResultForBo3();
    } else {
      _registerDeclaredGameResultForBo3(explicitResult);
    }

    String nextStage = 'G1';
    if (currentStage == 'G1') {
      nextStage = 'G2';
    } else if (currentStage == 'G2') {
      final bool matchClosed = _bo3Wins >= 2 || _bo3Losses >= 2;
      nextStage = matchClosed ? 'G1' : 'G3';
    } else {
      nextStage = 'G1';
    }

    _selectedGameStage = nextStage;
    if (nextStage == 'G1') {
      final String completedOpponent = _opponentName.trim();
      if (completedOpponent.isNotEmpty) {
        _lastCompletedOpponentName = completedOpponent;
      }
      _bo3Wins = 0;
      _bo3Losses = 0;
      _opponentName = '';
      _opponentDeckInUse = '';
      _selectedOpponentDeckId = '';
      _matchFormat = '';
      _matchTag = '';
      _matchName = '';
      _currentMatchId = 'match-${DateTime.now().microsecondsSinceEpoch}';
    }
  }

  String _resolvedOpponentForHistory() {
    final String trimmedOpponent = _opponentName.trim();
    if (trimmedOpponent.isNotEmpty) {
      return trimmedOpponent;
    }
    final String rememberedOpponent = _lastRecordedOpponentName.trim();
    if (rememberedOpponent.isNotEmpty) {
      return rememberedOpponent;
    }
    return _lastCompletedOpponentName.trim();
  }

  bool _hasActiveGameProgress() {
    if (_playerOneLp != widget.initialLifePoints ||
        _playerTwoLp != widget.initialLifePoints) {
      return true;
    }
    if (_playerOnePendingDelta != 0 || _playerTwoPendingDelta != 0) {
      return true;
    }
    if (_twoPlayerLifeEvents.isNotEmpty) {
      return true;
    }
    if (_isMtgRules) {
      for (final _MtgResourceCounter counter in _MtgResourceCounter.values) {
        if ((_playerOneResourceCounters[counter] ?? 0) != 0 ||
            (_playerTwoResourceCounters[counter] ?? 0) != 0) {
          return true;
        }
      }
      for (final _MtgStatusCounter counter in _MtgStatusCounter.values) {
        if ((_playerOneStatusCounters[counter] ?? 0) != 0 ||
            (_playerTwoStatusCounters[counter] ?? 0) != 0) {
          return true;
        }
      }
    }
    return false;
  }

  DuelCompletedGamePayload _buildCompletedGamePayload({
    required String matchResult,
  }) {
    final String rawStage = _selectedGameStage.trim().toUpperCase();
    final String normalizedStage = _supportedGameStages.contains(rawStage)
        ? rawStage
        : 'G1';
    final String rawResult = matchResult.trim();
    final String normalizedResult = _supportedMatchResults.contains(rawResult)
        ? rawResult
        : '';
    return DuelCompletedGamePayload(
      lifePointHistory: _historySnapshotWithPending(),
      gameStage: normalizedStage,
      opponentName: _resolvedOpponentForHistory(),
      deckId: _selectedDeckIdForHistory(),
      deckName: _deckInUse.trim(),
      opponentDeckId: _selectedOpponentDeckIdForHistory(),
      opponentDeckName: _opponentDeckInUse.trim(),
      matchFormat: _matchFormat.trim(),
      matchTag: _matchTag.trim(),
      matchId: _currentMatchId,
      matchName: _matchName.trim(),
      matchResult: normalizedResult,
      createdAt: DateTime.now(),
    );
  }

  @override
  void initState() {
    super.initState();
    unawaited(WakelockPlus.enable());
    _sessionAvailableDecks = List<SideboardDeck>.from(widget.availableDecks);
    _deckInUse = _resolveInitialDeckName();
    _selectedDeckId = _selectedDeckForGuide()?.id ?? '';
    _matchFormat = _selectedDeckForGuide()?.format.trim() ?? '';
    _currentMatchId = 'match-${DateTime.now().microsecondsSinceEpoch}';
    _playerOneLp = widget.initialLifePoints;
    _playerTwoLp = widget.initialLifePoints;
    _playerOneResourceCounters = {
      for (final _MtgResourceCounter counter in _MtgResourceCounter.values)
        counter: 0,
    };
    _playerTwoResourceCounters = {
      for (final _MtgResourceCounter counter in _MtgResourceCounter.values)
        counter: 0,
    };
    _playerOneStatusCounters = {
      for (final _MtgStatusCounter counter in _MtgStatusCounter.values)
        counter: 0,
    };
    _playerTwoStatusCounters = {
      for (final _MtgStatusCounter counter in _MtgStatusCounter.values)
        counter: 0,
    };
    _twoPlayerLifeEvents = <TwoPlayerLifeEvent>[];
  }

  String _formatSigned(int value) {
    return value > 0 ? '+$value' : '$value';
  }

  ({
    Alignment alignment,
    Offset beginOffset,
    double widthFactor,
    double heightFactor,
    int quarterTurns,
  })
  _calculatorPlacementFor(int player) {
    if (player == 1) {
      return (
        alignment: Alignment.bottomCenter,
        beginOffset: const Offset(0, 1),
        widthFactor: 0.96,
        heightFactor: 0.54,
        quarterTurns: 0,
      );
    }

    return (
      alignment: Alignment.topCenter,
      beginOffset: const Offset(0, -1),
      widthFactor: 0.96,
      heightFactor: 0.54,
      quarterTurns: 2,
    );
  }

  void _cancelPendingTimer(int player) {
    if (player == 1) {
      _playerOnePendingTimer?.cancel();
      _playerOnePendingTimer = null;
      return;
    }
    _playerTwoPendingTimer?.cancel();
    _playerTwoPendingTimer = null;
  }

  void _startPendingTimer(int player) {
    _cancelPendingTimer(player);

    final Timer timer = Timer(_aggregationWindow, () {
      _commitPendingDelta(player);
    });

    if (player == 1) {
      _playerOnePendingTimer = timer;
      return;
    }
    _playerTwoPendingTimer = timer;
  }

  void _commitPendingDelta(int player) {
    if (!mounted) {
      return;
    }

    final int pending = player == 1
        ? _playerOnePendingDelta
        : _playerTwoPendingDelta;
    if (pending == 0) {
      return;
    }

    final int currentLp = player == 1 ? _playerOneLp : _playerTwoLp;
    setState(() {
      _twoPlayerLifeEvents.add(
        TwoPlayerLifeEvent(
          player: player,
          delta: pending,
          resultingLife: currentLp,
        ),
      );
      if (player == 1) {
        _playerOnePendingDelta = 0;
      } else {
        _playerTwoPendingDelta = 0;
      }
    });
  }

  void _applySignedDelta({required int player, required int delta}) {
    final int currentLp = player == 1 ? _playerOneLp : _playerTwoLp;
    final int nextLp = max(0, currentLp + delta);
    final int effectiveDelta = nextLp - currentLp;

    if (effectiveDelta == 0) {
      return;
    }

    setState(() {
      if (player == 1) {
        _playerOneLp = nextLp;
        _playerOnePendingDelta += effectiveDelta;
      } else {
        _playerTwoLp = nextLp;
        _playerTwoPendingDelta += effectiveDelta;
      }
    });

    _startPendingTimer(player);
  }

  void _changeLp({
    required int player,
    required int amount,
    required bool addMode,
  }) {
    final bool add = addMode;
    final int signedDelta = add ? amount : -amount;
    _applySignedDelta(player: player, delta: signedDelta);
  }

  void _applyScaleAction({required int player, required bool addMode}) {
    final bool add = addMode;
    final int currentLp = player == 1 ? _playerOneLp : _playerTwoLp;
    final int nextLp = add ? currentLp * 2 : currentLp ~/ 2;
    final int signedDelta = nextLp - currentLp;
    _applySignedDelta(player: player, delta: signedDelta);
  }

  Map<_MtgResourceCounter, int> _resourceCountersForPlayer(int player) {
    return player == 1
        ? _playerOneResourceCounters
        : _playerTwoResourceCounters;
  }

  Map<_MtgStatusCounter, int> _statusCountersForPlayer(int player) {
    return player == 1 ? _playerOneStatusCounters : _playerTwoStatusCounters;
  }

  int _poisonCountersForPlayer(int player) {
    return _statusCountersForPlayer(player)[_MtgStatusCounter.poison] ?? 0;
  }

  int _experienceCountersForPlayer(int player) {
    return _statusCountersForPlayer(player)[_MtgStatusCounter.experience] ?? 0;
  }

  void _changeMtgResourceCounter({
    required int player,
    required _MtgResourceCounter counter,
    required int delta,
  }) {
    final Map<_MtgResourceCounter, int> counters = _resourceCountersForPlayer(
      player,
    );
    final int current = counters[counter] ?? 0;
    final int next = max(0, current + delta);
    if (next == current) {
      return;
    }
    setState(() {
      counters[counter] = next;
    });
  }

  void _changeMtgStatusCounter({
    required int player,
    required _MtgStatusCounter counter,
    required int delta,
  }) {
    final Map<_MtgStatusCounter, int> counters = _statusCountersForPlayer(
      player,
    );
    final int current = counters[counter] ?? 0;
    final int next = max(0, current + delta);
    if (next == current) {
      return;
    }
    setState(() {
      counters[counter] = next;
    });
  }

  Future<void> _openMtgCountersPanel({
    required int player,
    required String title,
    required Widget Function(StateSetter setModalState) contentBuilder,
  }) async {
    final placement = _calculatorPlacementFor(player);

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close counters',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (BuildContext context, _, _) {
        return SafeArea(
          child: RotatedBox(
            quarterTurns: placement.quarterTurns,
            child: Material(
              color: const Color(0xFF141414),
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setModalState) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close_rounded),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.08,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(child: contentBuilder(setModalState)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
      transitionBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> _,
            Widget child,
          ) {
            final Animation<Offset> offsetAnimation =
                Tween<Offset>(
                  begin: placement.beginOffset,
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                );

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: offsetAnimation, child: child),
            );
          },
    );
  }

  Widget _buildMtgCounterRow({
    required Widget label,
    required int value,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
    bool compact = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: compact ? 6 : 8),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Expanded(child: label),
          IconButton(
            onPressed: onDecrement,
            icon: const Icon(Icons.remove_rounded),
            style: IconButton.styleFrom(
              minimumSize: Size.square(compact ? 30 : 32),
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 32,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: compact ? 15 : 16,
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: onIncrement,
            icon: const Icon(Icons.add_rounded),
            style: IconButton.styleFrom(
              minimumSize: Size.square(compact ? 30 : 32),
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMtgResourceCountersForPlayer(int player) async {
    if (!_isMtgRules) {
      return;
    }

    await _openMtgCountersPanel(
      player: player,
      title: '${_playerName(player)} - Mana & Storm',
      contentBuilder: (StateSetter setModalState) {
        final Map<_MtgResourceCounter, int> counters =
            _resourceCountersForPlayer(player);
        return Column(
          children: [
            for (final _MtgResourceCounter counter
                in _MtgResourceCounter.values)
              Expanded(
                child: _buildMtgCounterRow(
                  compact: true,
                  label: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: counter.accentColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          counter.label,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  value: counters[counter] ?? 0,
                  onDecrement: () {
                    _changeMtgResourceCounter(
                      player: player,
                      counter: counter,
                      delta: -1,
                    );
                    setModalState(() {});
                  },
                  onIncrement: () {
                    _changeMtgResourceCounter(
                      player: player,
                      counter: counter,
                      delta: 1,
                    );
                    setModalState(() {});
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _openMtgStatusCountersForPlayer(int player) async {
    if (!_isMtgRules) {
      return;
    }

    await _openMtgCountersPanel(
      player: player,
      title: '${_playerName(player)} - Poison & Experience',
      contentBuilder: (StateSetter setModalState) {
        final Map<_MtgStatusCounter, int> counters = _statusCountersForPlayer(
          player,
        );
        return Column(
          children: [
            for (final _MtgStatusCounter counter in _MtgStatusCounter.values)
              _buildMtgCounterRow(
                label: Row(
                  children: [
                    if (counter == _MtgStatusCounter.poison) ...[
                      Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1D5F2A),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          '\u03A6',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        counter.label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                value: counters[counter] ?? 0,
                onDecrement: () {
                  _changeMtgStatusCounter(
                    player: player,
                    counter: counter,
                    delta: -1,
                  );
                  setModalState(() {});
                },
                onIncrement: () {
                  _changeMtgStatusCounter(
                    player: player,
                    counter: counter,
                    delta: 1,
                  );
                  setModalState(() {});
                },
              ),
            const Spacer(),
          ],
        );
      },
    );
  }

  Future<void> _openHistoryForPlayer(int player) async {
    final List<String> historySnapshot = _historySnapshotWithPending();
    final placement = _calculatorPlacementFor(player);

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close history',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (BuildContext context, _, _) {
        return SafeArea(
          child: RotatedBox(
            quarterTurns: placement.quarterTurns,
            child: Material(
              color: const Color(0xFF141414),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'LP History',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.08,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF101010),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: _buildLifeHistoryView(
                          lines: historySnapshot,
                          playerCount: 2,
                          dividerColor: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> _,
            Widget child,
          ) {
            final Animation<Offset> offsetAnimation =
                Tween<Offset>(
                  begin: placement.beginOffset,
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                );

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: offsetAnimation, child: child),
            );
          },
    );
  }

  List<String> _historySnapshotWithPending() {
    final List<TwoPlayerLifeEvent> events = List<TwoPlayerLifeEvent>.from(
      _twoPlayerLifeEvents,
    );
    if (_playerOnePendingDelta != 0) {
      events.add(
        TwoPlayerLifeEvent(
          player: 1,
          delta: _playerOnePendingDelta,
          resultingLife: _playerOneLp,
        ),
      );
    }
    if (_playerTwoPendingDelta != 0) {
      events.add(
        TwoPlayerLifeEvent(
          player: 2,
          delta: _playerTwoPendingDelta,
          resultingLife: _playerTwoLp,
        ),
      );
    }
    return _buildTwoPlayerHistoryTable(
      playerOneName: _playerName(1),
      playerTwoName: _playerName(2),
      initialPlayerOneLife: widget.initialLifePoints,
      initialPlayerTwoLife: widget.initialLifePoints,
      events: events,
    );
  }

  void _closeWithHistory({String matchResult = '', bool shouldSave = true}) {
    _diceRollTimer?.cancel();
    _diceResultTimer?.cancel();
    _cancelPendingTimer(1);
    _cancelPendingTimer(2);
    Navigator.of(context).pop(
      _buildDuelResultPayload(matchResult: matchResult, shouldSave: shouldSave),
    );
  }

  DuelResultPayload _buildDuelResultPayload({
    String matchResult = '',
    bool shouldSave = true,
    bool includeCurrentGameIfNeeded = true,
  }) {
    final String explicitMatchResult = matchResult.trim();
    final DuelCompletedGamePayload currentSnapshot = _buildCompletedGamePayload(
      matchResult: explicitMatchResult,
    );
    List<DuelCompletedGamePayload> gamesToSave =
        const <DuelCompletedGamePayload>[];
    if (shouldSave) {
      gamesToSave = List<DuelCompletedGamePayload>.from(
        _completedGamesForSession,
      );
      final bool includeCurrentGame =
          includeCurrentGameIfNeeded &&
          (explicitMatchResult.isNotEmpty || _hasActiveGameProgress());
      if (includeCurrentGame) {
        gamesToSave.add(currentSnapshot);
      }
    }
    final DuelCompletedGamePayload payloadSource = gamesToSave.isNotEmpty
        ? gamesToSave.last
        : currentSnapshot;
    return DuelResultPayload(
      lifePointHistory: List<String>.from(payloadSource.lifePointHistory),
      gameStage: payloadSource.gameStage,
      opponentName: payloadSource.opponentName,
      deckId: payloadSource.deckId,
      deckName: payloadSource.deckName,
      opponentDeckId: payloadSource.opponentDeckId,
      opponentDeckName: payloadSource.opponentDeckName,
      matchFormat: payloadSource.matchFormat,
      matchTag: payloadSource.matchTag,
      matchResult: payloadSource.matchResult,
      playerCount: 2,
      shouldSave: shouldSave && gamesToSave.isNotEmpty,
      completedGames: gamesToSave,
      createdDecks: List<SideboardDeck>.from(_createdDecksForSession),
      matchId: _currentMatchId,
      matchName: _matchName.trim(),
    );
  }

  Future<void> _openCalculatorForPlayer(int player) async {
    String customInput = '';
    bool isAddMode = false;
    final placement = _calculatorPlacementFor(player);

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close calculator',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (BuildContext context, _, _) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Align(
              alignment: placement.alignment,
              child: FractionallySizedBox(
                widthFactor: placement.widthFactor,
                heightFactor: placement.heightFactor,
                child: StatefulBuilder(
                  builder: (BuildContext context, StateSetter setModalState) {
                    final String sign = isAddMode ? '+' : '-';

                    void appendDigit(String digit) {
                      setModalState(() {
                        if (customInput.length >= 5) {
                          return;
                        }
                        if (customInput == '0') {
                          customInput = digit;
                          return;
                        }
                        customInput += digit;
                      });
                    }

                    void clearInput() {
                      setModalState(() {
                        customInput = '';
                      });
                    }

                    void applyInput() {
                      final int value = int.tryParse(customInput) ?? 0;
                      if (value == 0) {
                        return;
                      }
                      _changeLp(
                        player: player,
                        amount: value,
                        addMode: isAddMode,
                      );
                      Navigator.of(context).pop();
                    }

                    return RotatedBox(
                      quarterTurns: placement.quarterTurns,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: double.infinity),
                        child: Material(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${_playerName(player)} calculator',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    FilledButton.tonal(
                                      onPressed: () {
                                        setModalState(() {
                                          isAddMode = !isAddMode;
                                        });
                                      },
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            widget.settings.buttonColor,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 8,
                                        ),
                                      ),
                                      child: Text(
                                        '+/- ($sign)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0E0E0E),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.12,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    '$sign ${customInput.isEmpty ? '0' : customInput}',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: LayoutBuilder(
                                    builder:
                                        (
                                          BuildContext context,
                                          BoxConstraints constraints,
                                        ) {
                                          const double spacing = 8;
                                          final double gridWidth = max(
                                            0,
                                            constraints.maxWidth - spacing * 2,
                                          );
                                          final double gridHeight = max(
                                            0,
                                            constraints.maxHeight - spacing * 3,
                                          );
                                          final double tileWidth =
                                              gridWidth / 3;
                                          final double tileHeight = max(
                                            44,
                                            gridHeight / 4,
                                          );
                                          final double aspectRatio =
                                              tileHeight == 0
                                              ? 1
                                              : tileWidth / tileHeight;

                                          return GridView.count(
                                            padding: EdgeInsets.zero,
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            crossAxisCount: 3,
                                            crossAxisSpacing: spacing,
                                            mainAxisSpacing: spacing,
                                            childAspectRatio: aspectRatio,
                                            children: [
                                              for (final String key in [
                                                '1',
                                                '2',
                                                '3',
                                                '4',
                                                '5',
                                                '6',
                                                '7',
                                                '8',
                                                '9',
                                                'C',
                                                '0',
                                                '=',
                                              ])
                                                FilledButton.tonal(
                                                  onPressed: () {
                                                    if (key == 'C') {
                                                      clearInput();
                                                      return;
                                                    }
                                                    if (key == '=') {
                                                      applyInput();
                                                      return;
                                                    }
                                                    appendDigit(key);
                                                  },
                                                  style: FilledButton.styleFrom(
                                                    backgroundColor: key == '='
                                                        ? const Color(
                                                            0xFFB71C1C,
                                                          )
                                                        : widget
                                                              .settings
                                                              .buttonColor,
                                                    foregroundColor: key == '='
                                                        ? Colors.white
                                                        : null,
                                                    padding: EdgeInsets.zero,
                                                  ),
                                                  child: Text(
                                                    key,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          );
                                        },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> _,
            Widget child,
          ) {
            final Animation<Offset> offsetAnimation =
                Tween<Offset>(
                  begin: placement.beginOffset,
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                );

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: offsetAnimation, child: child),
            );
          },
    );
  }

  Future<void> _openMatchDetailsEditor() async {
    await showInfoTipOnce(
      context: context,
      tipId: InfoTipIds.opponentDeckSelection,
      titleKey: 'info.opponentDeck.title',
      bodyKey: 'info.opponentDeck.body',
      icon: Icons.arrow_drop_down_circle_outlined,
    );
    if (!mounted) {
      return;
    }
    final TextEditingController matchNameController = TextEditingController(
      text: _matchName,
    );
    final TextEditingController opponentController = TextEditingController(
      text: _opponentName,
    );
    final TextEditingController tagController = TextEditingController(
      text: _matchTag,
    );
    String stage = _selectedGameStage;
    String selectedDeckId = _selectedDeckIdForHistory();
    if (selectedDeckId.isEmpty && _deckInUse.trim().isNotEmpty) {
      selectedDeckId = _deckByName(_deckInUse)?.id ?? '';
    }
    if (selectedDeckId.isNotEmpty && _deckById(selectedDeckId) == null) {
      selectedDeckId = '';
    }
    String selectedFormat = _matchFormat.trim();
    String selectedOpponentDeckId = _selectedOpponentDeckIdForHistory();

    Future<String?> promptText({
      required String title,
      required String initialValue,
      required String hintText,
    }) async {
      return showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          return _TextPromptDialog(
            title: title,
            initialValue: initialValue,
            hintText: hintText,
            maxLines: 1,
          );
        },
      );
    }

    List<String> formatOptions() {
      final Set<String> unique = <String>{};
      for (final SideboardDeck deck in _sessionAvailableDecks) {
        final String format = deck.format.trim();
        if (format.isNotEmpty) {
          unique.add(format);
        }
      }
      if (selectedFormat.trim().isNotEmpty) {
        unique.add(selectedFormat.trim());
      }
      final List<String> sorted = unique.toList(growable: false);
      sorted.sort((String a, String b) {
        return a.toLowerCase().compareTo(b.toLowerCase());
      });
      return sorted;
    }

    List<SideboardDeck> deckOptions() {
      return _filterDecksByFormat(_sessionAvailableDecks, selectedFormat);
    }

    List<SideboardDeck> opponentDeckOptions() {
      return _filterDecksByFormat(_sessionAvailableDecks, selectedFormat);
    }

    void normalizeSelectedDeck() {
      if (selectedDeckId.isEmpty) {
        return;
      }
      final SideboardDeck? selectedDeck = _deckById(selectedDeckId);
      if (selectedDeck == null ||
          !_deckMatchesFormat(selectedDeck, selectedFormat)) {
        selectedDeckId = '';
      }
    }

    void normalizeSelectedOpponentDeck() {
      if (selectedOpponentDeckId.isEmpty) {
        return;
      }
      final SideboardDeck? selectedOpponentDeck = _deckById(
        selectedOpponentDeckId,
      );
      if (selectedOpponentDeck == null) {
        selectedOpponentDeckId = '';
        return;
      }
      if (!_deckMatchesFormat(selectedOpponentDeck, selectedFormat)) {
        selectedOpponentDeckId = '';
      }
    }

    if (selectedOpponentDeckId.isEmpty &&
        _opponentDeckInUse.trim().isNotEmpty) {
      selectedOpponentDeckId = _deckByName(_opponentDeckInUse)?.id ?? '';
    }
    normalizeSelectedDeck();
    normalizeSelectedOpponentDeck();

    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(context.txt.t('dialog.matchDetails')),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: matchNameController,
                      decoration: InputDecoration(
                        labelText: context.txt.t('field.matchName'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: opponentController,
                      decoration: InputDecoration(
                        labelText: context.txt.t('field.opponentName'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedFormat,
                      decoration: InputDecoration(
                        labelText: context.txt.t('field.format'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(
                          value: '',
                          child: Text(context.txt.t('field.noFormat')),
                        ),
                        ...formatOptions().map((String format) {
                          return DropdownMenuItem<String>(
                            value: format,
                            child: Text(format),
                          );
                        }),
                        DropdownMenuItem<String>(
                          value: '__add_format__',
                          child: Text(context.txt.t('field.addNewFormat')),
                        ),
                      ],
                      onChanged: (String? value) async {
                        if (value == null) {
                          return;
                        }
                        if (value == '__add_format__') {
                          final String? created = await promptText(
                            title: 'New format',
                            initialValue: '',
                            hintText: 'Modern, Edison, Commander...',
                          );
                          if (created == null) {
                            return;
                          }
                          final String trimmed = created.trim();
                          if (trimmed.isEmpty) {
                            return;
                          }
                          setDialogState(() {
                            selectedFormat = trimmed;
                            normalizeSelectedDeck();
                            normalizeSelectedOpponentDeck();
                          });
                          return;
                        }
                        setDialogState(() {
                          selectedFormat = value.trim();
                          normalizeSelectedDeck();
                          normalizeSelectedOpponentDeck();
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedOpponentDeckId,
                      decoration: InputDecoration(
                        labelText: context.txt.t('field.opponentDeck'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(
                          value: '',
                          child: Text(context.txt.t('field.noOpponentDeck')),
                        ),
                        ...opponentDeckOptions().map((SideboardDeck deck) {
                          return DropdownMenuItem<String>(
                            value: deck.id,
                            child: Text(
                              deck.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                        const DropdownMenuItem<String>(
                          value: '__add_opponent_deck__',
                          child: Text('Add new deck...'),
                        ),
                      ],
                      onChanged: (String? value) async {
                        if (value == null) {
                          return;
                        }
                        if (value == '__add_opponent_deck__') {
                          final String? createdName = await promptText(
                            title: 'New opponent deck',
                            initialValue: '',
                            hintText: 'Deck name',
                          );
                          if (createdName == null) {
                            return;
                          }
                          final String trimmedName = createdName.trim();
                          if (trimmedName.isEmpty) {
                            return;
                          }
                          final SideboardDeck? existing = _deckByName(
                            trimmedName,
                          );
                          if (existing != null) {
                            setDialogState(() {
                              selectedOpponentDeckId = existing.id;
                              normalizeSelectedOpponentDeck();
                            });
                            return;
                          }
                          final SideboardDeck newDeck = SideboardDeck(
                            id: DateTime.now().microsecondsSinceEpoch
                                .toString(),
                            name: trimmedName,
                            createdAt: DateTime.now(),
                            isFavorite: false,
                            userNotes: '',
                            matchups: const <SideboardMatchup>[],
                            format: selectedFormat.trim(),
                            tag: '',
                            tcgKey: _isMtgRules
                                ? SupportedTcg.mtg.storageKey
                                : SupportedTcg.yugioh.storageKey,
                          );
                          setDialogState(() {
                            _sessionAvailableDecks = <SideboardDeck>[
                              newDeck,
                              ..._sessionAvailableDecks,
                            ];
                            _createdDecksForSession.add(newDeck);
                            selectedOpponentDeckId = newDeck.id;
                            normalizeSelectedOpponentDeck();
                          });
                          return;
                        }
                        setDialogState(() {
                          selectedOpponentDeckId = value.trim();
                          normalizeSelectedOpponentDeck();
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: tagController,
                      decoration: const InputDecoration(
                        labelText: 'Tag',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: stage,
                      decoration: const InputDecoration(
                        labelText: 'Game',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _supportedGameStages
                          .map((String item) {
                            return DropdownMenuItem<String>(
                              value: item,
                              child: Text(item),
                            );
                          })
                          .toList(growable: false),
                      onChanged: (String? value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() {
                          stage = value;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedDeckId,
                      decoration: InputDecoration(
                        labelText: context.txt.t('field.deckInUse'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(
                          value: '',
                          child: Text(context.txt.t('field.noDeck')),
                        ),
                        ...deckOptions().map((SideboardDeck deck) {
                          return DropdownMenuItem<String>(
                            value: deck.id,
                            child: Text(deck.name),
                          );
                        }),
                      ],
                      onChanged: (String? value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() {
                          selectedDeckId = value.trim();
                          if (selectedDeckId.isEmpty) {
                            return;
                          }
                          final SideboardDeck? linkedDeck = _deckById(
                            selectedDeckId,
                          );
                          if (linkedDeck != null &&
                              selectedFormat.trim().isEmpty &&
                              linkedDeck.format.trim().isNotEmpty) {
                            selectedFormat = linkedDeck.format.trim();
                          }
                          normalizeSelectedDeck();
                          normalizeSelectedOpponentDeck();
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.txt.t('common.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.txt.t('common.save')),
            ),
          ],
        );
      },
    );

    if (shouldSave != true) {
      _disposeTextControllersLater(<TextEditingController>[
        matchNameController,
        opponentController,
        tagController,
      ]);
      return;
    }

    if (!mounted) {
      _disposeTextControllersLater(<TextEditingController>[
        matchNameController,
        opponentController,
        tagController,
      ]);
      return;
    }

    setState(() {
      _matchName = matchNameController.text.trim();
      _opponentName = opponentController.text.trim();
      final SideboardDeck? selectedDeckObject = _deckById(selectedDeckId);
      final SideboardDeck? selectedOpponentDeck = _deckById(
        selectedOpponentDeckId,
      );
      _selectedOpponentDeckId = selectedOpponentDeck?.id ?? '';
      _opponentDeckInUse = selectedOpponentDeck?.name ?? '';
      _matchFormat = selectedFormat.trim();
      _matchTag = tagController.text.trim();
      if (_opponentName.isNotEmpty) {
        _lastCompletedOpponentName = _opponentName;
        _lastRecordedOpponentName = _opponentName;
      }
      _selectedDeckId = selectedDeckObject?.id ?? '';
      _deckInUse = selectedDeckObject?.name ?? '';
      _selectedGameStage = stage;
      if (stage == 'G1') {
        _bo3Wins = 0;
        _bo3Losses = 0;
      }
    });
    _disposeTextControllersLater(<TextEditingController>[
      matchNameController,
      opponentController,
      tagController,
    ]);
  }

  Future<void> _confirmReset({bool fromHome = false}) async {
    const Color resetColor = Color(0xFF232323);
    const Color saveExitColor = Color(0xFF244A67);
    const Color winColor = Color(0xFF163825);
    const Color lossColor = Color(0xFF4A1E1E);
    const Color drawColor = Color(0xFF4D4220);
    final String? action = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(context.txt.t('game.endOrResetMatch')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (fromHome) ...[
                FilledButton.tonal(
                  onPressed: () => Navigator.of(context).pop('save_exit'),
                  style: FilledButton.styleFrom(backgroundColor: saveExitColor),
                  child: Text(context.txt.t('game.saveAndExit')),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton.tonal(
                onPressed: () => Navigator.of(context).pop('sideboard'),
                style: FilledButton.styleFrom(
                  backgroundColor: widget.settings.buttonColor,
                ),
                child: Text(context.txt.t('game.sideboardGuide')),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () => Navigator.of(context).pop('reset'),
                style: FilledButton.styleFrom(backgroundColor: resetColor),
                child: Text(
                  fromHome
                      ? (_completedGamesForSession.isNotEmpty
                            ? context.txt.t('game.discardAndExit')
                            : context.txt.t('game.exitWithoutSaving'))
                      : context.txt.t('game.resetWithoutSaving'),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.of(context).pop('Win'),
                style: FilledButton.styleFrom(backgroundColor: winColor),
                child: Text(context.txt.t('game.win')),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.of(context).pop('Loss'),
                style: FilledButton.styleFrom(backgroundColor: lossColor),
                child: Text(context.txt.t('game.loss')),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.of(context).pop('Draw'),
                style: FilledButton.styleFrom(backgroundColor: drawColor),
                child: Text(context.txt.t('game.draw')),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.txt.t('common.cancel')),
            ),
          ],
        );
      },
    );

    if (action == null || !mounted) {
      return;
    }
    if (action == 'sideboard') {
      await _openSideboardGuideDialog();
      return;
    }
    if (action == 'save_exit') {
      _closeWithHistory();
      return;
    }
    if (action == 'Win' || action == 'Loss' || action == 'Draw') {
      _diceRollTimer?.cancel();
      _diceRollTimer = null;
      _diceResultTimer?.cancel();
      _diceResultTimer = null;
      _cancelPendingTimer(1);
      _cancelPendingTimer(2);

      setState(() {
        _completedGamesForSession.add(
          _buildCompletedGamePayload(matchResult: action),
        );
        final String completedOpponent = _opponentName.trim();
        if (completedOpponent.isNotEmpty) {
          _lastCompletedOpponentName = completedOpponent;
          _lastRecordedOpponentName = completedOpponent;
        }
        _advanceBo3AfterRestart(declaredResult: action);
        _playerOneLp = widget.initialLifePoints;
        _playerTwoLp = widget.initialLifePoints;
        _playerOneDie = null;
        _playerTwoDie = null;
        _isRollingDice = false;
        _diceRollTicks = 0;
        _showDiceResults = false;
        _playerOnePendingDelta = 0;
        _playerTwoPendingDelta = 0;
        for (final _MtgResourceCounter counter in _MtgResourceCounter.values) {
          _playerOneResourceCounters[counter] = 0;
          _playerTwoResourceCounters[counter] = 0;
        }
        for (final _MtgStatusCounter counter in _MtgStatusCounter.values) {
          _playerOneStatusCounters[counter] = 0;
          _playerTwoStatusCounters[counter] = 0;
        }
        _twoPlayerLifeEvents.clear();
      });
      final DuelResultPayload checkpointPayload = _buildDuelResultPayload(
        shouldSave: true,
        includeCurrentGameIfNeeded: false,
      );
      if (widget.onCheckpoint != null) {
        await widget.onCheckpoint!(checkpointPayload);
      }
      return;
    }
    if (action != 'reset') {
      return;
    }
    if (fromHome) {
      _closeWithHistory(shouldSave: false);
      return;
    }

    _diceRollTimer?.cancel();
    _diceRollTimer = null;
    _diceResultTimer?.cancel();
    _diceResultTimer = null;
    _cancelPendingTimer(1);
    _cancelPendingTimer(2);

    setState(() {
      _lastRecordedOpponentName = '';
      _advanceBo3AfterRestart();
      _playerOneLp = widget.initialLifePoints;
      _playerTwoLp = widget.initialLifePoints;
      _playerOneDie = null;
      _playerTwoDie = null;
      _isRollingDice = false;
      _diceRollTicks = 0;
      _showDiceResults = false;
      _playerOnePendingDelta = 0;
      _playerTwoPendingDelta = 0;
      for (final _MtgResourceCounter counter in _MtgResourceCounter.values) {
        _playerOneResourceCounters[counter] = 0;
        _playerTwoResourceCounters[counter] = 0;
      }
      for (final _MtgStatusCounter counter in _MtgStatusCounter.values) {
        _playerOneStatusCounters[counter] = 0;
        _playerTwoStatusCounters[counter] = 0;
      }
      _twoPlayerLifeEvents.clear();
    });
  }

  void _rollDice() {
    if (_isRollingDice) {
      return;
    }

    const int totalTicks = 12;
    const Duration tickDuration = Duration(milliseconds: 85);

    _diceRollTimer?.cancel();
    _diceResultTimer?.cancel();
    _diceResultTimer = null;
    setState(() {
      _isRollingDice = true;
      _diceRollTicks = 0;
      _showDiceResults = true;
      _playerOneDie = _nextDieValue(_random);
      _playerTwoDie = _nextDieValue(_random);
    });

    _diceRollTimer = Timer.periodic(tickDuration, (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      bool shouldStop = false;
      setState(() {
        _playerOneDie = _nextDieValue(_random);
        _playerTwoDie = _nextDieValue(_random);
        _diceRollTicks += 1;

        if (_diceRollTicks >= totalTicks) {
          _isRollingDice = false;
          shouldStop = true;
        }
      });
      if (shouldStop) {
        timer.cancel();
        _diceRollTimer = null;
        _scheduleDiceResultDismissal();
      }
    });
  }

  void _scheduleDiceResultDismissal() {
    _diceResultTimer?.cancel();
    _diceResultTimer = Timer(_diceResultVisibilityDuration, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _showDiceResults = false;
        _playerOneDie = null;
        _playerTwoDie = null;
      });
      _diceResultTimer = null;
    });
  }

  List<Alignment> _diePipAlignments(int value) {
    switch (value) {
      case 1:
        return const [Alignment.center];
      case 2:
        return const [Alignment.topLeft, Alignment.bottomRight];
      case 3:
        return const [
          Alignment.topLeft,
          Alignment.center,
          Alignment.bottomRight,
        ];
      case 4:
        return const [
          Alignment.topLeft,
          Alignment.topRight,
          Alignment.bottomLeft,
          Alignment.bottomRight,
        ];
      case 5:
        return const [
          Alignment.topLeft,
          Alignment.topRight,
          Alignment.center,
          Alignment.bottomLeft,
          Alignment.bottomRight,
        ];
      default:
        return const [
          Alignment.topLeft,
          Alignment.centerLeft,
          Alignment.bottomLeft,
          Alignment.topRight,
          Alignment.centerRight,
          Alignment.bottomRight,
        ];
    }
  }

  Widget _buildDieFace(
    int value, {
    required bool compact,
    required bool isRolling,
    bool prominent = false,
  }) {
    final double size = prominent ? (compact ? 36 : 44) : (compact ? 28 : 34);
    final double pipSize = prominent ? size * 0.16 : size * 0.145;
    final double inset = prominent ? size * 0.14 : size * 0.13;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isRolling ? const Color(0xFFFFE9B3) : const Color(0xFFEEEDED),
        borderRadius: BorderRadius.circular(prominent ? 12 : (compact ? 7 : 9)),
        border: Border.all(
          color: isRolling ? const Color(0xFFE7C061) : const Color(0xFFB0AFAF),
          width: prominent ? (isRolling ? 1.9 : 1.2) : (isRolling ? 1.6 : 1),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(inset),
        child: Stack(
          children: [
            for (final Alignment align in _diePipAlignments(value))
              Align(
                alignment: align,
                child: Container(
                  width: pipSize,
                  height: pipSize,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A1A1A),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedDieResult({required int value, required bool compact}) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1).animate(animation),
            child: child,
          ),
        );
      },
      child: !_showDiceResults
          ? const SizedBox.shrink(key: ValueKey<String>('dice-hidden'))
          : Container(
              key: ValueKey<String>(
                'dice-$value-${compact ? 'compact' : 'regular'}-${_isRollingDice ? 'rolling' : 'final'}',
              ),
              padding: EdgeInsets.all(compact ? 4 : 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(compact ? 14 : 18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: _buildDieFace(
                value,
                compact: compact,
                isRolling: _isRollingDice,
                prominent: true,
              ),
            ),
    );
  }

  Widget _buildPendingDeltaBadge({required int player, required bool compact}) {
    final int value = player == 1
        ? _playerOnePendingDelta
        : _playerTwoPendingDelta;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 140),
      transitionBuilder: (Widget child, Animation<double> animation) {
        final Animation<Offset> offset = Tween<Offset>(
          begin: const Offset(0, -0.2),
          end: Offset.zero,
        ).animate(animation);

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: value == 0
          ? const SizedBox.shrink(key: ValueKey<String>('empty-delta'))
          : Container(
              key: ValueKey<int>(value),
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 6 : 8,
                vertical: compact ? 2 : 3,
              ),
              decoration: BoxDecoration(
                color: value > 0
                    ? const Color(0xFF245D32)
                    : const Color(0xFF6A2323),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _formatSigned(value),
                style: TextStyle(
                  fontSize: compact ? 10 : 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
    );
  }

  Widget _buildQuickButton(int player, int delta, {bool compact = false}) {
    final bool isPositive = delta > 0;
    final double compactHeight = _isMtgRules ? 38 : 32;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FilledButton.tonal(
          onPressed: () => _applySignedDelta(player: player, delta: delta),
          style: FilledButton.styleFrom(
            minimumSize: Size.fromHeight(compact ? compactHeight : 46),
            backgroundColor: widget.settings.buttonColor,
          ),
          child: Text(
            '${isPositive ? '+' : ''}$delta',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: compact ? 13 : 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignedQuickButton(
    int player,
    int delta, {
    bool compact = false,
  }) {
    final bool isPositive = delta > 0;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FilledButton.tonal(
          onPressed: () => _applySignedDelta(player: player, delta: delta),
          style: FilledButton.styleFrom(
            minimumSize: Size.fromHeight(compact ? 34 : 40),
            backgroundColor: widget.settings.buttonColor,
          ),
          child: Text(
            '${isPositive ? '+' : ''}$delta',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: compact ? 13 : 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScaleButton(
    int player, {
    required bool addMode,
    bool compact = false,
  }) {
    final String label = addMode ? 'x2' : '1/2';
    final double compactHeight = _isMtgRules ? 38 : 32;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FilledButton.tonal(
          onPressed: () => _applyScaleAction(player: player, addMode: addMode),
          style: FilledButton.styleFrom(
            minimumSize: Size.fromHeight(compact ? compactHeight : 46),
            backgroundColor: widget.settings.buttonColor,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: compact ? 13 : 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInlineLpTapHint({
    required bool isPositive,
    required bool compact,
  }) {
    return Container(
      width: compact ? 28 : 32,
      height: compact ? 28 : 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: widget.settings.buttonColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        isPositive ? '+' : '-',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: compact ? 16 : 18,
        ),
      ),
    );
  }

  Widget _playerPanel({
    required int player,
    required int lifePoints,
    bool compact = false,
  }) {
    final bool isYugiohRules = !_isMtgRules;
    final bool isYugiohCompact = isYugiohRules && compact;
    final int? dieValue = player == 1 ? _playerOneDie : _playerTwoDie;
    final bool showDieResult = _showDiceResults && dieValue != null;
    final int dieResultValue = dieValue ?? 0;
    final int poisonCounters = _isMtgRules
        ? _poisonCountersForPlayer(player)
        : 0;
    final int experienceCounters = _isMtgRules
        ? _experienceCountersForPlayer(player)
        : 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: EdgeInsets.fromLTRB(
        compact ? 8 : 10,
        isYugiohRules ? (compact ? 4 : 8) : 10,
        compact ? 8 : 10,
        isYugiohCompact ? 4 : (compact ? 6 : 10),
      ),
      padding: EdgeInsets.fromLTRB(
        compact ? 10 : 14,
        isYugiohRules ? (compact ? 6 : 10) : (compact ? 10 : 14),
        compact ? 10 : 14,
        isYugiohCompact ? 6 : (compact ? 8 : 12),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF221818),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _playerName(player).toUpperCase(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.86),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      fontSize: compact ? 12 : 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Open history',
                    onPressed: () => _openHistoryForPlayer(player),
                    icon: Icon(
                      Icons.format_list_bulleted_rounded,
                      size: compact ? 16 : 18,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: widget.settings.buttonColor,
                      foregroundColor: Colors.white,
                      minimumSize: Size.square(compact ? 28 : 30),
                    ),
                  ),
                  if (_isMtgRules) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Open mana and storm counters',
                      onPressed: () =>
                          _openMtgResourceCountersForPlayer(player),
                      icon: Icon(
                        Icons.blur_circular_rounded,
                        size: compact ? 16 : 18,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: widget.settings.buttonColor,
                        foregroundColor: Colors.white,
                        minimumSize: Size.square(compact ? 28 : 30),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Open poison and experience counters',
                      onPressed: () => _openMtgStatusCountersForPlayer(player),
                      icon: Text(
                        '\u03A6',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: compact ? 13 : 15,
                        ),
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: widget.settings.buttonColor,
                        foregroundColor: Colors.white,
                        minimumSize: Size.square(compact ? 28 : 30),
                      ),
                    ),
                  ],
                ],
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Open calculator',
                onPressed: () => _openCalculatorForPlayer(player),
                icon: Icon(Icons.calculate_outlined, size: compact ? 18 : 20),
                style: IconButton.styleFrom(
                  backgroundColor: widget.settings.buttonColor,
                  foregroundColor: Colors.white,
                  minimumSize: Size.square(compact ? 30 : 34),
                ),
              ),
            ],
          ),
          if (_isMtgRules &&
              (poisonCounters > 0 || experienceCounters > 0)) ...[
            SizedBox(height: compact ? 4 : 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (poisonCounters > 0)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 8 : 10,
                        vertical: compact ? 3 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6A2323),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFFF8A8A)),
                      ),
                      child: Text(
                        'Poison counter: $poisonCounters',
                        style: TextStyle(
                          color: const Color(0xFFFFA3A3),
                          fontWeight: FontWeight.w700,
                          fontSize: compact ? 11 : 12,
                        ),
                      ),
                    ),
                  if (experienceCounters > 0)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 8 : 10,
                        vertical: compact ? 3 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF234A6A),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFF7AC7FF)),
                      ),
                      child: Text(
                        'Experience counter: $experienceCounters',
                        style: TextStyle(
                          color: const Color(0xFFBEE8FF),
                          fontWeight: FontWeight.w700,
                          fontSize: compact ? 11 : 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          SizedBox(height: compact ? (isYugiohRules ? 1 : 6) : 10),
          SizedBox(
            height: compact ? (isYugiohRules ? 146 : 96) : 126,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 10 : 12,
                      vertical: compact ? 6 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: player == 1
                          ? widget.settings.playerOneColor
                          : widget.settings.playerTwoColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: _isMtgRules
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () => _applySignedDelta(
                                              player: player,
                                              delta: -1,
                                            ),
                                            splashColor: Colors.white
                                                .withValues(alpha: 0.08),
                                            highlightColor: Colors.white
                                                .withValues(alpha: 0.03),
                                            child: const SizedBox.expand(),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () => _applySignedDelta(
                                              player: player,
                                              delta: 1,
                                            ),
                                            splashColor: Colors.white
                                                .withValues(alpha: 0.08),
                                            highlightColor: Colors.white
                                                .withValues(alpha: 0.03),
                                            child: const SizedBox.expand(),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Padding(
                                              padding: EdgeInsets.only(
                                                left: compact ? 6 : 8,
                                              ),
                                              child: _buildInlineLpTapHint(
                                                isPositive: false,
                                                compact: compact,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Align(
                                            alignment: Alignment.centerRight,
                                            child: Padding(
                                              padding: EdgeInsets.only(
                                                right: compact ? 6 : 8,
                                              ),
                                              child: _buildInlineLpTapHint(
                                                isPositive: true,
                                                compact: compact,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: Center(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: compact ? 44 : 52,
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            '$lifePoints',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: compact ? 52 : 70,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () => _applySignedDelta(
                                              player: player,
                                              delta: -100,
                                            ),
                                            splashColor: Colors.white
                                                .withValues(alpha: 0.08),
                                            highlightColor: Colors.white
                                                .withValues(alpha: 0.03),
                                            child: const SizedBox.expand(),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () => _applySignedDelta(
                                              player: player,
                                              delta: 100,
                                            ),
                                            splashColor: Colors.white
                                                .withValues(alpha: 0.08),
                                            highlightColor: Colors.white
                                                .withValues(alpha: 0.03),
                                            child: const SizedBox.expand(),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Padding(
                                              padding: EdgeInsets.only(
                                                left: compact ? 8 : 10,
                                              ),
                                              child: Text(
                                                '-100',
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.72),
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: compact ? 10 : 11,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Align(
                                            alignment: Alignment.centerRight,
                                            child: Padding(
                                              padding: EdgeInsets.only(
                                                right: compact ? 8 : 10,
                                              ),
                                              child: Text(
                                                '+100',
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.72),
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: compact ? 10 : 11,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: Center(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: compact ? 42 : 50,
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            '$lifePoints',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 320,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: compact ? 2 : 4,
                  child: _buildPendingDeltaBadge(
                    player: player,
                    compact: compact,
                  ),
                ),
                Positioned(
                  left: 0,
                  top: compact ? 2 : 4,
                  child: showDieResult
                      ? _buildAnimatedDieResult(
                          value: dieResultValue,
                          compact: compact,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          SizedBox(height: compact ? (isYugiohRules ? 2 : 6) : 10),
          if (_isMtgRules) ...[
            Row(
              children: [
                _buildSignedQuickButton(player, -10, compact: compact),
                _buildSignedQuickButton(player, 10, compact: compact),
              ],
            ),
          ] else ...[
            Row(
              children: [
                _buildQuickButton(player, -1000, compact: compact),
                _buildQuickButton(player, -100, compact: compact),
                _buildScaleButton(player, addMode: false, compact: compact),
              ],
            ),
            SizedBox(height: isYugiohCompact ? 3 : (compact ? 6 : 8)),
            Row(
              children: [
                _buildQuickButton(player, 1000, compact: compact),
                _buildQuickButton(player, 100, compact: compact),
                _buildScaleButton(player, addMode: true, compact: compact),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _centerControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Card(
        color: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              const double spacing = 8;
              const int buttonsCount = 5;
              final double buttonWidth =
                  ((constraints.maxWidth - spacing * (buttonsCount - 1)) /
                          buttonsCount)
                      .clamp(48.0, 70.0);
              final double controlsWidth =
                  buttonWidth * buttonsCount + spacing * (buttonsCount - 1);

              Widget controlButton({
                required VoidCallback? onPressed,
                required Widget child,
                Color? backgroundColor,
              }) {
                return SizedBox(
                  width: buttonWidth,
                  child: FilledButton.tonal(
                    onPressed: onPressed,
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          backgroundColor ?? widget.settings.buttonColor,
                      minimumSize: const Size.fromHeight(46),
                      padding: EdgeInsets.zero,
                    ),
                    child: Center(child: child),
                  ),
                );
              }

              return Center(
                child: SizedBox(
                  width: controlsWidth,
                  child: Row(
                    children: [
                      controlButton(
                        onPressed: () => _confirmReset(fromHome: true),
                        child: const Icon(Icons.home_outlined, size: 30),
                      ),
                      const SizedBox(width: spacing),
                      controlButton(
                        onPressed: _confirmReset,
                        child: const Icon(Icons.restart_alt, size: 30),
                      ),
                      const SizedBox(width: spacing),
                      controlButton(
                        onPressed: _openMatchDetailsEditor,
                        child: const Icon(Icons.edit_outlined, size: 30),
                      ),
                      const SizedBox(width: spacing),
                      controlButton(
                        onPressed: () {
                          unawaited(_openSideboardGuideDialog());
                        },
                        child: const Icon(Icons.menu_book_outlined, size: 30),
                      ),
                      const SizedBox(width: spacing),
                      controlButton(
                        onPressed: _isRollingDice ? null : _rollDice,
                        child: const Icon(Icons.casino_outlined, size: 30),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _splitLayout() {
    final bool forceCompact = !_isMtgRules;
    return Column(
      children: [
        Expanded(
          child: RotatedBox(
            quarterTurns: 2,
            child: _playerPanel(
              player: 2,
              lifePoints: _playerTwoLp,
              compact: forceCompact,
            ),
          ),
        ),
        _centerControls(),
        Expanded(
          child: _playerPanel(
            player: 1,
            lifePoints: _playerOneLp,
            compact: forceCompact,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color duelMiddle =
        Color.lerp(
          widget.settings.backgroundStartColor,
          widget.settings.backgroundEndColor,
          0.45,
        ) ??
        widget.settings.backgroundStartColor;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        _closeWithHistory();
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                widget.settings.backgroundStartColor,
                duelMiddle,
                widget.settings.backgroundEndColor,
              ],
            ),
          ),
          child: SafeArea(child: _splitLayout()),
        ),
      ),
    );
  }

  @override
  void dispose() {
    unawaited(WakelockPlus.disable());
    _diceRollTimer?.cancel();
    _playerOnePendingTimer?.cancel();
    _playerTwoPendingTimer?.cancel();
    super.dispose();
  }
}

class GameHistoryScreen extends StatefulWidget {
  const GameHistoryScreen({
    super.key,
    required this.records,
    required this.decks,
    required this.tcg,
  });

  final List<GameRecord> records;
  final List<SideboardDeck> decks;
  final SupportedTcg tcg;

  @override
  State<GameHistoryScreen> createState() => _GameHistoryScreenState();
}

class _GameHistoryScreenState extends State<GameHistoryScreen> {
  static const int _matchPageSize = 5;

  late List<GameRecord> _records;
  MatchHistorySortMode _matchHistorySortMode = MatchHistorySortMode.date;
  String _selectedMatchDeckFilter = '';
  String _selectedMatchOpponentDeckFilter = '';
  String _selectedMatchFormatFilter = '';
  String _selectedMatchTagFilter = '';
  late final ScrollController _matchListController;
  late final TextEditingController _opponentNameFilterController;
  int _visibleMatchCount = _matchPageSize;

  @override
  void initState() {
    super.initState();
    _matchListController = ScrollController();
    _opponentNameFilterController = TextEditingController();
    _records = List<GameRecord>.from(widget.records);
    _records.sort((GameRecord a, GameRecord b) {
      return b.createdAt.compareTo(a.createdAt);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        showInfoTipOnce(
          context: context,
          tipId: InfoTipIds.matchHistory,
          titleKey: 'info.matchHistory.title',
          bodyKey: 'info.matchHistory.body',
          icon: Icons.history_rounded,
        ),
      );
    });
  }

  void _loadMoreMatches(int totalMatches) {
    setState(() {
      _visibleMatchCount = min(
        totalMatches,
        _visibleMatchCount + _matchPageSize,
      );
    });
  }

  void _resetVisibleMatchCount() {
    _visibleMatchCount = _matchPageSize;
  }

  bool _isPersistedHistoryRecord(GameRecord record) {
    return record.lifePointHistory.isNotEmpty ||
        _normalizedMatchResultOrEmpty(record.matchResult).isNotEmpty;
  }

  void _closeWithResult() {
    Navigator.of(context).pop(_records);
  }

  bool get _hasActiveMatchFilters {
    return _selectedMatchDeckFilter.isNotEmpty ||
        _selectedMatchOpponentDeckFilter.isNotEmpty ||
        _selectedMatchFormatFilter.isNotEmpty ||
        _selectedMatchTagFilter.isNotEmpty ||
        _opponentNameFilterController.text.trim().isNotEmpty;
  }

  void _clearMatchFilters() {
    _opponentNameFilterController.clear();
    setState(() {
      _selectedMatchDeckFilter = '';
      _selectedMatchOpponentDeckFilter = '';
      _selectedMatchFormatFilter = '';
      _selectedMatchTagFilter = '';
      _resetVisibleMatchCount();
    });
  }

  @override
  void dispose() {
    _opponentNameFilterController.dispose();
    _matchListController.dispose();
    super.dispose();
  }

  bool get _isTwoPlayerHistoryOnly {
    return _records.isNotEmpty &&
        _records.every((GameRecord record) => record.playerCount == 2);
  }

  String _defaultMatchName(int number) {
    final String prefix = widget.tcg == SupportedTcg.mtg
        ? 'MTG Match'
        : 'Match';
    return '$prefix $number';
  }

  String _effectiveMatchId(GameRecord record) {
    final String rawMatchId = record.matchId.trim();
    if (rawMatchId.isNotEmpty) {
      return rawMatchId;
    }
    return 'legacy-${record.id}';
  }

  String _firstNonEmptyFromNewest(
    List<GameRecord> games,
    String Function(GameRecord game) pick,
  ) {
    for (int index = games.length - 1; index >= 0; index -= 1) {
      final String value = pick(games[index]).trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  String _matchDeckFilterValue({
    required String deckId,
    required String deckName,
  }) {
    final String trimmedId = deckId.trim();
    final String trimmedName = deckName.trim();
    if (trimmedId.isNotEmpty) {
      return 'id:$trimmedId';
    }
    if (trimmedName.isNotEmpty) {
      return 'name:${trimmedName.toLowerCase()}';
    }
    return '';
  }

  List<_FilterOption> _matchDeckOptions(
    List<MatchRecord> matches, {
    required bool opponentDeck,
  }) {
    final Map<String, String> values = <String, String>{};
    for (final MatchRecord match in matches) {
      final String deckId = opponentDeck
          ? match.metadata.opponentDeckId
          : match.metadata.deckId;
      final String deckName = opponentDeck
          ? match.metadata.opponentDeckName
          : match.metadata.deckName;
      final String value = _matchDeckFilterValue(
        deckId: deckId,
        deckName: deckName,
      );
      final String label = deckName.trim().isNotEmpty
          ? deckName.trim()
          : deckId.trim();
      if (value.isEmpty || label.isEmpty) {
        continue;
      }
      values.putIfAbsent(value, () => label);
    }
    final List<_FilterOption> options = values.entries
        .map(
          (MapEntry<String, String> entry) =>
              _FilterOption(value: entry.key, label: entry.value),
        )
        .toList(growable: false);
    options.sort(((_FilterOption a, _FilterOption b) {
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    }));
    return options;
  }

  List<String> _availableMatchFormats(List<MatchRecord> matches) {
    final Set<String> unique = <String>{};
    for (final MatchRecord match in matches) {
      final String format = match.metadata.format.trim();
      if (format.isEmpty) {
        continue;
      }
      unique.add(format);
    }
    final List<String> sorted = unique.toList(growable: false);
    sorted.sort((String a, String b) {
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
    return sorted;
  }

  bool _matchesDeckFilter(
    MatchRecord match,
    String selectedValue, {
    required bool opponentDeck,
  }) {
    final String trimmedValue = selectedValue.trim();
    if (trimmedValue.isEmpty) {
      return true;
    }
    final String value = _matchDeckFilterValue(
      deckId: opponentDeck
          ? match.metadata.opponentDeckId
          : match.metadata.deckId,
      deckName: opponentDeck
          ? match.metadata.opponentDeckName
          : match.metadata.deckName,
    );
    return value == trimmedValue;
  }

  List<MatchRecord> _filteredMatchRecords(
    List<MatchRecord> matches, {
    required String selectedDeckFilter,
    required String selectedOpponentDeckFilter,
    required String selectedFormatFilter,
    required String selectedTagFilter,
    required String opponentQuery,
  }) {
    final String normalizedFormat = selectedFormatFilter.trim().toLowerCase();
    final String normalizedTag = selectedTagFilter.trim().toLowerCase();
    final String normalizedOpponentQuery = opponentQuery.trim().toLowerCase();

    return matches
        .where((MatchRecord match) {
          if (!_matchesDeckFilter(
            match,
            selectedDeckFilter,
            opponentDeck: false,
          )) {
            return false;
          }
          if (!_matchesDeckFilter(
            match,
            selectedOpponentDeckFilter,
            opponentDeck: true,
          )) {
            return false;
          }
          if (normalizedFormat.isNotEmpty &&
              match.metadata.format.trim().toLowerCase() != normalizedFormat) {
            return false;
          }
          if (normalizedTag.isNotEmpty &&
              match.metadata.tag.trim().toLowerCase() != normalizedTag) {
            return false;
          }
          if (normalizedOpponentQuery.isNotEmpty &&
              !match.metadata.opponentName.trim().toLowerCase().contains(
                normalizedOpponentQuery,
              )) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  List<MatchRecord> _twoPlayerMatchRecords() {
    final List<GameRecord> twoPlayerRecords = _records
        .where(
          (GameRecord record) =>
              record.playerCount == 2 && _isPersistedHistoryRecord(record),
        )
        .toList(growable: false);
    if (twoPlayerRecords.isEmpty) {
      return const <MatchRecord>[];
    }

    final Map<String, List<GameRecord>> grouped = <String, List<GameRecord>>{};
    for (final GameRecord record in twoPlayerRecords) {
      final String matchId = _effectiveMatchId(record);
      grouped.putIfAbsent(matchId, () => <GameRecord>[]).add(record);
    }

    final List<MapEntry<String, List<GameRecord>>> groupedEntries = grouped
        .entries
        .toList(growable: false);
    groupedEntries.sort((
      MapEntry<String, List<GameRecord>> a,
      MapEntry<String, List<GameRecord>> b,
    ) {
      final DateTime aCreated = a.value
          .map((GameRecord record) => record.createdAt)
          .reduce(
            (DateTime first, DateTime next) =>
                first.isBefore(next) ? first : next,
          );
      final DateTime bCreated = b.value
          .map((GameRecord record) => record.createdAt)
          .reduce(
            (DateTime first, DateTime next) =>
                first.isBefore(next) ? first : next,
          );
      return aCreated.compareTo(bCreated);
    });

    final List<MatchRecord> matches = <MatchRecord>[];
    int fallbackNumber = 0;
    for (final MapEntry<String, List<GameRecord>> entry in groupedEntries) {
      final List<GameRecord> games = List<GameRecord>.from(entry.value);
      games.sort((GameRecord a, GameRecord b) {
        final int byStage = _gameStageSortKey(
          a.gameStage,
        ).compareTo(_gameStageSortKey(b.gameStage));
        if (byStage != 0) {
          return byStage;
        }
        return a.createdAt.compareTo(b.createdAt);
      });
      fallbackNumber += 1;

      String matchName = '';
      for (final GameRecord game in games) {
        final String candidate = game.matchName.trim();
        if (candidate.isNotEmpty) {
          matchName = candidate;
          break;
        }
      }
      if (matchName.isEmpty) {
        matchName = _defaultMatchName(fallbackNumber);
      }

      final DateTime createdAt = games
          .map((GameRecord record) => record.createdAt)
          .reduce(
            (DateTime first, DateTime next) =>
                first.isBefore(next) ? first : next,
          );
      final DateTime updatedAt = games
          .map((GameRecord record) => record.createdAt)
          .reduce(
            (DateTime first, DateTime next) =>
                first.isAfter(next) ? first : next,
          );
      final String opponent = _firstNonEmptyFromNewest(games, (
        GameRecord game,
      ) {
        final String rawOpponent = game.opponentName.trim();
        if (rawOpponent.isNotEmpty) {
          return rawOpponent;
        }
        return game.playerTwoName.trim();
      });
      final String deckId = _firstNonEmptyFromNewest(
        games,
        (GameRecord game) => _resolvedDeckId(game),
      );
      final String deckName = _firstNonEmptyFromNewest(
        games,
        (GameRecord game) => _resolvedDeckName(game),
      );
      final String opponentDeckId = _firstNonEmptyFromNewest(
        games,
        (GameRecord game) => _resolvedOpponentDeckId(game),
      );
      final String opponentDeckName = _firstNonEmptyFromNewest(
        games,
        (GameRecord game) => _resolvedOpponentDeckName(game),
      );
      final String matchFormat = _firstNonEmptyFromNewest(
        games,
        (GameRecord game) => game.matchFormat.trim(),
      );
      final String tag = _firstNonEmptyFromNewest(
        games,
        (GameRecord game) => game.matchTag.trim(),
      );
      final MatchMetadata metadata = MatchMetadata(
        name: matchName,
        opponentName: opponent,
        deckId: deckId,
        deckName: deckName,
        opponentDeckId: opponentDeckId,
        opponentDeckName: opponentDeckName,
        format: matchFormat,
        tag: tag,
      );

      matches.add(
        MatchRecord(
          id: entry.key,
          tcgKey: widget.tcg.storageKey,
          metadata: metadata,
          createdAt: createdAt,
          updatedAt: updatedAt,
          games: games,
          aggregateResult: _aggregateMatchResultFromGames(games),
        ),
      );
    }

    matches.sort((MatchRecord a, MatchRecord b) {
      return b.createdAt.compareTo(a.createdAt);
    });
    return matches;
  }

  List<MatchRecord> _sortedMatchRecords(List<MatchRecord> matches) {
    final List<MatchRecord> sorted = List<MatchRecord>.from(matches);
    switch (_matchHistorySortMode) {
      case MatchHistorySortMode.date:
        sorted.sort((MatchRecord a, MatchRecord b) {
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
      case MatchHistorySortMode.name:
        sorted.sort((MatchRecord a, MatchRecord b) {
          return a.metadata.name.toLowerCase().compareTo(
            b.metadata.name.toLowerCase(),
          );
        });
        break;
    }
    return sorted;
  }

  Future<void> _openMatchGroup(MatchRecord match) async {
    final List<GameRecord>? updatedGames = await Navigator.of(context)
        .push<List<GameRecord>>(
          MaterialPageRoute<List<GameRecord>>(
            builder: (_) => _TwoPlayerMatchDetailScreen(
              tcg: widget.tcg,
              decks: widget.decks,
              match: match,
            ),
          ),
        );
    if (updatedGames == null) {
      return;
    }

    final Set<String> oldIds = match.games
        .map((GameRecord record) => record.id)
        .toSet();
    setState(() {
      _records = _records
          .where((GameRecord record) => !oldIds.contains(record.id))
          .toList(growable: false);
      _records = <GameRecord>[...updatedGames, ..._records];
      _records.sort((GameRecord a, GameRecord b) {
        return b.createdAt.compareTo(a.createdAt);
      });
    });
  }

  Future<String?> _promptText({
    required String title,
    required String initialValue,
    required String hintText,
    int maxLines = 1,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return _TextPromptDialog(
          title: title,
          initialValue: initialValue,
          hintText: hintText,
          maxLines: maxLines,
        );
      },
    );
  }

  void _updateRecord(GameRecord updatedRecord) {
    final int index = _records.indexWhere(
      (GameRecord record) => record.id == updatedRecord.id,
    );
    if (index < 0) {
      return;
    }
    setState(() {
      _records[index] = updatedRecord;
    });
  }

  SideboardDeck? _deckById(String deckId) {
    if (deckId.isEmpty) {
      return null;
    }
    for (final SideboardDeck deck in widget.decks) {
      if (deck.id == deckId) {
        return deck;
      }
    }
    return null;
  }

  SideboardDeck? _deckByName(String deckName) {
    return _findUniqueDeckByName(widget.decks, deckName);
  }

  String _resolvedDeckName(GameRecord record) {
    final SideboardDeck? linkedDeck = _deckById(record.deckId);
    if (linkedDeck != null) {
      return linkedDeck.name;
    }
    return record.deckName.trim();
  }

  String _resolvedDeckId(GameRecord record) {
    final String currentId = record.deckId.trim();
    if (currentId.isNotEmpty && _deckById(currentId) != null) {
      return currentId;
    }
    final SideboardDeck? linked = _deckByName(record.deckName);
    return linked?.id ?? '';
  }

  String _resolvedOpponentDeckName(GameRecord record) {
    final SideboardDeck? linkedDeck = _deckById(record.opponentDeckId);
    if (linkedDeck != null) {
      return linkedDeck.name;
    }
    return record.opponentDeckName.trim();
  }

  String _resolvedOpponentDeckId(GameRecord record) {
    final String currentId = record.opponentDeckId.trim();
    if (currentId.isNotEmpty && _deckById(currentId) != null) {
      return currentId;
    }
    final SideboardDeck? linked = _deckByName(record.opponentDeckName);
    return linked?.id ?? '';
  }

  String _selectedMatchResult(GameRecord record) {
    return _normalizedMatchResultOrEmpty(record.matchResult);
  }

  Color _matchResultBackgroundColor(String result) {
    if (result == 'Win') {
      return const Color(0xFF245D32);
    }
    if (result == 'Loss') {
      return const Color(0xFF6A2323);
    }
    if (result == 'Draw') {
      return const Color(0xFF665825);
    }
    return const Color(0xFF2B2424);
  }

  Color _matchResultTextColor(String result) {
    if (result == 'Win') {
      return const Color(0xFFB8FFCC);
    }
    if (result == 'Loss') {
      return const Color(0xFFFFC4C4);
    }
    if (result == 'Draw') {
      return const Color(0xFFFFEEAA);
    }
    return Colors.white.withValues(alpha: 0.86);
  }

  Future<void> _editMatchDetails(GameRecord record) async {
    final TextEditingController opponentController = TextEditingController(
      text: record.opponentName,
    );
    String selectedDeckId = _resolvedDeckId(record);
    String stage = _supportedGameStages.contains(record.gameStage)
        ? record.gameStage
        : 'G1';
    String result = _selectedMatchResult(record);

    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(context.txt.t('dialog.matchDetails')),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: opponentController,
                      decoration: const InputDecoration(
                        labelText: 'Opponent',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedDeckId,
                      decoration: const InputDecoration(
                        labelText: 'Deck',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(
                          value: '',
                          child: Text(context.txt.t('field.noDeck')),
                        ),
                        ...widget.decks.map((SideboardDeck deck) {
                          return DropdownMenuItem<String>(
                            value: deck.id,
                            child: Text(
                              deck.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                      onChanged: (String? nextValue) {
                        setDialogState(() {
                          selectedDeckId = (nextValue ?? '').trim();
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: stage,
                      decoration: const InputDecoration(
                        labelText: 'Game',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _supportedGameStages
                          .map((String item) {
                            return DropdownMenuItem<String>(
                              value: item,
                              child: Text(item),
                            );
                          })
                          .toList(growable: false),
                      onChanged: (String? nextValue) {
                        if (nextValue == null) {
                          return;
                        }
                        setDialogState(() {
                          stage = nextValue;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: result.isEmpty ? null : result,
                      decoration: const InputDecoration(
                        labelText: 'Result',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: <DropdownMenuItem<String>>[
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('No result'),
                        ),
                        ..._supportedMatchResults.map((String item) {
                          return DropdownMenuItem<String>(
                            value: item,
                            child: Text(item),
                          );
                        }),
                      ],
                      onChanged: (String? nextValue) {
                        setDialogState(() {
                          result = (nextValue ?? '').trim();
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.txt.t('common.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.txt.t('common.save')),
            ),
          ],
        );
      },
    );

    if (shouldSave != true) {
      _disposeTextControllersLater(<TextEditingController>[opponentController]);
      return;
    }

    final SideboardDeck? selectedDeck = _deckById(selectedDeckId);

    _updateRecord(
      record.copyWith(
        opponentName: opponentController.text.trim(),
        playerTwoName: opponentController.text.trim().isEmpty
            ? record.playerTwoName
            : opponentController.text.trim(),
        deckId: selectedDeck?.id ?? '',
        deckName: selectedDeck?.name ?? '',
        gameStage: stage,
        matchResult: result,
      ),
    );
    _disposeTextControllersLater(<TextEditingController>[opponentController]);
  }

  String _buildHistoryExportText() {
    final List<Map<String, Object>> serializedRecords = _records
        .map((GameRecord record) {
          return record
              .copyWith(
                tcgKey: widget.tcg.storageKey,
                deckName: _resolvedDeckName(record),
                opponentDeckName: _resolvedOpponentDeckName(record),
              )
              .toJson();
        })
        .toList(growable: false);

    final Map<String, Object> payload = <String, Object>{
      'schema': _historyExportSchema,
      'exportedAt': DateTime.now().toIso8601String(),
      'tcg': widget.tcg.storageKey,
      'records': serializedRecords,
    };

    return '$_historyExportSchema\n'
        '${const JsonEncoder.withIndent('  ').convert(payload)}';
  }

  List<GameRecord> _parseHistoryImportText(String rawText) {
    String payloadText = rawText.trim();
    if (payloadText.isEmpty) {
      throw const FormatException('Empty input');
    }

    if (payloadText.startsWith(_historyExportSchema)) {
      payloadText = payloadText.substring(_historyExportSchema.length).trim();
    }

    final dynamic decoded = jsonDecode(payloadText);
    if (decoded is! Map) {
      throw const FormatException('Invalid history payload');
    }
    final Map<String, dynamic> payload = Map<String, dynamic>.from(decoded);
    final String? payloadTcgKey = _supportedTcgKeyOrNull(payload['tcg']);
    if (payload['tcg'] != null && payloadTcgKey == null) {
      throw const FormatException(
        'Import failed. Unsupported game in history file.',
      );
    }
    if (payloadTcgKey != null && payloadTcgKey != widget.tcg.storageKey) {
      final String tcgLabel = SupportedTcgX.fromStorageKey(payloadTcgKey).label;
      throw FormatException(
        'This history file belongs to $tcgLabel. Import it from that game history.',
      );
    }
    final Object? rawRecords = payload['records'];
    if (rawRecords is! List) {
      throw const FormatException('Missing records list');
    }

    final List<GameRecord> imported = <GameRecord>[];
    for (final Object? entry in rawRecords) {
      if (entry is! Map) {
        continue;
      }
      final GameRecord parsed = GameRecord.fromJson(
        Map<String, dynamic>.from(entry),
      );
      imported.add(parsed.copyWith(tcgKey: widget.tcg.storageKey));
    }
    imported.sort((GameRecord a, GameRecord b) {
      return b.createdAt.compareTo(a.createdAt);
    });
    return imported;
  }

  Future<void> _exportHistoryTxt() async {
    final String exportText = _buildHistoryExportText();
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Export History (.txt)'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(
                exportText,
                style: const TextStyle(height: 1.35, fontFamily: 'monospace'),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: exportText));
                if (!context.mounted) {
                  return;
                }
                Navigator.of(context).pop();
                if (!mounted) {
                  return;
                }
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'History text copied. Save it as a .txt file.',
                    ),
                  ),
                );
              },
              child: const Text('Copy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _importHistoryTxt() async {
    final TextEditingController textController = TextEditingController();
    final bool? shouldImport = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Import History (.txt)'),
          content: SizedBox(
            width: double.maxFinite,
            child: TextField(
              controller: textController,
              maxLines: 14,
              minLines: 8,
              decoration: const InputDecoration(
                hintText: 'Paste exported .txt content here',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.txt.t('common.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Import'),
            ),
          ],
        );
      },
    );

    final String rawInput = textController.text.trim();
    _disposeTextControllersLater(<TextEditingController>[textController]);
    if (shouldImport != true || rawInput.isEmpty) {
      return;
    }

    try {
      final List<GameRecord> imported = _parseHistoryImportText(rawInput);
      if (imported.isEmpty) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid duel records found.')),
        );
        return;
      }

      setState(() {
        final Map<String, GameRecord> mergedById = <String, GameRecord>{
          for (final GameRecord record in _records) record.id: record,
        };
        for (final GameRecord record in imported) {
          mergedById[record.id] = record;
        }
        _records = mergedById.values.toList(growable: false);
        _records.sort((GameRecord a, GameRecord b) {
          return b.createdAt.compareTo(a.createdAt);
        });
      });

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${imported.length} duel(s) imported.')),
      );
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      final String message = error.message.trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message.isEmpty
                ? 'Import failed. Invalid .txt history format.'
                : message,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Import failed. Invalid .txt history format.'),
        ),
      );
    }
  }

  Future<void> _renameRecord(GameRecord record) async {
    final String? result = await _promptText(
      title: 'Rename game',
      initialValue: record.title,
      hintText: 'Game name',
    );
    if (result == null) {
      return;
    }

    final String trimmed = result.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _updateRecord(record.copyWith(title: trimmed));
  }

  Future<void> _editNotes(GameRecord record) async {
    final String? result = await _promptText(
      title: 'Edit notes',
      initialValue: record.notes,
      hintText: 'Write some notes...',
      maxLines: 6,
    );
    if (result == null) {
      return;
    }
    _updateRecord(record.copyWith(notes: result.trim()));
  }

  Future<void> _deleteRecord(GameRecord record) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete game'),
          content: Text('Delete "${record.title}" from history?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.txt.t('common.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (shouldDelete != true) {
      return;
    }

    setState(() {
      _records.removeWhere((GameRecord item) => item.id == record.id);
    });
  }

  void _createManualRecord() {
    final DateTime now = DateTime.now();
    final Set<String> twoPlayerMatchIds = _records
        .where((GameRecord record) => record.playerCount == 2)
        .map((GameRecord record) => _effectiveMatchId(record))
        .toSet();
    final String matchId = 'manual-match-${now.microsecondsSinceEpoch}';
    final String matchName = _defaultMatchName(twoPlayerMatchIds.length + 1);
    final GameRecord newRecord = GameRecord(
      id: now.microsecondsSinceEpoch.toString(),
      title:
          '${widget.tcg == SupportedTcg.mtg ? 'MTG Game' : 'Game'} ${_records.length + 1}',
      createdAt: now,
      gameStage: 'G1',
      notes: '',
      lifePointHistory: const <String>[],
      tcgKey: widget.tcg.storageKey,
      deckId: '',
      playerOneName: 'Player 1',
      playerTwoName: 'Player 2',
      playerCount: 2,
      matchId: matchId,
      matchName: matchName,
      opponentDeckId: '',
      opponentDeckName: '',
      matchTag: '',
    );

    setState(() {
      _records.insert(0, newRecord);
    });
  }

  Future<void> _showLifePointHistory(GameRecord record) async {
    final bool hasHistory = record.lifePointHistory.isNotEmpty;

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${record.title} - LP History'),
          content: SizedBox(
            width: double.maxFinite,
            child: hasHistory
                ? _buildLifeHistoryView(
                    lines: record.lifePointHistory,
                    playerCount: record.playerCount,
                    dividerColor: Colors.white.withValues(alpha: 0.14),
                  )
                : const Text('No life point history saved for this game yet.'),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  List<String> _availableMatchTags(List<MatchRecord> matches) {
    final Set<String> unique = <String>{};
    for (final MatchRecord match in matches) {
      final String tag = match.metadata.tag.trim();
      if (tag.isEmpty) {
        continue;
      }
      unique.add(tag);
    }
    final List<String> sorted = unique.toList(growable: false);
    sorted.sort((String a, String b) {
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
    return sorted;
  }

  Widget _buildAggregateResultBadge(MatchAggregateResult result) {
    final String label = _matchAggregateResultLabel(result);
    final Color bg = _matchResultBackgroundColor(label);
    final Color fg = _matchResultTextColor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildTwoPlayerMatchList() {
    final AppStrings txt = context.txt;
    final List<MatchRecord> allMatches = _twoPlayerMatchRecords();
    final List<_FilterOption> deckOptions = _matchDeckOptions(
      allMatches,
      opponentDeck: false,
    );
    final List<_FilterOption> opponentDeckOptions = _matchDeckOptions(
      allMatches,
      opponentDeck: true,
    );
    final List<String> availableFormats = _availableMatchFormats(allMatches);
    final List<String> availableTags = _availableMatchTags(allMatches);
    final String effectiveSelectedDeckFilter =
        deckOptions.any(
          (_FilterOption option) => option.value == _selectedMatchDeckFilter,
        )
        ? _selectedMatchDeckFilter
        : '';
    final String effectiveSelectedOpponentDeckFilter =
        opponentDeckOptions.any(
          (_FilterOption option) =>
              option.value == _selectedMatchOpponentDeckFilter,
        )
        ? _selectedMatchOpponentDeckFilter
        : '';
    final String effectiveSelectedFormatFilter =
        _selectedMatchFormatFilter.isNotEmpty &&
            availableFormats.contains(_selectedMatchFormatFilter)
        ? _selectedMatchFormatFilter
        : '';
    final String effectiveSelectedTagFilter =
        _selectedMatchTagFilter.isNotEmpty &&
            availableTags.contains(_selectedMatchTagFilter)
        ? _selectedMatchTagFilter
        : '';
    final List<MatchRecord> matches = _sortedMatchRecords(
      _filteredMatchRecords(
        allMatches,
        selectedDeckFilter: effectiveSelectedDeckFilter,
        selectedOpponentDeckFilter: effectiveSelectedOpponentDeckFilter,
        selectedFormatFilter: effectiveSelectedFormatFilter,
        selectedTagFilter: effectiveSelectedTagFilter,
        opponentQuery: _opponentNameFilterController.text,
      ),
    );
    if (matches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _hasActiveMatchFilters
                    ? txt.t('history.noMatchesWithFilters')
                    : txt.t('history.empty'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.74)),
              ),
              if (_hasActiveMatchFilters) ...[
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: _clearMatchFilters,
                  icon: const Icon(Icons.filter_alt_off_rounded),
                  label: Text(txt.t('history.clearFilters')),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final int visibleMatchCount = min(matches.length, _visibleMatchCount);
    final bool hasMoreMatches = visibleMatchCount < matches.length;

    return Column(
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
                    txt.t('history.sortBy'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<MatchHistorySortMode>(
                          initialValue: _matchHistorySortMode,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: <DropdownMenuItem<MatchHistorySortMode>>[
                            DropdownMenuItem<MatchHistorySortMode>(
                              value: MatchHistorySortMode.date,
                              child: Text(txt.t('history.byDate')),
                            ),
                            DropdownMenuItem<MatchHistorySortMode>(
                              value: MatchHistorySortMode.name,
                              child: Text(txt.t('history.byName')),
                            ),
                          ],
                          onChanged: (MatchHistorySortMode? mode) {
                            if (mode == null) {
                              return;
                            }
                            setState(() {
                              _matchHistorySortMode = mode;
                              _resetVisibleMatchCount();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.tonalIcon(
                        onPressed: _hasActiveMatchFilters
                            ? _clearMatchFilters
                            : null,
                        icon: const Icon(Icons.filter_alt_off_rounded),
                        label: Text(txt.t('history.clearFilters')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    txt.t('history.filters'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (deckOptions.isNotEmpty || opponentDeckOptions.isNotEmpty)
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: effectiveSelectedDeckFilter.isEmpty
                                ? null
                                : effectiveSelectedDeckFilter,
                            decoration: InputDecoration(
                              labelText: txt.t('field.deck'),
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: <DropdownMenuItem<String>>[
                              DropdownMenuItem<String>(
                                value: '',
                                child: Text(txt.t('history.allDecks')),
                              ),
                              ...deckOptions.map((_FilterOption option) {
                                return DropdownMenuItem<String>(
                                  value: option.value,
                                  child: Text(
                                    option.label,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }),
                            ],
                            onChanged: (String? value) {
                              setState(() {
                                _selectedMatchDeckFilter = (value ?? '').trim();
                                _resetVisibleMatchCount();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue:
                                effectiveSelectedOpponentDeckFilter.isEmpty
                                ? null
                                : effectiveSelectedOpponentDeckFilter,
                            decoration: InputDecoration(
                              labelText: txt.t('field.opponentDeck'),
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: <DropdownMenuItem<String>>[
                              DropdownMenuItem<String>(
                                value: '',
                                child: Text(txt.t('history.allOpponentDecks')),
                              ),
                              ...opponentDeckOptions.map((
                                _FilterOption option,
                              ) {
                                return DropdownMenuItem<String>(
                                  value: option.value,
                                  child: Text(
                                    option.label,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }),
                            ],
                            onChanged: (String? value) {
                              setState(() {
                                _selectedMatchOpponentDeckFilter = (value ?? '')
                                    .trim();
                                _resetVisibleMatchCount();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  if (deckOptions.isNotEmpty || opponentDeckOptions.isNotEmpty)
                    const SizedBox(height: 12),
                  if (availableFormats.isNotEmpty || availableTags.isNotEmpty)
                    Row(
                      children: [
                        if (availableFormats.isNotEmpty)
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue:
                                  effectiveSelectedFormatFilter.isEmpty
                                  ? null
                                  : effectiveSelectedFormatFilter,
                              decoration: InputDecoration(
                                labelText: txt.t('field.format'),
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: <DropdownMenuItem<String>>[
                                DropdownMenuItem<String>(
                                  value: '',
                                  child: Text(txt.t('history.allFormats')),
                                ),
                                ...availableFormats.map((String format) {
                                  return DropdownMenuItem<String>(
                                    value: format,
                                    child: Text(
                                      format,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }),
                              ],
                              onChanged: (String? value) {
                                setState(() {
                                  _selectedMatchFormatFilter = (value ?? '')
                                      .trim();
                                  _resetVisibleMatchCount();
                                });
                              },
                            ),
                          ),
                        if (availableFormats.isNotEmpty &&
                            availableTags.isNotEmpty)
                          const SizedBox(width: 12),
                        if (availableTags.isNotEmpty)
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: effectiveSelectedTagFilter.isEmpty
                                  ? null
                                  : effectiveSelectedTagFilter,
                              decoration: InputDecoration(
                                labelText: txt.t('field.tag'),
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: <DropdownMenuItem<String>>[
                                DropdownMenuItem<String>(
                                  value: '',
                                  child: Text(txt.t('history.allTags')),
                                ),
                                ...availableTags.map((String tag) {
                                  return DropdownMenuItem<String>(
                                    value: tag,
                                    child: Text(
                                      tag,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }),
                              ],
                              onChanged: (String? value) {
                                setState(() {
                                  _selectedMatchTagFilter = (value ?? '')
                                      .trim();
                                  _resetVisibleMatchCount();
                                });
                              },
                            ),
                          ),
                      ],
                    ),
                  if (availableFormats.isNotEmpty || availableTags.isNotEmpty)
                    const SizedBox(height: 12),
                  TextField(
                    controller: _opponentNameFilterController,
                    onChanged: (_) {
                      setState(() {
                        _resetVisibleMatchCount();
                      });
                    },
                    decoration: InputDecoration(
                      labelText: txt.t('history.opponentSearch'),
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon:
                          _opponentNameFilterController.text.trim().isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _opponentNameFilterController.clear();
                                setState(() {
                                  _resetVisibleMatchCount();
                                });
                              },
                              icon: const Icon(Icons.close_rounded),
                              tooltip: txt.t('common.clear'),
                            ),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _matchListController,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: visibleMatchCount + (hasMoreMatches ? 1 : 0),
            itemBuilder: (BuildContext context, int index) {
              if (index >= visibleMatchCount) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: FilledButton.tonal(
                      onPressed: () => _loadMoreMatches(matches.length),
                      child: Text(txt.t('common.loadMore')),
                    ),
                  ),
                );
              }
              final MatchRecord match = matches[index];
              final String opponentLabel = match.metadata.opponentName.isEmpty
                  ? '-'
                  : match.metadata.opponentName;
              final String deckLabel = match.metadata.deckName.isEmpty
                  ? '-'
                  : match.metadata.deckName;
              final String opponentDeckLabel =
                  match.metadata.opponentDeckName.isEmpty
                  ? '-'
                  : match.metadata.opponentDeckName;
              final String formatLabel = match.metadata.format.isEmpty
                  ? '-'
                  : match.metadata.format;
              final String tagLabel = match.metadata.tag.isEmpty
                  ? '-'
                  : match.metadata.tag;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                color: const Color(0xFF1E1B1B),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openMatchGroup(match),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                match.metadata.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildAggregateResultBadge(match.aggregateResult),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _formatDateTime(match.createdAt, context),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${txt.t('field.opponent')}: $opponentLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.84),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${txt.t('field.deck')}: $deckLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${txt.t('field.opponentDeck')}: $opponentDeckLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${txt.t('field.format')}: $formatLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${txt.t('field.tag')}: $tagLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          txt.t(
                            'field.gamesCount',
                            params: <String, Object?>{
                              'count': match.games.length,
                            },
                          ),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings txt = context.txt;
    final bool twoPlayerOnly = _isTwoPlayerHistoryOnly;
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
          title: Text(txt.t('history.title')),
          leading: IconButton(
            onPressed: _closeWithResult,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          actions: [
            IconButton(
              tooltip: txt.t('history.importTxt'),
              onPressed: _importHistoryTxt,
              icon: const Icon(Icons.upload_file_rounded),
            ),
            IconButton(
              tooltip: txt.t('history.exportTxt'),
              onPressed: _exportHistoryTxt,
              icon: const Icon(Icons.download_rounded),
            ),
            IconButton(
              tooltip: twoPlayerOnly
                  ? txt.t('history.addMatch')
                  : txt.t('history.addGame'),
              onPressed: _createManualRecord,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        body: _records.isEmpty
            ? Center(
                child: Text(
                  txt.t('history.empty'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.74)),
                ),
              )
            : twoPlayerOnly
            ? _buildTwoPlayerMatchList()
            : ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                itemCount: _records.length,
                itemBuilder: (BuildContext context, int index) {
                  final GameRecord record = _records[index];
                  final String dropdownValue =
                      _supportedGameStages.contains(record.gameStage)
                      ? record.gameStage
                      : 'G1';
                  final String selectedDeckId = _resolvedDeckId(record);
                  final String selectedResult = _selectedMatchResult(record);
                  final String opponentLabel =
                      record.opponentName.trim().isNotEmpty
                      ? record.opponentName.trim()
                      : (record.playerTwoName.trim().isNotEmpty
                            ? record.playerTwoName.trim()
                            : '-');
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    color: const Color(0xFF1E1B1B),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      record.title,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatDateTime(record.createdAt, context),
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              DropdownButton<String>(
                                value: dropdownValue,
                                items: _supportedGameStages
                                    .map((String stage) {
                                      return DropdownMenuItem<String>(
                                        value: stage,
                                        child: Text(stage),
                                      );
                                    })
                                    .toList(growable: false),
                                onChanged: (String? nextValue) {
                                  if (nextValue == null) {
                                    return;
                                  }
                                  _updateRecord(
                                    record.copyWith(gameStage: nextValue),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Opponent: $opponentLabel',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.84),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _matchResultBackgroundColor(
                                    selectedResult,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedResult.isEmpty
                                        ? null
                                        : selectedResult,
                                    hint: Text(
                                      'Result',
                                      style: TextStyle(
                                        color: _matchResultTextColor(''),
                                      ),
                                    ),
                                    dropdownColor: const Color(0xFF2B2424),
                                    style: TextStyle(
                                      color: _matchResultTextColor(
                                        selectedResult,
                                      ),
                                      fontWeight: FontWeight.w700,
                                    ),
                                    items: _supportedMatchResults
                                        .map((String result) {
                                          return DropdownMenuItem<String>(
                                            value: result,
                                            child: Text(
                                              result,
                                              style: TextStyle(
                                                color: _matchResultTextColor(
                                                  result,
                                                ),
                                              ),
                                            ),
                                          );
                                        })
                                        .toList(growable: false),
                                    onChanged: (String? nextResult) {
                                      if (nextResult == null) {
                                        return;
                                      }
                                      _updateRecord(
                                        record.copyWith(
                                          matchResult: nextResult,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: selectedDeckId,
                            decoration: const InputDecoration(
                              labelText: 'Deck',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: <DropdownMenuItem<String>>[
                              DropdownMenuItem<String>(
                                value: '',
                                child: Text(context.txt.t('field.noDeck')),
                              ),
                              ...widget.decks.map((SideboardDeck deck) {
                                return DropdownMenuItem<String>(
                                  value: deck.id,
                                  child: Text(
                                    deck.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }),
                            ],
                            onChanged: (String? deckId) {
                              if (deckId == null) {
                                return;
                              }
                              final SideboardDeck? linkedDeck = _deckById(
                                deckId,
                              );
                              _updateRecord(
                                record.copyWith(
                                  deckId: deckId,
                                  deckName: linkedDeck?.name ?? '',
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 6),
                          Text(
                            record.notes.trim().isEmpty
                                ? 'No notes'
                                : record.notes,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: record.notes.trim().isEmpty
                                  ? Colors.white.withValues(alpha: 0.5)
                                  : Colors.white.withValues(alpha: 0.88),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Wrap(
                                  spacing: 2,
                                  runSpacing: 2,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => _renameRecord(record),
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 16,
                                      ),
                                      label: Text(context.txt.t('common.rename')),
                                    ),
                                    TextButton.icon(
                                      onPressed: () => _editNotes(record),
                                      icon: const Icon(
                                        Icons.sticky_note_2_outlined,
                                        size: 16,
                                      ),
                                      label: Text(context.txt.t('common.notes')),
                                    ),
                                    TextButton.icon(
                                      onPressed: () =>
                                          _editMatchDetails(record),
                                      icon: const Icon(
                                        Icons.edit_note_rounded,
                                        size: 16,
                                      ),
                                      label: Text(context.txt.t('game.details')),
                                    ),
                                    TextButton.icon(
                                      onPressed: () =>
                                          _showLifePointHistory(record),
                                      icon: const Icon(
                                        Icons.format_list_bulleted_rounded,
                                        size: 16,
                                      ),
                                      label: Text(context.txt.t('game.lpHistory')),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Delete duel',
                                onPressed: () => _deleteRecord(record),
                                icon: const Icon(Icons.delete_outline_rounded),
                                color: const Color(0xFFFF8A8A),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _TwoPlayerMatchDetailScreen extends StatefulWidget {
  const _TwoPlayerMatchDetailScreen({
    required this.tcg,
    required this.decks,
    required this.match,
  });

  final SupportedTcg tcg;
  final List<SideboardDeck> decks;
  final MatchRecord match;

  @override
  State<_TwoPlayerMatchDetailScreen> createState() =>
      _TwoPlayerMatchDetailScreenState();
}

class _TwoPlayerMatchDetailScreenState
    extends State<_TwoPlayerMatchDetailScreen> {
  late List<GameRecord> _games;
  late MatchMetadata _metadata;

  @override
  void initState() {
    super.initState();
    final String initialName = widget.match.metadata.name.trim().isEmpty
        ? _defaultMatchName()
        : widget.match.metadata.name.trim();
    _metadata = widget.match.metadata.copyWith(name: initialName);
    _games = widget.match.games
        .map((GameRecord game) => _applyMetadataToGame(game))
        .toList(growable: false);
    _sortGames();
  }

  String _defaultMatchName() {
    return widget.tcg == SupportedTcg.mtg ? 'MTG Match' : 'Match';
  }

  void _sortGames() {
    _games.sort((GameRecord a, GameRecord b) {
      final int byStage = _gameStageSortKey(
        a.gameStage,
      ).compareTo(_gameStageSortKey(b.gameStage));
      if (byStage != 0) {
        return byStage;
      }
      return a.createdAt.compareTo(b.createdAt);
    });
  }

  void _closeWithResult() {
    final List<GameRecord> updated = _games
        .map((GameRecord game) => _applyMetadataToGame(game))
        .toList(growable: false);
    Navigator.of(context).pop(updated);
  }

  String _effectiveMatchName() {
    final String name = _metadata.name.trim();
    return name.isEmpty ? _defaultMatchName() : name;
  }

  GameRecord _applyMetadataToGame(GameRecord game) {
    final String opponent = _metadata.opponentName.trim();
    return game.copyWith(
      matchId: widget.match.id,
      matchName: _effectiveMatchName(),
      opponentName: opponent,
      playerTwoName: opponent.isEmpty ? 'Player 2' : opponent,
      deckId: _metadata.deckId.trim(),
      deckName: _metadata.deckName.trim(),
      opponentDeckId: _metadata.opponentDeckId.trim(),
      opponentDeckName: _metadata.opponentDeckName.trim(),
      matchFormat: _metadata.format.trim(),
      matchTag: _metadata.tag.trim(),
    );
  }

  Future<String?> _promptText({
    required String title,
    required String initialValue,
    required String hintText,
    int maxLines = 1,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return _TextPromptDialog(
          title: title,
          initialValue: initialValue,
          hintText: hintText,
          maxLines: maxLines,
        );
      },
    );
  }

  SideboardDeck? _deckById(String deckId) {
    final String trimmedId = deckId.trim();
    if (trimmedId.isEmpty) {
      return null;
    }
    for (final SideboardDeck deck in widget.decks) {
      if (deck.id == trimmedId) {
        return deck;
      }
    }
    return null;
  }

  SideboardDeck? _deckByName(String deckName) {
    return _findUniqueDeckByName(widget.decks, deckName);
  }

  String _selectedMatchResult(GameRecord record) {
    return _normalizedMatchResultOrEmpty(record.matchResult);
  }

  Color _matchResultBackgroundColor(String result) {
    if (result == 'Win') {
      return const Color(0xFF245D32);
    }
    if (result == 'Loss') {
      return const Color(0xFF6A2323);
    }
    if (result == 'Draw') {
      return const Color(0xFF665825);
    }
    return const Color(0xFF2B2424);
  }

  Color _matchResultTextColor(String result) {
    if (result == 'Win') {
      return const Color(0xFFB8FFCC);
    }
    if (result == 'Loss') {
      return const Color(0xFFFFC4C4);
    }
    if (result == 'Draw') {
      return const Color(0xFFFFEEAA);
    }
    return Colors.white.withValues(alpha: 0.86);
  }

  void _updateGame(GameRecord updatedGame) {
    final int index = _games.indexWhere(
      (GameRecord game) => game.id == updatedGame.id,
    );
    if (index < 0) {
      return;
    }
    setState(() {
      _games[index] = _applyMetadataToGame(updatedGame);
      _sortGames();
    });
  }

  void _applyMatchMetadata(MatchMetadata metadata) {
    final String normalizedName = metadata.name.trim().isEmpty
        ? _defaultMatchName()
        : metadata.name.trim();
    final MatchMetadata normalized = metadata.copyWith(name: normalizedName);
    setState(() {
      _metadata = normalized;
      _games = _games
          .map((GameRecord game) => _applyMetadataToGame(game))
          .toList(growable: false);
      _sortGames();
    });
  }

  Future<void> _openMatchEditor() async {
    await showInfoTipOnce(
      context: context,
      tipId: InfoTipIds.opponentDeckSelection,
      titleKey: 'info.opponentDeck.title',
      bodyKey: 'info.opponentDeck.body',
      icon: Icons.arrow_drop_down_circle_outlined,
    );
    if (!mounted) {
      return;
    }
    final TextEditingController matchNameController = TextEditingController(
      text: _effectiveMatchName(),
    );
    final TextEditingController opponentController = TextEditingController(
      text: _metadata.opponentName,
    );
    final TextEditingController tagController = TextEditingController(
      text: _metadata.tag,
    );
    String selectedDeckId = _metadata.deckId.trim();
    if (selectedDeckId.isEmpty && _metadata.deckName.trim().isNotEmpty) {
      selectedDeckId = _deckByName(_metadata.deckName)?.id ?? '';
    }
    if (selectedDeckId.isNotEmpty && _deckById(selectedDeckId) == null) {
      selectedDeckId = '';
    }
    String selectedFormat = _metadata.format.trim();
    String selectedOpponentDeckId = _metadata.opponentDeckId.trim();
    if (selectedOpponentDeckId.isEmpty &&
        _metadata.opponentDeckName.trim().isNotEmpty) {
      selectedOpponentDeckId =
          _deckByName(_metadata.opponentDeckName)?.id ?? '';
    }

    List<String> formatOptions() {
      final Set<String> formats = <String>{};
      for (final SideboardDeck deck in widget.decks) {
        final String format = deck.format.trim();
        if (format.isNotEmpty) {
          formats.add(format);
        }
      }
      for (final GameRecord game in _games) {
        final String format = game.matchFormat.trim();
        if (format.isNotEmpty) {
          formats.add(format);
        }
      }
      if (selectedFormat.trim().isNotEmpty) {
        formats.add(selectedFormat.trim());
      }
      final List<String> sorted = formats.toList(growable: false);
      sorted.sort((String a, String b) {
        return a.toLowerCase().compareTo(b.toLowerCase());
      });
      return sorted;
    }

    List<SideboardDeck> opponentDeckOptions() {
      return _filterDecksByFormat(widget.decks, selectedFormat);
    }

    List<SideboardDeck> deckOptions() {
      return _filterDecksByFormat(widget.decks, selectedFormat);
    }

    void normalizeSelectedDeck() {
      if (selectedDeckId.isEmpty) {
        return;
      }
      final SideboardDeck? selectedDeck = _deckById(selectedDeckId);
      if (selectedDeck == null ||
          !_deckMatchesFormat(selectedDeck, selectedFormat)) {
        selectedDeckId = '';
      }
    }

    void normalizeSelectedOpponentDeck() {
      if (selectedOpponentDeckId.isEmpty) {
        return;
      }
      final SideboardDeck? selectedOpponentDeck = _deckById(
        selectedOpponentDeckId,
      );
      if (selectedOpponentDeck == null ||
          !_deckMatchesFormat(selectedOpponentDeck, selectedFormat)) {
        selectedOpponentDeckId = '';
      }
    }

    normalizeSelectedDeck();
    normalizeSelectedOpponentDeck();

    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(context.txt.t('dialog.matchDetails')),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: matchNameController,
                      decoration: InputDecoration(
                        labelText: context.txt.t('field.matchName'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: opponentController,
                      decoration: const InputDecoration(
                        labelText: 'Opponent',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedFormat.isEmpty
                          ? null
                          : selectedFormat,
                      decoration: InputDecoration(
                        labelText: context.txt.t('field.format'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(
                          value: '',
                          child: Text(context.txt.t('field.noFormat')),
                        ),
                        ...formatOptions().map((String format) {
                          return DropdownMenuItem<String>(
                            value: format,
                            child: Text(format),
                          );
                        }),
                        DropdownMenuItem<String>(
                          value: '__add_format__',
                          child: Text(context.txt.t('field.addNewFormat')),
                        ),
                      ],
                      onChanged: (String? nextValue) async {
                        if (nextValue == null) {
                          return;
                        }
                        if (nextValue == '__add_format__') {
                          final String? created = await _promptText(
                            title: 'New format',
                            initialValue: '',
                            hintText: 'Modern, Edison, Commander...',
                          );
                          if (created == null) {
                            return;
                          }
                          final String trimmed = created.trim();
                          if (trimmed.isEmpty) {
                            return;
                          }
                          setDialogState(() {
                            selectedFormat = trimmed;
                            normalizeSelectedDeck();
                            normalizeSelectedOpponentDeck();
                          });
                          return;
                        }
                        setDialogState(() {
                          selectedFormat = nextValue.trim();
                          normalizeSelectedDeck();
                          normalizeSelectedOpponentDeck();
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedDeckId,
                      decoration: InputDecoration(
                        labelText: context.txt.t('field.deck'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(
                          value: '',
                          child: Text(context.txt.t('field.noDeck')),
                        ),
                        ...deckOptions().map((SideboardDeck deck) {
                          return DropdownMenuItem<String>(
                            value: deck.id,
                            child: Text(
                              deck.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                      onChanged: (String? nextValue) {
                        setDialogState(() {
                          selectedDeckId = (nextValue ?? '').trim();
                          normalizeSelectedDeck();
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedOpponentDeckId.isEmpty
                          ? null
                          : selectedOpponentDeckId,
                      decoration: InputDecoration(
                        labelText: context.txt.t('field.opponentDeck'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(
                          value: '',
                          child: Text(context.txt.t('field.noOpponentDeck')),
                        ),
                        ...opponentDeckOptions().map((SideboardDeck deck) {
                          return DropdownMenuItem<String>(
                            value: deck.id,
                            child: Text(
                              deck.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                      onChanged: (String? nextValue) {
                        setDialogState(() {
                          selectedOpponentDeckId = (nextValue ?? '').trim();
                          normalizeSelectedOpponentDeck();
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: tagController,
                      decoration: const InputDecoration(
                        labelText: 'Tag',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.txt.t('common.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.txt.t('common.save')),
            ),
          ],
        );
      },
    );

    if (shouldSave != true) {
      _disposeTextControllersLater(<TextEditingController>[
        matchNameController,
        opponentController,
        tagController,
      ]);
      return;
    }

    if (!mounted) {
      _disposeTextControllersLater(<TextEditingController>[
        matchNameController,
        opponentController,
        tagController,
      ]);
      return;
    }

    final SideboardDeck? selectedDeck = _deckById(selectedDeckId);
    final SideboardDeck? selectedOpponentDeck = _deckById(
      selectedOpponentDeckId,
    );
    _applyMatchMetadata(
      _metadata.copyWith(
        name: matchNameController.text.trim(),
        opponentName: opponentController.text.trim(),
        deckId: selectedDeck?.id ?? '',
        deckName: selectedDeck?.name ?? '',
        format: selectedFormat,
        opponentDeckId: selectedOpponentDeck?.id ?? '',
        opponentDeckName: selectedOpponentDeck?.name ?? '',
        tag: tagController.text.trim(),
      ),
    );
    _disposeTextControllersLater(<TextEditingController>[
      matchNameController,
      opponentController,
      tagController,
    ]);
  }

  Widget _buildSummaryRow({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.68),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '-' : value.trim(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editGameDetails(GameRecord record) async {
    String stage = _supportedGameStages.contains(record.gameStage)
        ? record.gameStage
        : 'G1';
    String result = _selectedMatchResult(record);

    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(context.txt.t('dialog.gameDetails')),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: stage,
                      decoration: const InputDecoration(
                        labelText: 'Game',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _supportedGameStages
                          .map((String item) {
                            return DropdownMenuItem<String>(
                              value: item,
                              child: Text(item),
                            );
                          })
                          .toList(growable: false),
                      onChanged: (String? nextValue) {
                        if (nextValue == null) {
                          return;
                        }
                        setDialogState(() {
                          stage = nextValue;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: result.isEmpty ? null : result,
                      decoration: const InputDecoration(
                        labelText: 'Result',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: <DropdownMenuItem<String>>[
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('No result'),
                        ),
                        ..._supportedMatchResults.map((String item) {
                          return DropdownMenuItem<String>(
                            value: item,
                            child: Text(item),
                          );
                        }),
                      ],
                      onChanged: (String? nextValue) {
                        setDialogState(() {
                          result = (nextValue ?? '').trim();
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.txt.t('common.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.txt.t('common.save')),
            ),
          ],
        );
      },
    );

    if (shouldSave != true) {
      return;
    }

    _updateGame(record.copyWith(gameStage: stage, matchResult: result));
  }

  Future<void> _editNotes(GameRecord record) async {
    final String? result = await _promptText(
      title: 'Edit game notes',
      initialValue: record.notes,
      hintText: 'Write some notes...',
      maxLines: 6,
    );
    if (result == null) {
      return;
    }
    _updateGame(record.copyWith(notes: result.trim()));
  }

  Future<void> _deleteGame(GameRecord record) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete game'),
          content: Text('Delete "${record.title}" from this match?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.txt.t('common.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (shouldDelete != true) {
      return;
    }
    setState(() {
      _games = _games
          .where((GameRecord game) => game.id != record.id)
          .toList(growable: false);
    });
  }

  Future<void> _showLifePointHistory(GameRecord record) async {
    final bool hasHistory = record.lifePointHistory.isNotEmpty;
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${record.title} - LP History'),
          content: SizedBox(
            width: double.maxFinite,
            child: hasHistory
                ? _buildLifeHistoryView(
                    lines: record.lifePointHistory,
                    playerCount: record.playerCount,
                    dividerColor: Colors.white.withValues(alpha: 0.14),
                  )
                : const Text('No life point history saved for this game yet.'),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
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
          title: Text(_effectiveMatchName()),
          leading: IconButton(
            onPressed: _closeWithResult,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            Card(
              color: const Color(0xFF1E1B1B),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _effectiveMatchName(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _matchResultBackgroundColor(
                              _matchAggregateResultLabel(
                                _aggregateMatchResultFromGames(_games),
                              ),
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _matchAggregateResultLabel(
                              _aggregateMatchResultFromGames(_games),
                            ),
                            style: TextStyle(
                              color: _matchResultTextColor(
                                _matchAggregateResultLabel(
                                  _aggregateMatchResultFromGames(_games),
                                ),
                              ),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildSummaryRow(
                      label: context.txt.t('field.opponent'),
                      value: _metadata.opponentName,
                    ),
                    _buildSummaryRow(label: context.txt.t('field.deck'), value: _metadata.deckName),
                    _buildSummaryRow(
                      label: context.txt.t('field.opponentDeck'),
                      value: _metadata.opponentDeckName,
                    ),
                    _buildSummaryRow(label: context.txt.t('field.format'), value: _metadata.format),
                    _buildSummaryRow(label: context.txt.t('field.tag'), value: _metadata.tag),
                    const SizedBox(height: 10),
                    Text(
                      'Edit match changes metadata only. Match result is calculated from the game results below.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.tonalIcon(
                        onPressed: _openMatchEditor,
                        icon: const Icon(Icons.edit_note_rounded, size: 18),
                        label: const Text('Edit match'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_games.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'No games in this match.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.74),
                    ),
                  ),
                ),
              )
            else
              ..._games.map((GameRecord game) {
                final String selectedResult = _selectedMatchResult(game);
                final String stage =
                    _supportedGameStages.contains(game.gameStage)
                    ? game.gameStage
                    : 'G1';
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  color: const Color(0xFF1E1B1B),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '$stage - ${game.title}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _matchResultBackgroundColor(
                                  selectedResult,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedResult.isEmpty
                                      ? null
                                      : selectedResult,
                                  hint: Text(
                                    'Result',
                                    style: TextStyle(
                                      color: _matchResultTextColor(''),
                                    ),
                                  ),
                                  dropdownColor: const Color(0xFF2B2424),
                                  style: TextStyle(
                                    color: _matchResultTextColor(
                                      selectedResult,
                                    ),
                                    fontWeight: FontWeight.w700,
                                  ),
                                  items: _supportedMatchResults
                                      .map((String result) {
                                        return DropdownMenuItem<String>(
                                          value: result,
                                          child: Text(
                                            result,
                                            style: TextStyle(
                                              color: _matchResultTextColor(
                                                result,
                                              ),
                                            ),
                                          ),
                                        );
                                      })
                                      .toList(growable: false),
                                  onChanged: (String? nextResult) {
                                    if (nextResult == null) {
                                      return;
                                    }
                                    _updateGame(
                                      game.copyWith(matchResult: nextResult),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDateTime(game.createdAt, context),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          game.notes.trim().isEmpty ? 'No notes' : game.notes,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: game.notes.trim().isEmpty
                                ? Colors.white.withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.88),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 2,
                                runSpacing: 2,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _editGameDetails(game),
                                    icon: const Icon(
                                      Icons.edit_note_rounded,
                                      size: 16,
                                    ),
                                    label: Text(context.txt.t('game.details')),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => _editNotes(game),
                                    icon: const Icon(
                                      Icons.sticky_note_2_outlined,
                                      size: 16,
                                    ),
                                    label: Text(context.txt.t('common.notes')),
                                  ),
                                  TextButton.icon(
                                    onPressed: () =>
                                        _showLifePointHistory(game),
                                    icon: const Icon(
                                      Icons.format_list_bulleted_rounded,
                                      size: 16,
                                    ),
                                    label: Text(context.txt.t('game.lpHistory')),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Delete game',
                              onPressed: () => _deleteGame(game),
                              icon: const Icon(Icons.delete_outline_rounded),
                              color: const Color(0xFFFF8A8A),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

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
                title: Text(initialDeck == null ? 'New deck' : 'Edit deck'),
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
                          'Existing formats',
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
                      if (_hasDeckNameConflict(
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
      _disposeTextControllersLater(<TextEditingController>[
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
          title: const Text('Synchronize matchups'),
          content: Text(
            'Do you want to synchronize this deck with the matchup lists of all decks with the same format?\n\nFormat: $format',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes'),
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
    final String normalizedOldName = _normalizeDeckName(previousDeck.name);
    final String updatedName = updatedDeck.name.trim();
    if (normalizedOldName.isEmpty || updatedName.isEmpty) {
      return List<GameRecord>.from(records);
    }
    final String updatedDeckId = updatedDeck.id.trim();
    return records
        .map((GameRecord record) {
          final bool deckMatches = updatedDeckId.isNotEmpty
              ? record.deckId.trim() == updatedDeckId
              : _normalizeDeckName(record.deckName) == normalizedOldName;
          final bool opponentDeckMatches = updatedDeckId.isNotEmpty
              ? record.opponentDeckId.trim() == updatedDeckId
              : _normalizeDeckName(record.opponentDeckName) ==
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
      if (_normalizeDeckName(deck.name) !=
          _normalizeDeckName(updatedDeck.name)) {
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
          title: const Text("Deck's Utility"),
          leading: IconButton(
            onPressed: _closeWithResult,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          actions: [
            IconButton(
              tooltip: 'Add deck',
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
                            Text(
                              txt.t('deckList.filters'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (availableFormats.isNotEmpty)
                              DropdownButtonFormField<String>(
                                initialValue: effectiveFormatFilter.isEmpty
                                    ? null
                                    : effectiveFormatFilter,
                                decoration: InputDecoration(
                                  labelText: txt.t('field.format'),
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: <DropdownMenuItem<String>>[
                                  DropdownMenuItem<String>(
                                    value: '',
                                    child: Text(txt.t('deckList.allFormats')),
                                  ),
                                  ...availableFormats.map((String format) {
                                    return DropdownMenuItem<String>(
                                      value: format,
                                      child: Text(
                                        format,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (String? value) {
                                  setState(() {
                                    _selectedDeckFormatFilter = (value ?? '')
                                        .trim();
                                    _visibleDeckCount = _deckPageSize;
                                  });
                                },
                              ),
                            if (availableFormats.isNotEmpty &&
                                availableTags.isNotEmpty)
                              const SizedBox(height: 12),
                            if (availableTags.isNotEmpty)
                              DropdownButtonFormField<String>(
                                initialValue: effectiveTagFilter.isEmpty
                                    ? null
                                    : effectiveTagFilter,
                                decoration: InputDecoration(
                                  labelText: txt.t('field.tag'),
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: <DropdownMenuItem<String>>[
                                  DropdownMenuItem<String>(
                                    value: '',
                                    child: Text(txt.t('deckList.allTags')),
                                  ),
                                  ...availableTags.map((String tag) {
                                    return DropdownMenuItem<String>(
                                      value: tag,
                                      child: Text(
                                        tag,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (String? value) {
                                  setState(() {
                                    _selectedDeckTagFilter = (value ?? '')
                                        .trim();
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
                                  ? '1 matchup'
                                  : '$matchupCount matchups';
                              final String trimmedFormat = deck.format.trim();
                              final String subtitleText = trimmedFormat.isEmpty
                                  ? matchupLabel
                                  : 'Format: $trimmedFormat  •  $matchupLabel';
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
        builder: (_) => _DeckUserNotesScreen(
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
        builder: (_) => _DeckMatchupHistoryScreen(
          deck: widget.deck.copyWith(
            matchups: _matchups,
            userNotes: _userNotes,
          ),
          records: _records,
          mode: _DeckSectionMode.matchupHistory,
        ),
      ),
    );
  }

  Future<void> _openSideboardPlans() async {
    final List<SideboardMatchup>? updated = await Navigator.of(context)
        .push<List<SideboardMatchup>>(
          MaterialPageRoute<List<SideboardMatchup>>(
            builder: (_) => _DeckMatchupHistoryScreen(
              deck: widget.deck.copyWith(
                matchups: _matchups,
                userNotes: _userNotes,
              ),
              records: _records,
              mode: _DeckSectionMode.sideboardPlans,
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
        builder: (_) => _DeckStatisticsScreen(
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

class _DeckUserNotesScreen extends StatefulWidget {
  const _DeckUserNotesScreen({
    required this.deckName,
    required this.initialNotes,
  });

  final String deckName;
  final String initialNotes;

  @override
  State<_DeckUserNotesScreen> createState() => _DeckUserNotesScreenState();
}

class _DeckUserNotesScreenState extends State<_DeckUserNotesScreen> {
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

enum _DeckSectionMode { matchupHistory, sideboardPlans }

class _DeckMatchupHistoryScreen extends StatefulWidget {
  const _DeckMatchupHistoryScreen({
    required this.deck,
    required this.records,
    required this.mode,
  });

  final SideboardDeck deck;
  final List<GameRecord> records;
  final _DeckSectionMode mode;

  @override
  State<_DeckMatchupHistoryScreen> createState() =>
      _DeckMatchupHistoryScreenState();
}

class _DeckMatchupHistoryScreenState extends State<_DeckMatchupHistoryScreen> {
  late List<SideboardMatchup> _matchups;
  late List<GameRecord> _records;
  SideboardMatchupSortMode _matchupSortMode =
      SideboardMatchupSortMode.createdAt;

  @override
  void initState() {
    super.initState();
    _matchups = List<SideboardMatchup>.from(widget.deck.matchups);
    _records = List<GameRecord>.from(widget.records);
  }

  void _closeWithResult() {
    if (widget.mode == _DeckSectionMode.sideboardPlans) {
      Navigator.of(context).pop(List<SideboardMatchup>.from(_matchups));
      return;
    }
    Navigator.of(context).pop();
  }

  Future<String?> _promptText({
    required String title,
    required String hintText,
    String initialValue = '',
  }) async {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return _TextPromptDialog(
          title: title,
          initialValue: initialValue,
          hintText: hintText,
          maxLines: 1,
        );
      },
    );
  }

  String _effectiveMatchId(GameRecord record) {
    final String raw = record.matchId.trim();
    if (raw.isNotEmpty) {
      return raw;
    }
    return 'legacy-${record.id}';
  }

  String _firstNonEmptyFromNewest(
    List<GameRecord> games,
    String Function(GameRecord game) pick,
  ) {
    for (int index = games.length - 1; index >= 0; index -= 1) {
      final String value = pick(games[index]).trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  List<GameRecord> _recordsForDeck() {
    final String deckId = widget.deck.id.trim();
    final String deckName = widget.deck.name.trim().toLowerCase();
    final List<GameRecord> linked = _records
        .where((GameRecord record) {
          if (deckId.isNotEmpty && record.deckId.trim() == deckId) {
            return true;
          }
          return deckName.isNotEmpty &&
              record.deckName.trim().toLowerCase() == deckName;
        })
        .toList(growable: false);
    linked.sort((GameRecord a, GameRecord b) {
      return b.createdAt.compareTo(a.createdAt);
    });
    return linked;
  }

  List<MatchRecord> _linkedMatchRecords() {
    final List<GameRecord> twoPlayerRecords = _recordsForDeck()
        .where((GameRecord record) => record.playerCount == 2)
        .toList(growable: false);
    if (twoPlayerRecords.isEmpty) {
      return const <MatchRecord>[];
    }
    final Map<String, List<GameRecord>> grouped = <String, List<GameRecord>>{};
    for (final GameRecord record in twoPlayerRecords) {
      final String key = _effectiveMatchId(record);
      grouped.putIfAbsent(key, () => <GameRecord>[]).add(record);
    }
    final List<MatchRecord> matches = <MatchRecord>[];
    for (final MapEntry<String, List<GameRecord>> entry in grouped.entries) {
      final List<GameRecord> games = List<GameRecord>.from(entry.value);
      games.sort((GameRecord a, GameRecord b) {
        final int byStage = _gameStageSortKey(
          a.gameStage,
        ).compareTo(_gameStageSortKey(b.gameStage));
        if (byStage != 0) {
          return byStage;
        }
        return a.createdAt.compareTo(b.createdAt);
      });
      final DateTime createdAt = games
          .map((GameRecord game) => game.createdAt)
          .reduce((DateTime a, DateTime b) => a.isBefore(b) ? a : b);
      final DateTime updatedAt = games
          .map((GameRecord game) => game.createdAt)
          .reduce((DateTime a, DateTime b) => a.isAfter(b) ? a : b);
      final String name = _firstNonEmptyFromNewest(
        games,
        (GameRecord game) => game.matchName.trim(),
      );
      final String opponent = _firstNonEmptyFromNewest(games, (
        GameRecord game,
      ) {
        final String v = game.opponentName.trim();
        if (v.isNotEmpty) {
          return v;
        }
        return game.playerTwoName.trim();
      });
      final String deckName = _firstNonEmptyFromNewest(
        games,
        (GameRecord game) => game.deckName.trim(),
      );
      final String opponentDeckName = _firstNonEmptyFromNewest(
        games,
        (GameRecord game) => game.opponentDeckName.trim(),
      );
      final String format = _firstNonEmptyFromNewest(
        games,
        (GameRecord game) => game.matchFormat.trim(),
      );
      final String tag = _firstNonEmptyFromNewest(
        games,
        (GameRecord game) => game.matchTag.trim(),
      );
      matches.add(
        MatchRecord(
          id: entry.key,
          tcgKey: widget.deck.tcgKey,
          metadata: MatchMetadata(
            name: name.isEmpty ? 'Match' : name,
            opponentName: opponent,
            deckId: widget.deck.id,
            deckName: deckName,
            opponentDeckId: '',
            opponentDeckName: opponentDeckName,
            format: format,
            tag: tag,
          ),
          createdAt: createdAt,
          updatedAt: updatedAt,
          games: games,
          aggregateResult: _aggregateMatchResultFromGames(games),
        ),
      );
    }
    matches.sort((MatchRecord a, MatchRecord b) {
      return b.createdAt.compareTo(a.createdAt);
    });
    return matches;
  }

  Color _matchResultBackgroundColor(String result) {
    if (result == 'Win') {
      return const Color(0xFF245D32);
    }
    if (result == 'Loss') {
      return const Color(0xFF6A2323);
    }
    if (result == 'Draw') {
      return const Color(0xFF665825);
    }
    return const Color(0xFF2B2424);
  }

  Color _matchResultTextColor(String result) {
    if (result == 'Win') {
      return const Color(0xFFB8FFCC);
    }
    if (result == 'Loss') {
      return const Color(0xFFFFC4C4);
    }
    if (result == 'Draw') {
      return const Color(0xFFFFEEAA);
    }
    return Colors.white.withValues(alpha: 0.86);
  }

  Future<void> _addMatchup() async {
    final String? rawName = await _promptText(
      title: 'New matchup',
      hintText: 'Opponent deck name',
    );
    if (rawName == null) {
      return;
    }
    final String name = rawName.trim();
    if (name.isEmpty) {
      return;
    }
    final DateTime now = DateTime.now();
    setState(() {
      _matchups.insert(
        0,
        SideboardMatchup(
          id: now.microsecondsSinceEpoch.toString(),
          name: name,
          createdAt: now,
          sideIn: const <SideboardCardEntry>[],
          sideOut: const <SideboardCardEntry>[],
        ),
      );
    });
  }

  Future<void> _openMatchup(SideboardMatchup matchup) async {
    final SideboardMatchup? updated = await Navigator.of(context)
        .push<SideboardMatchup>(
          MaterialPageRoute<SideboardMatchup>(
            builder: (_) => SideboardPlanScreen(matchup: matchup),
          ),
        );
    if (updated == null) {
      return;
    }
    final int index = _matchups.indexWhere(
      (SideboardMatchup item) => item.id == matchup.id,
    );
    if (index < 0) {
      return;
    }
    setState(() {
      _matchups[index] = updated;
    });
  }

  List<SideboardMatchup> _sortedMatchups() {
    final List<SideboardMatchup> sorted = List<SideboardMatchup>.from(
      _matchups,
    );
    switch (_matchupSortMode) {
      case SideboardMatchupSortMode.alphabetical:
        sorted.sort((SideboardMatchup a, SideboardMatchup b) {
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
      case SideboardMatchupSortMode.createdAt:
        sorted.sort((SideboardMatchup a, SideboardMatchup b) {
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings txt = context.txt;
    final List<SideboardMatchup> sortedMatchups = _sortedMatchups();
    final List<MatchRecord> linkedMatches = _linkedMatchRecords();
    final bool showSideboardPlans =
        widget.mode == _DeckSectionMode.sideboardPlans;
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
          title: Text(
            txt.t(showSideboardPlans ? 'section.sideboardPlans' : 'section.matchupHistory'),
          ),
          leading: IconButton(
            onPressed: _closeWithResult,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          actions: showSideboardPlans
              ? <Widget>[
                  PopupMenuButton<SideboardMatchupSortMode>(
                    tooltip: 'Sort sideboards',
                    onSelected: (SideboardMatchupSortMode mode) {
                      setState(() {
                        _matchupSortMode = mode;
                      });
                    },
                    itemBuilder: (BuildContext context) {
                      return const <PopupMenuEntry<SideboardMatchupSortMode>>[
                        PopupMenuItem<SideboardMatchupSortMode>(
                          value: SideboardMatchupSortMode.alphabetical,
                          child: Text('Alphabetical'),
                        ),
                        PopupMenuItem<SideboardMatchupSortMode>(
                          value: SideboardMatchupSortMode.createdAt,
                          child: Text('Creation Date'),
                        ),
                      ];
                    },
                    icon: const Icon(Icons.sort_rounded),
                  ),
                  IconButton(
                    tooltip: 'Add matchup',
                    onPressed: _addMatchup,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ]
              : const <Widget>[],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          children: [
            if (showSideboardPlans) ...[
              if (sortedMatchups.isEmpty)
                Card(
                  color: const Color(0xFF1E1B1B),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      'No sideboard plans yet. Tap + to add one.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.74),
                      ),
                    ),
                  ),
                )
              else
                ...sortedMatchups.map((SideboardMatchup matchup) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    color: const Color(0xFF1E1B1B),
                    child: ListTile(
                      onTap: () => _openMatchup(matchup),
                      title: Text(
                        matchup.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Side In: ${matchup.sideIn.length}  •  Side Out: ${matchup.sideOut.length}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                    ),
                  );
                }),
            ] else ...[
              if (linkedMatches.isEmpty)
                Card(
                  color: const Color(0xFF1E1B1B),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      'No saved matches for this deck yet.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.74),
                      ),
                    ),
                  ),
                )
              else
                ...linkedMatches.map((MatchRecord match) {
                  final String opponent =
                      match.metadata.opponentName.trim().isEmpty
                      ? '-'
                      : match.metadata.opponentName.trim();
                  final String opponentDeck =
                      match.metadata.opponentDeckName.trim().isEmpty
                      ? '-'
                      : match.metadata.opponentDeckName.trim();
                  final String resultLabel = _matchAggregateResultLabel(
                    match.aggregateResult,
                  );
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    color: const Color(0xFF1E1B1B),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  match.metadata.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _matchResultBackgroundColor(
                                    resultLabel,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  resultLabel,
                                  style: TextStyle(
                                    color: _matchResultTextColor(resultLabel),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDateTime(match.createdAt, context),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Opponent: $opponent',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.82),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Opponent Deck: $opponentDeck',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${match.games.length} game${match.games.length == 1 ? '' : 's'}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ],
        ),
      ),
    );
  }
}

@immutable
class _DeckStatisticsRow {
  const _DeckStatisticsRow({
    required this.opponentDeck,
    required this.matches,
    required this.wins,
    required this.losses,
    required this.draws,
  });

  final String opponentDeck;
  final int matches;
  final int wins;
  final int losses;
  final int draws;
}

class _DeckStatisticsScreen extends StatelessWidget {
  const _DeckStatisticsScreen({required this.deck, required this.records});

  final SideboardDeck deck;
  final List<GameRecord> records;

  String _effectiveMatchId(GameRecord record) {
    final String raw = record.matchId.trim();
    if (raw.isNotEmpty) {
      return raw;
    }
    return 'legacy-${record.id}';
  }

  String _firstNonEmptyFromNewest(
    List<GameRecord> games,
    String Function(GameRecord game) pick,
  ) {
    for (int index = games.length - 1; index >= 0; index -= 1) {
      final String value = pick(games[index]).trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  List<GameRecord> _recordsForDeck() {
    final String deckId = deck.id.trim();
    final String deckName = deck.name.trim().toLowerCase();
    final List<GameRecord> linked = records
        .where((GameRecord record) {
          if (deckId.isNotEmpty && record.deckId.trim() == deckId) {
            return true;
          }
          return deckName.isNotEmpty &&
              record.deckName.trim().toLowerCase() == deckName;
        })
        .where((GameRecord record) => record.playerCount == 2)
        .toList(growable: false);
    linked.sort((GameRecord a, GameRecord b) {
      return b.createdAt.compareTo(a.createdAt);
    });
    return linked;
  }

  List<_DeckStatisticsRow> _statsRows() {
    final List<GameRecord> linked = _recordsForDeck();
    if (linked.isEmpty) {
      return const <_DeckStatisticsRow>[];
    }
    final Map<String, List<GameRecord>> groupedMatches =
        <String, List<GameRecord>>{};
    for (final GameRecord record in linked) {
      final String key = _effectiveMatchId(record);
      groupedMatches.putIfAbsent(key, () => <GameRecord>[]).add(record);
    }

    final Map<String, ({int matches, int wins, int losses, int draws})> table =
        <String, ({int matches, int wins, int losses, int draws})>{};

    for (final List<GameRecord> games in groupedMatches.values) {
      games.sort((GameRecord a, GameRecord b) {
        final int byStage = _gameStageSortKey(
          a.gameStage,
        ).compareTo(_gameStageSortKey(b.gameStage));
        if (byStage != 0) {
          return byStage;
        }
        return a.createdAt.compareTo(b.createdAt);
      });
      final String opponentDeck = _firstNonEmptyFromNewest(
        games,
        (GameRecord game) => game.opponentDeckName.trim(),
      );
      final String key = opponentDeck.isEmpty ? '-' : opponentDeck;
      final MatchAggregateResult aggregate = _aggregateMatchResultFromGames(
        games,
      );
      final ({int matches, int wins, int losses, int draws}) current =
          table[key] ?? (matches: 0, wins: 0, losses: 0, draws: 0);
      int wins = current.wins;
      int losses = current.losses;
      int draws = current.draws;
      if (aggregate == MatchAggregateResult.win) {
        wins += 1;
      } else if (aggregate == MatchAggregateResult.loss) {
        losses += 1;
      } else if (aggregate == MatchAggregateResult.draw) {
        draws += 1;
      }
      table[key] = (
        matches: current.matches + 1,
        wins: wins,
        losses: losses,
        draws: draws,
      );
    }

    final List<_DeckStatisticsRow> rows = table.entries
        .map((
          MapEntry<String, ({int matches, int wins, int losses, int draws})> e,
        ) {
          return _DeckStatisticsRow(
            opponentDeck: e.key,
            matches: e.value.matches,
            wins: e.value.wins,
            losses: e.value.losses,
            draws: e.value.draws,
          );
        })
        .toList(growable: false);
    rows.sort((_DeckStatisticsRow a, _DeckStatisticsRow b) {
      return a.opponentDeck.toLowerCase().compareTo(
        b.opponentDeck.toLowerCase(),
      );
    });
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings txt = context.txt;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) {
        return;
      }
      unawaited(
        showInfoTipOnce(
          context: context,
          tipId: InfoTipIds.statistics,
          titleKey: 'info.statistics.title',
          bodyKey: 'info.statistics.body',
          icon: Icons.query_stats_rounded,
        ),
      );
    });
    final List<_DeckStatisticsRow> rows = _statsRows();
    return Scaffold(
      appBar: AppBar(title: Text(txt.t('statistics.title'))),
      body: rows.isEmpty
          ? Center(
              child: Text(
                txt.t('statistics.empty'),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.74)),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              itemCount: rows.length,
              itemBuilder: (BuildContext context, int index) {
                final _DeckStatisticsRow row = rows[index];
                final double winRate = row.matches == 0
                    ? 0
                    : (row.wins / row.matches) * 100;
                final double lossRate = row.matches == 0
                    ? 0
                    : (row.losses / row.matches) * 100;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  color: const Color(0xFF1E1B1B),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          txt.t(
                            'statistics.vs',
                            params: <String, Object?>{'deck': row.opponentDeck},
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(txt.t('statistics.matches', params: <String, Object?>{'count': row.matches})),
                        const SizedBox(height: 2),
                        Text(txt.t('statistics.wins', params: <String, Object?>{'count': row.wins})),
                        const SizedBox(height: 2),
                        Text(txt.t('statistics.losses', params: <String, Object?>{'count': row.losses})),
                        if (row.draws > 0) ...[
                          const SizedBox(height: 2),
                          Text(txt.t('statistics.draws', params: <String, Object?>{'count': row.draws})),
                        ],
                        const SizedBox(height: 6),
                        Text(txt.t('statistics.winrate', params: <String, Object?>{'value': winRate.toStringAsFixed(1)})),
                        const SizedBox(height: 2),
                        Text(txt.t('statistics.lossRate', params: <String, Object?>{'value': lossRate.toStringAsFixed(1)})),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

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
        return _TextPromptDialog(
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

class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.initialValue,
    required this.hintText,
    required this.maxLines,
  });

  final String title;
  final String initialValue;
  final String hintText;
  final int maxLines;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: widget.maxLines,
        textInputAction: widget.maxLines == 1
            ? TextInputAction.done
            : TextInputAction.newline,
        decoration: InputDecoration(
          hintText: widget.hintText,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.txt.t('common.cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(context.txt.t('common.save')),
        ),
      ],
    );
  }
}

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
            for (final Color color in _appColorPalette)
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
              items: _supportedTcgAlphabeticalOrder
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
