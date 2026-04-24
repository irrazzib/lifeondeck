import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yugi_life_counter/app.dart';
import 'package:yugi_life_counter/core/constants.dart';
import 'package:yugi_life_counter/models/app_settings.dart';
import 'package:yugi_life_counter/models/game_record.dart';
import 'package:yugi_life_counter/models/sideboard.dart';
import 'package:yugi_life_counter/screens/history/game_history_screen.dart';
import 'package:yugi_life_counter/screens/sideboard/sideboard_deck_list_screen.dart';

void main() {
  testWidgets('Home screen loads after stored onboarding is completed', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{
      'onboarding_completed_v1': true,
    });
    await tester.pumpWidget(const YugiLifeCounterApp());
    await tester.pumpAndSettle();

    expect(find.text('TCG Life Counter'), findsOneWidget);
    expect(find.text("Let's Duel"), findsOneWidget);
    expect(find.text('Game History'), findsOneWidget);
    expect(find.text('Customize App'), findsOneWidget);
  });

  testWidgets('History import rejects files from a different game', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{
      'seen_info_tips_v1': <String>['match_history'],
    });
    final String payload =
        'TCG_LIFE_COUNTER_HISTORY_V1\n'
        '${jsonEncode(<String, Object>{
          'schema': 'TCG_LIFE_COUNTER_HISTORY_V1',
          'tcg': 'mtg',
          'records': <Map<String, Object>>[
            GameRecord(id: 'imported-1', title: 'Imported Duel', createdAt: DateTime.utc(2026, 3, 1), gameStage: 'G1', notes: '', lifePointHistory: const <String>['8000|8000'], tcgKey: 'mtg', playerCount: 2, matchId: 'match-1', matchName: 'Imported Match', matchResult: 'Win').toJson(),
          ],
        })}';

    await tester.pumpWidget(
      const MaterialApp(
        home: GameHistoryScreen(
          records: <GameRecord>[],
          decks: <SideboardDeck>[],
          tcg: SupportedTcg.yugioh,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.upload_file_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), payload);
    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'This history file belongs to MTG. Import it from that game history.',
      ),
      findsOneWidget,
    );
    expect(find.text('Imported Match'), findsNothing);
  });

  testWidgets('Deck creation blocks duplicate names', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final SideboardDeck deck = SideboardDeck(
      id: 'deck-1',
      name: 'Blue-Eyes',
      createdAt: DateTime.utc(2026, 3, 1),
      isFavorite: false,
      userNotes: '',
      matchups: const <SideboardMatchup>[],
      format: 'GOAT',
      tag: '',
      tcgKey: SupportedTcg.yugioh.storageKey,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SideboardDeckListScreen(
          decks: <SideboardDeck>[deck],
          records: const <GameRecord>[],
          settings: AppSettings.defaults(),
          tcg: SupportedTcg.yugioh,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Blue-Eyes');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('A deck with this name already exists.'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Blue-Eyes'), findsOneWidget);
  });
}
