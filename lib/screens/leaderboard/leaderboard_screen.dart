// ═══════════════════════════════════════════════════════════════
//  lib/screens/leaderboard/leaderboard_screen.dart
// ═══════════════════════════════════════════════════════════════
// Super simple leaderboard: a hardcoded list of joke entries (fake
// ships/colonies with fake scores to beat) merged with whatever finished
// games (won or terminated) currently sit in this device's 3 manual save
// slots. No separate persistence — recomputed fresh every time the
// screen opens, so it just reflects whatever's on disk right now.

import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/game_models.dart';
import '../../theme/app_theme.dart';
import '../score/score_screen.dart';

class _LeaderboardEntry {
  final String name;
  final int score;
  final bool isPlayer;
  const _LeaderboardEntry(this.name, this.score, {this.isPlayer = false});
}

// Fake competition — flavor riffs on the colony contract/indenture theme.
// Spans the full grade range so there's always something just barely
// beatable, whatever week you're on.
const _jokeEntries = [
  _LeaderboardEntry('SS Nostalgia For Dirt', 1250000),
  _LeaderboardEntry("Barnaby's Retirement Fund", 780000),
  _LeaderboardEntry('Colony Contract 4J-000 (Original)', 610000),
  _LeaderboardEntry('The Indenture Never Ends', 340000),
  _LeaderboardEntry('MSV Second Mortgage', 215000),
  _LeaderboardEntry('Sunk Cost Station', 165000),
  _LeaderboardEntry('Outpost Overextended', 110000),
  _LeaderboardEntry('The Reluctant Harvest', 72000),
  _LeaderboardEntry("Kovacs' Personal Best (Allegedly)", 58000),
  _LeaderboardEntry("Freighter 'Perpetually Late'", 41000),
  _LeaderboardEntry('Farmstead Zero', 28000),
  _LeaderboardEntry('Domebot Prototype Run', 15500),
  _LeaderboardEntry('The One That Got Raided', 6200),
  _LeaderboardEntry("Tutorial Save, Don't Judge", 900),
];

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  Future<List<_LeaderboardEntry>> _load() async {
    final db = DatabaseHelper.instance;
    final entries = <_LeaderboardEntry>[..._jokeEntries];

    for (final slot in [1, 2, 3]) {
      final state = await db.loadGameState(slot);
      if (state == null || state.status == GameStatus.active) continue;
      entries.add(_LeaderboardEntry(
        state.displayName,
        ScoreScreen.calculateScore(state),
        isPlayer: true,
      ));
    }

    entries.sort((a, b) => b.score.compareTo(a.score));
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MFColors.background,
      appBar: AppBar(
        title: const Text('LEADERBOARD'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: MFColors.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FutureBuilder<List<_LeaderboardEntry>>(
        future: _load(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(color: MFColors.neonCyan),
            );
          }
          final entries = snapshot.data!;
          final hasPlayerEntry = entries.any((e) => e.isPlayer);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                hasPlayerEntry
                    ? 'Scores from finished contracts on this device, '
                      'stacked up against some... optimistic self-reported '
                      'numbers from other outfits.'
                    : "Nobody on this device has finished a contract yet — "
                      "win or lose one to add your name here. Until then, "
                      "here's who you're up against.",
                style: MFTextStyles.bodySmall.copyWith(color: MFColors.textMuted),
              ),
              const SizedBox(height: 16),
              ...entries.indexed.map((rec) {
                final (i, e) = rec;
                final rank = i + 1;
                final grade = ScoreScreen.scoreGrade(e.score);
                final color = ScoreScreen.gradeColor(grade);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: e.isPlayer
                        ? MFColors.neonCyan.withValues(alpha: 0.08)
                        : MFColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: e.isPlayer
                          ? MFColors.neonCyan.withValues(alpha: 0.5)
                          : MFColors.borderDefault,
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text('$rank',
                            style: MFTextStyles.labelLarge.copyWith(
                                color: MFColors.textMuted, fontSize: 14)),
                      ),
                      Expanded(
                        child: Text(
                          e.name,
                          style: MFTextStyles.bodyMedium.copyWith(
                            fontWeight: e.isPlayer ? FontWeight.bold : FontWeight.normal,
                            color: e.isPlayer ? MFColors.neonCyan : MFColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(_formatScore(e.score),
                          style: MFTextStyles.labelLarge.copyWith(fontSize: 13)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(grade,
                            style: TextStyle(
                                color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  String _formatScore(int score) {
    final s = score.toString();
    final parts = <String>[];
    for (int i = s.length; i > 0; i -= 3) {
      parts.insert(0, s.substring((i - 3).clamp(0, s.length), i));
    }
    return parts.join(',');
  }
}
