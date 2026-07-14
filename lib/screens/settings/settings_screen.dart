// ═══════════════════════════════════════════════════════════════
//  lib/screens/settings/settings_screen.dart
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../config/settings_service.dart';
import '../../providers/settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: MFColors.background,
      appBar: AppBar(
        title: const Text('SETTINGS'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: MFColors.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsSection(
            title: 'DISPLAY',
            children: [
              _TextScaleRow(
                value: settings.textScale,
                onChanged: notifier.setTextScale,
              ),
              const SizedBox(height: 16),
              _ChoiceRow<AppThemeMode>(
                label: 'Theme',
                value: settings.themeMode,
                options: AppThemeMode.values,
                labelOf: (v) => v.label,
                onChanged: notifier.setThemeMode,
                caption: 'Switching reopens the app to the Main Menu.',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: 'GAMEPLAY',
            children: [
              _SwitchRow(
                label: 'Confirm before destructive actions',
                subtitle: 'Sell All, Clear Crop, Cancel Contract',
                value: settings.confirmDialogs,
                onChanged: notifier.setConfirmDialogs,
              ),
              const SizedBox(height: 16),
              _ChoiceRow<RaidSpeed>(
                label: 'Raid Speed',
                value: settings.raidSpeed,
                options: RaidSpeed.values,
                labelOf: (v) => v.label,
                onChanged: notifier.setRaidSpeed,
                caption: 'Applies the next time you start a raid.',
              ),
              const SizedBox(height: 16),
              _ChoiceRow<AutoSaveFrequency>(
                label: 'Auto-Save Frequency',
                value: settings.autoSaveFrequency,
                options: AutoSaveFrequency.values,
                labelOf: (v) => v.label,
                onChanged: notifier.setAutoSaveFrequency,
                caption: 'Your manual save slot is always updated every '
                    'week regardless — this only controls the separate '
                    'autosave backup.',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: 'LANGUAGE',
            children: [
              _ChoiceRow<AppLanguage>(
                label: 'Language',
                value: settings.language,
                options: AppLanguage.values,
                labelOf: (v) => v.label,
                onChanged: null, // coming soon — see caption
                caption: 'Spanish translations aren\'t written yet. This '
                    'choice is saved for when they are.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Section container ─────────────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MFColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MFColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: MFTextStyles.bodySmall.copyWith(
              color: MFColors.textMuted,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

// ─── Switch row ─────────────────────────────────────────────────────────────

class _SwitchRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: MFTextStyles.bodyLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!,
                    style: MFTextStyles.bodySmall.copyWith(color: MFColors.textMuted)),
              ],
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: MFColors.neonCyan,
        ),
      ],
    );
  }
}

// ─── Text scale row ─────────────────────────────────────────────────────────

class _TextScaleRow extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  static const _steps = [0.85, 1.0, 1.15, 1.3];
  static const _labels = ['Small', 'Normal', 'Large', 'XL'];

  const _TextScaleRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final closestIndex = _steps.indexOf(
      _steps.reduce((a, b) => (a - value).abs() < (b - value).abs() ? a : b),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Text Size', style: MFTextStyles.bodyLarge),
        const SizedBox(height: 8),
        Row(
          children: List.generate(_steps.length, (i) {
            final selected = i == closestIndex;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < _steps.length - 1 ? 8 : 0),
                child: GestureDetector(
                  onTap: () => onChanged(_steps[i]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? MFColors.neonCyan.withValues(alpha: 0.15)
                          : MFColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: selected ? MFColors.neonCyan : MFColors.borderSubtle,
                      ),
                    ),
                    child: Text(
                      _labels[i],
                      style: MFTextStyles.bodyMedium.copyWith(
                        color: selected ? MFColors.neonCyan : MFColors.textSecondary,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ─── Generic choice row (enum picker) ──────────────────────────────────────

class _ChoiceRow<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T>? onChanged; // null = disabled / coming soon
  final String? caption;

  const _ChoiceRow({
    required this.label,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onChanged == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: MFTextStyles.bodyLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((o) {
            final selected = o == value;
            final color = disabled
                ? (selected ? MFColors.textSecondary : MFColors.textMuted)
                : (selected ? MFColors.neonCyan : MFColors.textSecondary);
            return GestureDetector(
              onTap: disabled ? null : () => onChanged!(o),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected && !disabled
                      ? MFColors.neonCyan.withValues(alpha: 0.15)
                      : MFColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: selected
                        ? (disabled ? MFColors.borderDefault : MFColors.neonCyan)
                        : MFColors.borderSubtle,
                  ),
                ),
                child: Text(
                  labelOf(o),
                  style: MFTextStyles.bodyMedium.copyWith(
                    color: color,
                    fontWeight: selected && !disabled ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (caption != null) ...[
          const SizedBox(height: 6),
          Text(caption!, style: MFTextStyles.bodySmall.copyWith(color: MFColors.textMuted)),
        ],
      ],
    );
  }
}
