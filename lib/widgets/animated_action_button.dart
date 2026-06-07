// ═══════════════════════════════════════════════════════════════
//  lib/widgets/animated_action_button.dart
// ═══════════════════════════════════════════════════════════════
// Hops on success, shakes on failure, shows missing resource snackbar.

import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AnimatedActionButton extends StatefulWidget {
  final String label;
  final bool canAfford;
  final Color color;
  final String missingText;
  final VoidCallback? onTap;

  const AnimatedActionButton({
    super.key,
    required this.label,
    required this.canAfford,
    required this.color,
    this.missingText = '',
    this.onTap,
  });

  @override
  State<AnimatedActionButton> createState() => AnimatedActionButtonState();
}

class AnimatedActionButtonState extends State<AnimatedActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.canAfford) {
      setState(() => _isSuccess = true);
      _controller.forward(from: 0).then((_) {
        if (mounted) setState(() => _isSuccess = false);
      });
      widget.onTap?.call();
    } else {
      setState(() => _isSuccess = false);
      _controller.forward(from: 0).then((_) {
        if (mounted) _controller.reset();
      });
      if (widget.missingText.isNotEmpty) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.missingText),
            duration: const Duration(seconds: 2),
            backgroundColor: MFColors.surfaceElevated,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        double dx = 0, dy = 0;
        if (_isSuccess) {
          dy = -sin(_controller.value * pi) * 8.0;
        } else if (_controller.isAnimating) {
          dx = sin(_controller.value * pi * 4) * 6.0;
        }
        return Transform.translate(offset: Offset(dx, dy), child: child);
      },
      child: GestureDetector(
        onTap: _handleTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.canAfford
                ? widget.color.withValues(alpha: 0.12)
                : MFColors.borderSubtle,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.canAfford
                  ? widget.color.withValues(alpha: 0.5)
                  : MFColors.borderSubtle,
            ),
          ),
          child: Text(
            widget.label,
            style: MFTextStyles.bodySmall.copyWith(
              color: widget.canAfford ? widget.color : MFColors.textMuted,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}