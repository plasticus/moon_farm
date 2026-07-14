// ═══════════════════════════════════════════════════════════════
//  lib/widgets/confirm_dialog.dart
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/settings_providers.dart';

/// Shows an "are you sure?" dialog before a destructive action, unless the
/// player has turned confirmations off in Settings — in which case this
/// resolves to true immediately. Returns true if the action should proceed.
Future<bool> confirmIfNeeded(
    BuildContext context,
    WidgetRef ref, {
      required String title,
      required String message,
      String confirmLabel = 'CONFIRM',
    }) async {
  if (!ref.read(settingsProvider).confirmDialogs) return true;

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: MFColors.surfaceElevated,
      title: Text(title),
      content: Text(message, style: MFTextStyles.bodyMedium),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('CANCEL'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel, style: TextStyle(color: MFColors.neonPink)),
        ),
      ],
    ),
  );
  return result == true;
}
