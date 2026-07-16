// ═══════════════════════════════════════════════════════════════
//  lib/screens/new_game/new_game_screen.dart
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';
import '../../models/game_models.dart';
import '../../providers/game_providers.dart';
import '../../theme/app_theme.dart';
import '../../config/game_config_service.dart';
import '../../utils/game_factory.dart';
import '../save_slots/save_slot_detail_screen.dart';

class NewGameScreen extends ConsumerStatefulWidget {
  final int slotNumber;

  const NewGameScreen({super.key, required this.slotNumber});

  @override
  ConsumerState<NewGameScreen> createState() => _NewGameScreenState();
}

class _NewGameScreenState extends ConsumerState<NewGameScreen> {
  final _nameController = TextEditingController();
  Difficulty _selectedDifficulty = Difficulty.normal;
  bool _isCreating = false;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    // Pre-populate with a random name suggestion
    _suggestRandomName();
  }

  void _suggestRandomName() {
    final suggestions = GameConfigService.instance
        .getFarmNameSuggestions();
    if (suggestions.isNotEmpty) {
      final name = suggestions[Random().nextInt(suggestions.length)];
      _nameController.text = name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canCreate {
    return _nameController.text.trim().isNotEmpty && !_isCreating;
  }

  Future<void> _createGame() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Please name your farm.');
      return;
    }
    if (name.length > 32) {
      setState(() => _nameError = 'Max 32 characters.');
      return;
    }

    setState(() {
      _isCreating = true;
      _nameError = null;
    });

    final newGame = GameFactory.createNewGame(
      slotNumber: widget.slotNumber,
      farmName: name,
      difficulty: _selectedDifficulty,
    );

    await ref.read(activeGameProvider.notifier).startNewGame(newGame);
    await ref.read(saveSlotsProvider.notifier).refresh();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SaveSlotDetailScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MFColors.background,
      appBar: AppBar(
        title: const Text('NEW GAME'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: MFColors.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // ── Moon icon ──────────────────────────────────────────────────
            const Center(
              child: Text('🌕', style: TextStyle(fontSize: 56)),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'SLOT ${widget.slotNumber}',
                style: MFTextStyles.bodySmall.copyWith(
                  color: MFColors.textMuted,
                  letterSpacing: 3,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ── Farm name ──────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'FARM NAME',
                  style: MFTextStyles.bodySmall.copyWith(
                    color: MFColors.textMuted,
                    letterSpacing: 2,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() => _nameError = null);
                    _suggestRandomName();
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shuffle, color: MFColors.neonCyan, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'SUGGEST',
                        style: MFTextStyles.bodySmall.copyWith(
                          color: MFColors.neonCyan,
                          fontSize: 10,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              maxLength: 27,
              style: MFTextStyles.bodyLarge,
              decoration: InputDecoration(
                hintText: 'Name your operation...',
                errorText: _nameError,
                counterStyle: MFTextStyles.bodySmall,
              ),
              onChanged: (_) => setState(() => _nameError = null),
              textCapitalization: TextCapitalization.words,
            ),
            Text(
              'Displays as "${_nameController.text.isEmpty ? 'Your Farm' : _nameController.text} (4J)" — that\'s your callsign. Radio chatter and Kovacs both use it.',
              style: MFTextStyles.bodySmall.copyWith(color: MFColors.textMuted),
            ),
            const SizedBox(height: 32),

            // ── Difficulty ─────────────────────────────────────────────────
            Text(
              'DIFFICULTY',
              style: MFTextStyles.bodySmall.copyWith(
                color: MFColors.textMuted,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            ...Difficulty.values.map(
                  (d) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DifficultyOption(
                  difficulty: d,
                  isSelected: _selectedDifficulty == d,
                  onTap: () => setState(() => _selectedDifficulty = d),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ── Create button ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canCreate ? _createGame : null,
                child: _isCreating
                    ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: MFColors.background,
                  ),
                )
                    : const Text('BEGIN OPERATION'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Difficulty Option Card ───────────────────────────────────────────────────

class _DifficultyOption extends StatelessWidget {
  final Difficulty difficulty;
  final bool isSelected;
  final VoidCallback onTap;

  const _DifficultyOption({
    required this.difficulty,
    required this.isSelected,
    required this.onTap,
  });

  String get _emoji {
    switch (difficulty) {
      case Difficulty.easy: return '🟢';
      case Difficulty.normal: return '🟡';
      case Difficulty.hard: return '🔴';
    }
  }

  String get _label {
    switch (difficulty) {
      case Difficulty.easy: return 'EASY';
      case Difficulty.normal: return 'NORMAL';
      case Difficulty.hard: return 'HARD';
    }
  }

  String get _description {
    switch (difficulty) {
      case Difficulty.easy:
        return 'Relaxed milestones. No raid penalties. Your contract is permanent. '
            'Perfect for learning the systems.';
      case Difficulty.normal:
        return 'Standard balance. Regular fauna raids. '
            'Miss 3 milestones in a row and the colony pulls your contract.';
      case Difficulty.hard:
        return 'Relentless raids. Razor-thin deadlines. Fast crop decay. '
            'One missed milestone ends your operation.';
    }
  }

  Color get _accentColor {
    switch (difficulty) {
      case Difficulty.easy: return MFColors.statusOptimal;
      case Difficulty.normal: return MFColors.statusWarning;
      case Difficulty.hard: return MFColors.statusCritical;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? _accentColor.withValues(alpha: 0.08)
              : MFColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? _accentColor : MFColors.borderSubtle,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(_emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _label,
                    style: MFTextStyles.labelLarge.copyWith(
                      color: isSelected ? _accentColor : MFColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(_description, style: MFTextStyles.bodySmall),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: _accentColor, size: 20),
          ],
        ),
      ),
    );
  }
}