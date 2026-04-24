import 'package:flutter/material.dart';

import '../core/ux_state.dart';

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

void disposeTextControllersLater(Iterable<TextEditingController> controllers) {
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
