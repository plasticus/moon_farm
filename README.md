# Moon Farm — Development Notes

## Phase 1 Setup (do this before running)

### 1. Flutter environment
Make sure you have Flutter 3.x installed and an Android emulator or device connected.

```bash
flutter doctor
flutter pub get
```

### 2. First run
```bash
flutter run
```

You should see:
- Dark main menu with Moon Farm title and 3 empty save slots
- Tap a slot → New Game screen → name your farm → pick difficulty → Begin Operation
- You land on the game hub with Dashboard, Domes, Refinery, Relay, Habitat tabs
- Dashboard shows your starting resources, power, milestone tracker, and End Week button
- Habitat tab shows lifetime stats and radio transmissions
- Save/load/delete all working via SQLite

### 3. AdMob setup (do this before publishing, not needed for dev)
- Replace the test app ID in `android/app/src/main/AndroidManifest.xml`
- The banner placeholder in the Dashboard is a grey box — wire up real AdMob in Phase 5

---

## File Structure

```
lib/
├── main.dart                          # App entry, Riverpod scope, theme
├── theme/
│   └── app_theme.dart                 # All color tokens, text styles, ThemeData
├── models/
│   └── game_models.dart               # All data models (GameState, Dome, Crop, etc.)
├── database/
│   └── database_helper.dart           # SQLite schema and all CRUD operations
├── config/
│   └── game_config_service.dart       # Loads + caches game_config.json
├── providers/
│   └── game_providers.dart            # All Riverpod providers
├── utils/
│   └── game_factory.dart              # Creates new games and game objects
└── screens/
    ├── main_menu/
    │   └── main_menu_screen.dart      # Title screen, save slot list
    ├── new_game/
    │   └── new_game_screen.dart       # Farm name + difficulty selection
    └── save_slots/
        └── save_slot_detail_screen.dart  # Main game hub (all tabs)

assets/
└── config/
    └── game_config.json               # ALL game balance values — edit freely
```

---

## Tweaking game balance

Everything numeric lives in `assets/config/game_config.json`:
- Crop growth times, water usage, calorie values, solar prices
- Building costs and power draw
- Difficulty settings (starting resources, raid frequency, decay rates)
- Milestone targets and deadlines
- Trophy definitions
- Relay technician mood values and rant topics
- Enemy types and raid wave counts

**You do not need to touch Dart code to rebalance the game.**
Hot reload does not pick up asset changes — you need to hot restart (`R` in terminal) after editing the JSON.

---

## Phase Roadmap

| Phase | What gets built |
|-------|----------------|
| ✅ 1 | Foundation: models, DB, config, theme, main menu, new game, save/load/delete, game hub scaffold |
| 2 | Core loop: 3×3 dome grid, manual farming actions, End Week calculator, week summary screen |
| 3 | Economy: Refinery, Relay/Kovacs, buying/selling, contracts, Solars flow |
| 4 | Expansion: multiple domes, robots 1-5, power grid enforcement, raids + sentry mini-game |
| 5 | Polish: full Habitat screens, trophy room, milestones, difficulty modes, all 20 crops enabled |

---

## Known Phase 1 limitations (intentional)
- End Week button shows a snackbar — engine not built yet
- Dome/Refinery/Relay tabs are stubs with placeholder content
- AdMob is a grey box
- No pixel art yet — all emoji and text
- Crop actions (water, fertilize, harvest) not interactive yet
