# Moon Farm — Phase 5 Plan

---

## Win Condition

The final milestone is a lifetime scrip target, tuned to take approximately 200 weeks on Normal difficulty to reach. When it completes, the game doesn't end immediately — Kovacs sends a final transmission, you get a story screen ("you bought the farm, hired a manager, retired to a resort world on Caelum-V"), then the score screen. The save is then marked as won (similar to how terminated saves are marked), and the main menu slot card shows a distinct visual.

The existing `lifetimeScripEarned` field already tracks this. The milestone engine already processes completion. No new tracking fields needed — just a new milestone entry in `milestone_config.yaml` and a win-state branch in the end-week engine.

---

## New Milestone Types

All go into `milestone_config.yaml`. The existing milestone engine checks them each week. New `check_type` values will need to be added to `MilestoneConfigService` and the engine's milestone evaluation block for types that don't exist yet.

| Milestone | Check | Notes |
|---|---|---|
| Power capacity | `game.totalPowerProduction >= target` | Field already exists |
| Contracts completed | `game.completedContracts.length >= target` | Already tracked |
| Fauna killed | `game.totalFaunaKilled >= target` | Already tracked |
| Monuments built | total monument count >= target | New field needed on GameState |
| Kovacs dialogue unlocks | specific topic ID in `relay.unlockedTopicIds` | One milestone per major topic |
| Kovacs max mood | `hasReachedMaxMood` bool on RelayTechnicianState | Mood fluctuates — can't check current value |
| Kovacs min mood | `hasReachedMinMood` bool | Badge of shame. Worth a surprising amount of score. |
| Crop diversity T1–T5 | all crop IDs of that tier present in `totalCropHarvestCounts` | One milestone per tier, no new fields needed |
| Scrap baron | new `totalScrapSoldDam3` float on GameState | Incremented in end-week engine on scrap payout |
| Full automation | domes with Mk4 bot >= target | Thresholds: 4, 8, 12, 16, 20, 24, 28, 32, 36, 40 |

---

## Score

Score is calculated fresh at end of game (win or loss) from the final GameState. Not stored as a running number — derived on the fly. The "running estimate" in the Stats tab uses the same calculation mid-game.

### Components

- **Difficulty multiplier** — applied to the entire final score. Easy ×1.0, Normal ×2.0, Hard ×3.5. The single biggest lever on your score.
- **Lifetime scrip earned** — `lifetimeScripEarned`, already tracked.
- **Total m³ delivered** — `totalVolumeDeliveredM3`, already tracked.
- **Total fauna killed** — `totalFaunaKilled`, already tracked.
- **Total crops harvested** — `totalCropsHarvested`, already tracked.
- **Milestones completed** — each completed milestone adds a flat score value. Higher-tier milestones worth more. Values defined in `milestone_config.yaml`.
- **Monuments built** — total monument count × per-type score value. Mk10 worth significantly more than Mk1. Primary score multiplier for endgame players.
- **Final milestone speed bonus** — win-only. `(targetWeek - actualWeek) × pointsPerWeekEarly`. Hit the scrip target at week 180 instead of 200 and you get a meaningful bonus.

### Local High Score Table

Stores the top 5 completed runs per difficulty in `shared_preferences`. Each entry: farm name, final score, week completed, key stats summary. Shown in a "Records" section on the Score screen. No cloud, no external comparison.

---

## Monuments

A new buildable category accessed from a new tab in Habitat (between Radio and Stats — label TBD, something short).

- **10 types**, Mk1–Mk10. Each is a distinct structure with a name and Olathian lore flavor text.
- **Repeatable** — you can build multiple of the same type.
- **Build cost** scales steeply with Mk level. Resources: moon soil, metals, water — deliberately the same things you'd sell as scrap or run through the refinery. Late-game scrip sink alternative.
- **Score value** — each monument has a base score contribution. Mk10 is worth significantly more than Mk1. This is the primary way serious players push their score.
- **Monument Viewing Room** — displays all monuments built this run. The pride wall of the save, replacing trophies.
- GameState needs a `List<Monument>` field (new model: id, mk level, weekBuilt). Persisted through the existing serialization system.

---

## Trophies

Remove entirely. Monuments replace them.

- Delete `trophies` field from GameState, the Trophy model class, all serialization, the Habitat trophy tab, and all end-week trophy unlock logic.
- Convert applicable trophy checks (e.g. `robot_army`) to milestone entries where appropriate.
- Clean deletion pass — approximately 200–300 lines removed.

---

## Kovacs — Extended Integration

This section is intentionally open-ended and needs a focused design session before implementation. The goal is to make Kovacs feel like a genuine presence across the full 200-week run, not just the first 20 weeks.

- **New long-game dialogue tiers** — currently dialogue unlocks via topic chains. Phase 5 adds content gated behind week thresholds (e.g. week 50+, week 100+), so long-term players keep discovering new things. New topic entries in `kovacs_dialog.json`, new week-gate conditions in the engine.
- **Mood integration design session** — mood currently affects prices and some dialogue options. Open questions: does low mood cause Kovacs to withhold seeds from the buy screen? Does high mood give early raid warnings? Does mood affect contract quality offered? These need to feel meaningful without being punishing.
- **Milestone: unlock each major dialogue topic** — tracked via `relay.unlockedTopicIds`. Need to decide which topic IDs count as "major."
- **Milestone: Elated** — `hasReachedMaxMood` bool persisted on RelayTechnicianState.
- **Milestone: Rock Bottom** — same pattern. `hasReachedMinMood`. Worth a surprising score bonus for the audacity.

---

## Radio

- **Milestone radio triggers** — each milestone completion fires a dedicated transmission themed around that achievement. Goes in `radio_triggers.toml` using a new `milestone_completed` trigger kind (needs adding to `radio_trigger_engine.dart`). Written in the same Olathian-world voice as the rest of the pool.
- **Expand `radio_pool.toml`** — more flavor text, more Kovacs personal log entries, more colony broadcast variety.

---

## Stats Tab

- **Running score** — same calculation as end-game score, computed live from current GameState. Shown as "Estimated Score" with a note that the difficulty multiplier applies at completion.
- **Farm History** — chronological list of every milestone completed this run, with the week it was achieved. e.g. "W12 — First Shipment", "W47 — First T5 Dome". Stored as `List<MilestoneEvent>` (milestoneId + weekAchieved) on GameState. Replaces the trophy display being removed.

---

## Settings Screen

`settings_config.yaml` stub already exists. Phase 5 wires it up with a real UI and actual game effects.

| Setting | Details |
|---|---|
| Light/dark mode | `MFColors` already centralizes all colors in `app_theme.dart`. Light mode = alternate color set, swapped at runtime via a Riverpod provider. Mostly mechanical. |
| Text size | Scale factor applied to `MFTextStyles`. Affects all text. |
| Confirm dialogs | Gates "are you sure?" prompts on Sell All, Clear Crop, Cancel Contract. Currently always shown. |
| Raid speed | Multiplier on game tick rate in `RaidScreen`. Normal ×1, Fast ×2, Turbo ×3. Read at raid start. |
| Auto-save frequency | Currently saves every week. Options: every 1/5/10 weeks, or manual only. |
| Language | English / Spanish toggle. See Localization section. |

---

## Localization

- **Spanish** as first non-English language. Flutter's built-in `intl` package (already in pubspec) with ARB files.
- All UI strings need extraction to ARB files. Config-driven display text (crop names, milestone names) gets parallel Spanish entries or a language-key structure.
- `kovacs_dialog.json` and `radio_pool.toml` need Spanish variants — Kovacs' voice needs to translate, not just his words. This is a significant creative writing task.
- Adding future languages (French, Portuguese) after Spanish is just a new ARB file.

---

## Play Store Prep

- Release keystore signing (currently debug-only builds)
- Store listing: title, short description, long description, content rating questionnaire
- Screenshots: minimum 2 per form factor, recommend 4–5 (dashboard, raid, relay/Kovacs, dome management)
- Privacy policy URL already linked in-app at `moonfarm.oaf.monster`

---

## Dependency Cleanup

- `flutter pub upgrade` — blocked until share_plus resolves its KGP warning upstream. Monitor and run when a clean version ships.
- Remove remaining stale transitive packages once major deps are upgraded.

---

## Maybe / To Be Considered

### New Game+ / Prestige
After winning, offer a fresh start with a small permanent bonus — Kovacs starts at higher mood, or a starting resource bonus. Gives the win screen a "what next" answer beyond just looking at your score. Needs a `prestigeCount` field on GameState and a prestige bonus table. Design needs thought before committing.

### Kovacs Gifting System
Spend scrip to send Kovacs care packages for a one-time mood boost. Functions as a scrip sink in the late game when scrip is abundant. Needs a new buy option on the Relay screen, a cooldown to prevent spamming, and a mood cap so gifts alone can't max him out. Good depth addition but needs design work.

### Seasonal Events
Occasional week-long modifiers that fire via the radio trigger system using a new `seasonal_event` trigger kind. The week before, a radio warning fires. Examples:

- **Caelum Dust Storm** — solar array output drops 50% for 1 week.
- **Colony Founders Day** — Kovacs pays a 15% bonus on all sales that ship window.
- **Fauna Migration Season** — that week's raid wave is 1.5× larger but drops double chitin. High risk, high reward.

### Save Slot Name Editing
Let the player rename their farm after starting. Small UI addition to the main menu slot card (long-press or edit icon). Farm name is stored in both GameState and the `save_slots` metadata table — both need updating on rename.
