# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
flutter pub get          # Install dependencies
flutter run              # Run in debug mode
flutter analyze          # Lint (uses analysis_options.yaml)
flutter test             # Run all tests
flutter test test/widget_test.dart  # Run a single test file
flutter build apk        # Build Android
flutter build ios        # Build iOS
flutter build web        # Build web/PWA
```

## Architecture

**TCG Life Counter** — a cross-platform Flutter app for tracking life points in Trading Card Games (Yu-Gi-Oh, MTG, with Riftbound/Lorcana stubbed).

### Single-file structure

The entire app lives in `lib/main.dart` (~16k lines). It is organized into distinct sections: data models, i18n strings, state management, and UI screens — all within one file. This is intentional; do not split into separate files unless explicitly asked.

### Navigation

Uses imperative `Navigator.push/pop` — no named routes. The flow is:

```
_AppOnboardingScreen (first run)
  → _GameSelectionScreen
    → HomeScreen (root)
        ├── DuelScreen / MtgDuelScreen
        ├── GameHistoryScreen → _TwoPlayerMatchDetailScreen
        ├── SideboardDeckListScreen → SideboardMatchupListScreen → SideboardPlanScreen
        └── CustomizeScreen
```

### State management

No external state management library. Pattern:
- `HomeScreen` (_HomeScreenState) is the root state holder, owns `AppSettings`, `List<GameRecord>`, `List<SideboardDeck>`, and the active `SupportedTcg`.
- All mutations persist via `_persistState()` → SharedPreferences (JSON-serialized with versioned keys).
- `AppRuntimeConfig` holds `ValueNotifier<AppLanguage>` for live locale switching.
- State is passed down as constructor params; results bubble up via callbacks (e.g. `DuelCheckpointCallback`).

### Data models

All models are `@immutable` with manual `toJson()`/`fromJson()` and `copyWith()`. No codegen. Key models: `AppSettings`, `GameRecord`, `SideboardDeck`, `SideboardMatchup`, `MatchMetadata`.

### i18n

`AppStrings` (defined near top of main.dart) is the string catalog supporting English and Italian. Access strings via the `AppTextScope` InheritedWidget: `context.txt.someKey`. Do not hardcode user-facing strings — add them to `AppStrings` and all locale maps.

### MTG specifics

MTG has its own setup screen (`MtgDuelSetupScreen`) and duel screen (`MtgDuelScreen`) with resource counters (mana colors, poison, experience) and a `tableMode` layout. Game-specific logic is isolated to these screens.

## Key conventions

- Mobile is portrait-only (enforced via `AppOrientationLock` + lifecycle observer).
- `wakelock_plus` keeps the screen on during active duels — always release it on duel exit.
- Per-player colors and gradient themes are stored in `AppSettings`; read from there, do not hardcode colors.
- Deck records link to match history for statistics — maintain referential integrity when modifying deck or record IDs.
- History export/import uses a `.txt` file containing a JSON payload; the format is versioned.
