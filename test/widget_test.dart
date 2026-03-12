import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yugi_life_counter/main.dart';

void main() {
  testWidgets('Home screen loads', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await tester.pumpWidget(const YugiLifeCounterApp());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('TCG Life Counter'), findsOneWidget);
    expect(find.text("Let's Duel"), findsOneWidget);
    expect(find.text('Game History'), findsOneWidget);
    expect(find.text('Customize App'), findsOneWidget);
  });
}
