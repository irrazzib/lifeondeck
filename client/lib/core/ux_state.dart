import 'package:shared_preferences/shared_preferences.dart';

const String _onboardingCompletedKey = 'onboarding_completed_v1';
const String _defaultGameSelectedKey = 'default_game_selected_v1';
const String _seenInfoTipsKey = 'seen_info_tips_v1';

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
