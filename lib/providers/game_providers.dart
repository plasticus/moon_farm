// ═══════════════════════════════════════════════════════════════
//  lib/providers/game_providers.dart
// ═══════════════════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart'; // StateProvider moved to legacy in Riverpod 3
import '../models/game_models.dart';
import '../database/database_helper.dart';
import '../config/game_config_service.dart';
import '../config/raid_config_service.dart';
import '../engine/kovacs_engine.dart';

// ─── Save Slots Provider ──────────────────────────────────────────────────────

final saveSlotsProvider =
AsyncNotifierProvider<SaveSlotsNotifier, List<SaveSlot>>(
  SaveSlotsNotifier.new,
);

class SaveSlotsNotifier extends AsyncNotifier<List<SaveSlot>> {
  @override
  Future<List<SaveSlot>> build() async {
    return await DatabaseHelper.instance.getAllSaveSlots();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
          () => DatabaseHelper.instance.getAllSaveSlots(),
    );
  }

  Future<void> deleteSlot(int slotNumber) async {
    await DatabaseHelper.instance.clearSaveSlot(slotNumber);
    await refresh();
  }
}

// ─── Active Game Provider ─────────────────────────────────────────────────────

final activeGameProvider =
AsyncNotifierProvider<ActiveGameNotifier, GameState?>(
  ActiveGameNotifier.new,
);

class ActiveGameNotifier extends AsyncNotifier<GameState?> {
  @override
  Future<GameState?> build() async {
    return null; // No game loaded at app start
  }

  /// Load an existing game from a save slot
  Future<void> loadGame(int slotNumber) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
          () => DatabaseHelper.instance.loadGameState(slotNumber),
    );
  }

  /// Start a brand new game in a slot
  Future<void> startNewGame(GameState newGame) async {
    state = const AsyncLoading();
    await DatabaseHelper.instance.saveGameState(newGame);
    state = AsyncValue.data(newGame);
  }

  /// Update game state and persist (call after every meaningful action)
  Future<void> updateGame(GameState updatedState) async {
    final saved = updatedState.copyWith(lastSaved: DateTime.now());
    state = AsyncValue.data(saved);
    await DatabaseHelper.instance.saveGameState(saved);

    // Also write to autosave slot (slot 0) if this is a manual slot
    if (saved.slotNumber != 0) {
      final autoSave = saved.copyWith(slotNumber: 0);
      await DatabaseHelper.instance.saveGameState(autoSave);
    }
  }

  /// Update game state in memory only (for mid-turn actions, save on End Week)
  void updateGameLocal(GameState updatedState) {
    state = AsyncValue.data(updatedState);
  }

  /// Persist current in-memory state to disk
  Future<void> persistCurrentState() async {
    final current = state.value;
    if (current == null) return;
    final saved = current.copyWith(lastSaved: DateTime.now());
    state = AsyncValue.data(saved);
    await DatabaseHelper.instance.saveGameState(saved);
    if (saved.slotNumber != 0) {
      await DatabaseHelper.instance.saveGameState(
        saved.copyWith(slotNumber: 0),
      );
    }
  }

  void clearGame() {
    state = const AsyncValue.data(null);
  }
}

// ─── Config Loaded Provider ───────────────────────────────────────────────────

final configLoadedProvider = FutureProvider<bool>((ref) async {
  await GameConfigService.instance.initialize();
  return true;
});

// ─── Derived Providers (computed from game state) ─────────────────────────────

/// Current week number
final currentWeekProvider = Provider<int>((ref) {
  return ref.watch(activeGameProvider).value?.currentWeek ?? 1;
});

/// Current solar balance
final starScripProvider = Provider<int>((ref) {
  return ref.watch(activeGameProvider).value?.resources.starScrip ?? 0;
});

/// Power surplus/deficit
final powerSurplusProvider = Provider<int>((ref) {
  return ref.watch(activeGameProvider).value?.powerSurplus ?? 0;
});

/// All domes
final domesProvider = Provider<List<Dome>>((ref) {
  return ref.watch(activeGameProvider).value?.domes ?? [];
});

/// Specific dome by id
final domeByIdProvider = Provider.family<Dome?, String>((ref, id) {
  final domes = ref.watch(domesProvider);
  try {
    return domes.firstWhere((d) => d.id == id);
  } catch (_) {
    return null;
  }
});

/// Active contracts
final activeContractsProvider = Provider<List<Contract>>((ref) {
  return ref.watch(activeGameProvider).value?.activeContracts ?? [];
});

/// Active milestones (pending ones)
final pendingMilestonesProvider = Provider<List<Milestone>>((ref) {
  return ref
      .watch(activeGameProvider)
      .value
      ?.milestones
      .where((m) => m.status == MilestoneStatus.pending)
      .toList() ??
      [];
});

/// Is raid coming soon?
final raidWarningProvider = Provider<bool>((ref) {
  final game = ref.watch(activeGameProvider).value;
  if (game == null) return false;
  final warningWeeks = RaidConfigService.instance.raidWarningWeeksBefore;
  return game.nextRaidWeek - game.currentWeek <= warningWeeks &&
      game.nextRaidWeek > game.currentWeek;
});

/// Is this a raid week (must defend before end week)?
final isRaidWeekProvider = Provider<bool>((ref) {
  final game = ref.watch(activeGameProvider).value;
  if (game == null) return false;
  return game.currentWeek >= game.nextRaidWeek && !game.raidDefendedThisWeek;
});

/// Relay technician state
final relayProvider = Provider<RelayTechnicianState?>((ref) {
  return ref.watch(activeGameProvider).value?.relay;
});

/// Radio feed (unread count)
final unreadRadioCountProvider = Provider<int>((ref) {
  return ref
      .watch(activeGameProvider)
      .value
      ?.radioFeed
      .where((r) => !r.isRead)
      .length ??
      0;
});

/// Pending sales
final pendingSalesProvider = Provider<List<PendingSale>>((ref) {
  return ref.watch(activeGameProvider).value?.pendingSales ?? [];
});

/// Week summary (set after end-week calculation, cleared on new week)
final weekSummaryProvider = StateProvider<WeekSummary?>((ref) => null);

/// UI state: which dome is currently being viewed (index)
final activeDomeIndexProvider = StateProvider<int>((ref) => 0);

/// UI state: selected dome action tool
final selectedDomeActionProvider = StateProvider<String?>((ref) => null);

/// UI state: loading state for end-week calculation
final endWeekLoadingProvider = StateProvider<bool>((ref) => false);

/// Kovacs conversation state — persists across navigation within the same week.
/// Reset to null by end_week_engine each week.
final kovacsConversationProvider = StateProvider<KovacsConversation?>((ref) => null);