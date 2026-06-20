// ═══════════════════════════════════════════════════════════════
//  lib/screens/main_menu/main_menu_screen.dart
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../score/score_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/game_models.dart';
import '../../providers/game_providers.dart';
import '../../theme/app_theme.dart';
import '../../config/game_config_service.dart';
import '../new_game/new_game_screen.dart';
import '../save_slots/save_slot_detail_screen.dart';
import '../../widgets/space_background.dart';

class MainMenuScreen extends ConsumerWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slotsAsync = ref.watch(saveSlotsProvider);
    final config = GameConfigService.instance;

    return Scaffold(
      backgroundColor: MFColors.background,
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              // ── Header / Title ──────────────────────────────────────────────
              const _GameTitle(),
              const SizedBox(height: 8),

              // ── Save Slots ──────────────────────────────────────────────────
              Expanded(
                child: slotsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: MFColors.neonCyan,
                      strokeWidth: 2,
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Text(
                      'Failed to load saves: $e',
                      style: MFTextStyles.bodyMedium,
                    ),
                  ),
                  data: (slots) {
                    // Slots 1-3 are manual saves. Slot 0 is autosave.
                    final manualSlots = slots.where((s) => s.slotNumber > 0).toList();
                    final autoSave =
                        slots.where((s) => s.slotNumber == 0).firstOrNull;

                    return ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      children: [
                        Text(
                          'SAVE SLOTS',
                          style: MFTextStyles.bodySmall.copyWith(
                            color: MFColors.textMuted,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...manualSlots.map(
                              (slot) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _SaveSlotCard(
                              slot: slot,
                              onTap: () => _handleSlotTap(context, ref, slot),
                              onDelete: slot.isEmpty
                                  ? null
                                  : () => _confirmDelete(context, ref, slot),
                            ),
                          ),
                        ),

                        // Autosave slot
                        if (autoSave != null && !autoSave.isEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'AUTOSAVE',
                            style: MFTextStyles.bodySmall.copyWith(
                              color: MFColors.textMuted,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _SaveSlotCard(
                            slot: autoSave,
                            isAutoSave: true,
                            onTap: () => _handleSlotTap(context, ref, autoSave),
                            onDelete: null,
                          ),
                        ],

                        const SizedBox(height: 24),
                        Text(
                          'THE STORY SO FAR',
                          style: MFTextStyles.bodySmall.copyWith(
                            color: MFColors.textMuted,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const _StoryBlurb(),
                      ],
                    );
                  },
                ),
              ),

              // ── Footer ──────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'v${config.gameVersion}',
                      style: MFTextStyles.bodySmall,
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () {
                        // URL launch handled in Phase 4 polish
                      },
                      child: Text(
                        config.websiteUrl,
                        style: MFTextStyles.bodySmall.copyWith(
                          color: MFColors.neonCyan,
                          decoration: TextDecoration.underline,
                          decorationColor: MFColors.neonCyan,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ), // Column
        ), // SafeArea
      ), // SpaceBackground
    );
  }

  void _handleSlotTap(BuildContext context, WidgetRef ref, SaveSlot slot) {
    if (slot.isEmpty) {
      // Start new game flow
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NewGameScreen(slotNumber: slot.slotNumber),
        ),
      );
    } else {
      // Load existing game
      _loadGame(context, ref, slot);
    }
  }

  Future<void> _loadGame(
      BuildContext context,
      WidgetRef ref,
      SaveSlot slot,
      ) async {
    await ref.read(activeGameProvider.notifier).loadGame(slot.slotNumber);
    if (!context.mounted) return;

    final game = ref.read(activeGameProvider).value;
    if (game != null && game.status == GameStatus.terminated) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ScoreScreen(game: game)),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SaveSlotDetailScreen()),
      );
    }
  }

  Future<void> _confirmDelete(
      BuildContext context,
      WidgetRef ref,
      SaveSlot slot,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MFColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: MFColors.neonPink, width: 1),
        ),
        title: Text(
          'DELETE SAVE?',
          style: MFTextStyles.headlineMedium.copyWith(
            color: MFColors.neonPink,
          ),
        ),
        content: Text(
          'Delete "${slot.farmName}"? This cannot be undone.',
          style: MFTextStyles.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: MFColors.neonPink,
              foregroundColor: MFColors.textOnDark,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(saveSlotsProvider.notifier).deleteSlot(slot.slotNumber);
    }
  }
}

// ─── Game Title Widget ────────────────────────────────────────────────────────

class _GameTitle extends StatelessWidget {
  const _GameTitle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: MFColors.borderSubtle, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Moon emoji as logo placeholder
          const Text('🌕', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 12),
          Text(
            'MOON FARM',
            style: MFTextStyles.displayLarge.copyWith(
              color: MFColors.neonCyan,
              letterSpacing: 8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'LUNAR AGRICULTURAL MANAGEMENT',
            style: MFTextStyles.bodySmall.copyWith(
              color: MFColors.textMuted,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Story So Far ─────────────────────────────────────────────────────────────

class _StoryBlurb extends StatelessWidget {
  const _StoryBlurb();

  static const _coordLines = [
    'PRIMARY ORBIT: Caelum-V [CLM-05]',
    'COORDINATES: Olanthe [CLM-05-C]',
    'SECTOR GRID: 4J',
    'TARGET HUB: X-OLN-4J-[undetermined]',
    'OUTPOST NAME: [undetermined]',
  ];

  static const _narrative =
      "You've been awarded a contract to work the land in Sector 4J, on the "
      "moon Olanthe, in orbit of Caelum-V.\n\n"
      "Also in orbit of Caelum-V is a Colony Ship: The Ark of Caelum (Official "
      "Registry: AC-Ring-01). They're waiting for Olanthe to finish "
      "terraforming before they attempt to inhabit it full-time. They can "
      "stay in orbit indefinitely, provided they have an influx of food. "
      "That's where you come in.\n\n"
      "There was no information given on the status of the prior contract "
      "holder at location 4J. However, The Ark sent down a group of S.E.E.D."
      "ers (Surface Environment Engineering Drones) to fabricate a basic "
      "setup for you: a farming dome, a small refinery with basic equipment, "
      "and a habitat.\n\n"
      "Your primary contact to the Colony is Specialist Kovacs. You have a "
      "Comms Relay tuned to his signal. Reach out to him when you need more "
      "seeds or have food ready to ship up.\n\n"
      "Good luck, moon farmer.";

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MFColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MFColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._coordLines.map((line) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              line,
              style: MFTextStyles.bodySmall.copyWith(
                color: MFColors.neonCyan,
                fontFamily: 'monospace',
                letterSpacing: 0.5,
              ),
            ),
          )),
          const SizedBox(height: 10),
          Container(height: 1, color: MFColors.borderSubtle),
          const SizedBox(height: 10),
          Text(
            _narrative,
            style: MFTextStyles.bodyMedium.copyWith(
              color: MFColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Save Slot Card ───────────────────────────────────────────────────────────

class _SaveSlotCard extends StatelessWidget {
  final SaveSlot slot;
  final bool isAutoSave;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _SaveSlotCard({
    required this.slot,
    this.isAutoSave = false,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MFColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: slot.isEmpty
                ? MFColors.borderSubtle
                : MFColors.borderDefault,
            width: 1,
          ),
        ),
        child: slot.isEmpty
            ? _EmptySlotContent(
          slotNumber: slot.slotNumber,
          isAutoSave: isAutoSave,
        )
            : _FilledSlotContent(
          slot: slot,
          isAutoSave: isAutoSave,
          onDelete: onDelete,
        ),
      ),
    );
  }
}

class _EmptySlotContent extends StatelessWidget {
  final int slotNumber;
  final bool isAutoSave;

  const _EmptySlotContent({
    required this.slotNumber,
    required this.isAutoSave,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            border: Border.all(color: MFColors.borderDefault),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Center(
            child: Icon(Icons.add, color: MFColors.textMuted, size: 20),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isAutoSave
                  ? 'NO AUTOSAVE'
                  : 'SLOT ${slotNumber} — EMPTY',
              style: MFTextStyles.labelLarge.copyWith(
                color: MFColors.textMuted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              isAutoSave ? '—' : 'Tap to start new game',
              style: MFTextStyles.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}

class _FilledSlotContent extends StatelessWidget {
  final SaveSlot slot;
  final bool isAutoSave;
  final VoidCallback? onDelete;

  const _FilledSlotContent({
    required this.slot,
    required this.isAutoSave,
    required this.onDelete,
  });

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.month}/${dt.day}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _difficultyLabel(Difficulty? d) {
    switch (d) {
      case Difficulty.easy: return '🟢 EASY';
      case Difficulty.normal: return '🟡 NORMAL';
      case Difficulty.hard: return '🔴 HARD';
      default: return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Slot icon
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            border: Border.all(color: MFColors.neonCyan),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              isAutoSave ? '🔄' : '🌕',
              style: const TextStyle(fontSize: 22),
            ),
          ),
        ),
        const SizedBox(width: 16),

        // Slot info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      slot.farmName ?? 'Unknown Farm',
                      style: MFTextStyles.labelLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isAutoSave)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: MFColors.neonYellow),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'AUTO',
                        style: MFTextStyles.bodySmall.copyWith(
                          color: MFColors.neonYellow,
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                'Week ${slot.currentWeek ?? 1}  ·  ${_difficultyLabel(slot.difficulty)}',
                style: MFTextStyles.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${slot.totalScrip?.toInt() ?? 0} 🎫 Star-Scrip',
                style: MFTextStyles.bodySmall.copyWith(
                  color: MFColors.starScrip,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Saved ${_formatDate(slot.lastSaved)}',
                style: MFTextStyles.bodySmall.copyWith(
                  color: MFColors.textMuted,
                ),
              ),
            ],
          ),
        ),

        // Delete button (only for manual slots)
        if (onDelete != null) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(8),
              child: const Icon(
                Icons.delete_outline,
                color: MFColors.neonPink,
                size: 18,
              ),
            ),
          ),
        ],
      ],
    );
  }
}