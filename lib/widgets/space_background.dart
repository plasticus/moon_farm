// ═══════════════════════════════════════════════════════════════
//  lib/widgets/space_background.dart
// ═══════════════════════════════════════════════════════════════
// Ambient space background: parallax starfield + purple horizon arc.
// Usage:
//   SpaceBackground(
//     scrollController: _scrollController, // optional, enables parallax
//     child: YourWidget(),
//   )

import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ─── Star data ────────────────────────────────────────────────────────────────

class _Star {
  final double x;        // 0.0–1.0 normalized screen position
  final double y;        // 0.0–1.0 normalized screen position
  final double size;     // radius in logical pixels
  final double opacity;  // base opacity
  final double phase;    // twinkle phase offset (0.0–2π)
  final double speed;    // twinkle speed multiplier
  final double layer;    // 0.0 = far (slow parallax), 1.0 = close (fast)

  const _Star({
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    required this.phase,
    required this.speed,
    required this.layer,
  });
}

// ─── Painter ──────────────────────────────────────────────────────────────────

class _SpacePainter extends CustomPainter {
  final List<_Star> stars;
  final double twinkleValue;   // 0.0–1.0 from AnimationController
  final double scrollOffset;   // pixels scrolled, drives parallax
  final double maxScroll;      // max scroll extent for horizon reveal

  _SpacePainter({
    required this.stars,
    required this.twinkleValue,
    required this.scrollOffset,
    required this.maxScroll,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawStars(canvas, size);
    _drawHorizon(canvas, size);
  }

  void _drawStars(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    // Night sky: bright stars on black. Lunar daylight: no visible stars —
    // there's no atmosphere to scatter light, but direct sun washes out
    // anything this dim, so these read as faint dust motes catching glare
    // instead, muted enough not to fight the pale sky.
    final isLight = MFColors.isLight;

    for (final star in stars) {
      // Parallax: far stars (layer≈0) barely move, close stars (layer≈1) shift more
      final parallaxShift = scrollOffset * (0.02 + star.layer * 0.06);
      final px = star.x * size.width;
      final py = (star.y * size.height) - parallaxShift;

      // Skip stars scrolled off screen
      if (py < -4 || py > size.height + 4) continue;

      // Twinkle: each star has a unique phase so they don't sync
      final twinkle = sin((twinkleValue * 2 * pi * star.speed) + star.phase);
      final baseOpacity = (star.opacity + twinkle * 0.15).clamp(0.05, 0.9);
      final opacity = isLight ? baseOpacity * 0.35 : baseOpacity;

      // Color: most stars are white/blue-white, occasional warm star. In
      // light mode these become muted dust motes instead of bright points.
      final color = isLight
          ? (star.phase % 1.2 < 0.15
          ? Color.fromRGBO(150, 130, 95, opacity)
          : star.phase % 0.7 < 0.1
          ? Color.fromRGBO(120, 125, 140, opacity)
          : Color.fromRGBO(130, 128, 120, opacity))
          : (star.phase % 1.2 < 0.15
          ? Color.fromRGBO(255, 220, 180, opacity) // warm
          : star.phase % 0.7 < 0.1
          ? Color.fromRGBO(180, 210, 255, opacity) // blue-white
          : Color.fromRGBO(255, 255, 255, opacity)); // white

      paint.color = color;
      canvas.drawCircle(Offset(px, py), star.size, paint);
    }
  }

  void _drawHorizon(Canvas canvas, Size size) {
    final isLight = MFColors.isLight;

    // Bottom nav is ~60px. Arc should peek above it even at scroll 0,
    // then rise further as you scroll down.
    const bottomNavHeight = 60.0;
    final revealProgress = maxScroll > 10
        ? (scrollOffset / maxScroll).clamp(0.0, 1.0)
        : 0.3; // no scroll controller — show arc at fixed peek position

    // At scroll 0: arc center is just below visible area (peeking ~40px of rim).
    // At full scroll: arc rises ~120px higher.
    final arcCenterY = size.height
        - bottomNavHeight
        + (size.width * 0.45)   // arc radius keeps most of surface off screen
        - 40                     // base peek amount
        - (revealProgress * 120);

    final arcRadiusX = size.width * 1.6;
    final arcRadiusY = size.width * 0.55;
    final arcCenter = Offset(size.width / 2, arcCenterY);

    // ── Horizon glow ────────────────────────────────────────────────────────
    // Night: violet nebula haze. Daylight: no atmosphere to scatter light
    // into a glow, but harsh direct sun blows out the horizon — same visual
    // beat (a bright band low in frame), warm-white instead of violet.
    final hazeBottom = size.height - bottomNavHeight;
    final hazeOpacity = 0.08 + (revealProgress * 0.12);
    final hazeRect = Rect.fromLTWH(0, hazeBottom - 180, size.width, 180);
    final hazeColors = isLight
        ? [
      const Color(0xFFFFF6E0).withValues(alpha: 0),
      const Color(0xFFFFEFC4).withValues(alpha: hazeOpacity * 0.6),
      const Color(0xFFFFE9AE).withValues(alpha: hazeOpacity * 1.2),
    ]
        : [
      const Color(0xFF7B2FBE).withValues(alpha: 0),
      const Color(0xFF9B4DCA).withValues(alpha: hazeOpacity * 0.5),
      const Color(0xFFB06EE0).withValues(alpha: hazeOpacity),
    ];
    final hazePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: hazeColors,
      ).createShader(hazeRect);
    canvas.drawRect(hazeRect, hazePaint);

    // ── Surface arc ──────────────────────────────────────────────────────────
    final surfaceOpacity = (0.5 + revealProgress * 0.4).clamp(0.0, 0.95);

    final ovalRect = Rect.fromCenter(
      center: arcCenter,
      width: arcRadiusX * 2,
      height: arcRadiusY * 2,
    );

    // Surface fill — dark rim silhouette at night, pale sunlit regolith by day
    canvas.drawOval(
      ovalRect,
      Paint()
        ..style = PaintingStyle.fill
        ..color = (isLight ? const Color(0xFFCAC3B3) : const Color(0xFF1A1520))
            .withValues(alpha: surfaceOpacity),
    );

    // Rim glow — cool violet starlight at night, warm sun glare by day
    canvas.drawOval(
      ovalRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
        ..color = (isLight ? const Color(0xFFFFE9AE) : const Color(0xFFCC88FF))
            .withValues(alpha: surfaceOpacity),
    );

    // ── Surface details ──────────────────────────────────────────────────────
    if (revealProgress > 0.2) {
      final detailOpacity = ((revealProgress - 0.2) / 0.8).clamp(0.0, 1.0) * 0.45;
      _drawSurfaceDetails(canvas, size, arcCenter, arcRadiusX, arcRadiusY, detailOpacity, isLight);
    }
  }

  void _drawSurfaceDetails(
      Canvas canvas,
      Size size,
      Offset arcCenter,
      double rx,
      double ry,
      double opacity,
      bool isLight,
      ) {
    final paint = Paint()..style = PaintingStyle.stroke;
    // Craters read as shadow lines against the pale daylit surface, so they
    // need to go darker (not lighter) in light mode to stay visible.
    final craterColor = isLight ? const Color(0xFF8A8070) : const Color(0xFF6A5080);
    final rockColor = isLight ? const Color(0xFF8A8070) : const Color(0xFF1A1520);

    // Crater 1 — left side, shallow
    paint
      ..strokeWidth = 1.0
      ..color = craterColor.withValues(alpha: opacity);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.22, arcCenter.dy - ry * 0.15),
        width: 28,
        height: 10,
      ),
      paint,
    );

    // Crater 2 — right-center, slightly deeper
    paint
      ..strokeWidth = 0.8
      ..color = craterColor.withValues(alpha: opacity * 0.8);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.68, arcCenter.dy - ry * 0.08),
        width: 18,
        height: 7,
      ),
      paint,
    );

    // Rock silhouette 1 — small jagged bump left
    final rock1 = Path()
      ..moveTo(size.width * 0.08, arcCenter.dy - ry * 0.02)
      ..lineTo(size.width * 0.11, arcCenter.dy - ry * 0.09)
      ..lineTo(size.width * 0.14, arcCenter.dy - ry * 0.05)
      ..lineTo(size.width * 0.16, arcCenter.dy - ry * 0.08)
      ..lineTo(size.width * 0.19, arcCenter.dy - ry * 0.02)
      ..close();
    canvas.drawPath(
      rock1,
      Paint()
        ..style = PaintingStyle.fill
        ..color = rockColor.withValues(alpha: opacity * 0.9),
    );

    // Rock silhouette 2 — right edge
    final rock2 = Path()
      ..moveTo(size.width * 0.78, arcCenter.dy - ry * 0.02)
      ..lineTo(size.width * 0.80, arcCenter.dy - ry * 0.06)
      ..lineTo(size.width * 0.83, arcCenter.dy - ry * 0.04)
      ..lineTo(size.width * 0.85, arcCenter.dy - ry * 0.07)
      ..lineTo(size.width * 0.88, arcCenter.dy - ry * 0.02)
      ..close();
    canvas.drawPath(
      rock2,
      Paint()
        ..style = PaintingStyle.fill
        ..color = rockColor.withValues(alpha: opacity * 0.9),
    );
  }

  @override
  bool shouldRepaint(_SpacePainter old) =>
      old.twinkleValue != twinkleValue ||
          old.scrollOffset != scrollOffset ||
          old.maxScroll != maxScroll;
}

// ─── Public widget ────────────────────────────────────────────────────────────

class SpaceBackground extends StatefulWidget {
  final Widget child;
  final ScrollController? scrollController;

  const SpaceBackground({
    super.key,
    required this.child,
    this.scrollController,
  });

  @override
  State<SpaceBackground> createState() => _SpaceBackgroundState();
}

class _SpaceBackgroundState extends State<SpaceBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _twinkleController;
  late List<_Star> _stars;
  double _scrollOffset = 0;
  double _maxScroll = 1;

  static const int _starCount = 55; // sparse

  @override
  void initState() {
    super.initState();

    // Generate stars once with a fixed seed for consistency
    final rng = Random(42);
    _stars = List.generate(_starCount, (_) {
      final layer = rng.nextDouble(); // 0=far, 1=close
      return _Star(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        size: 0.5 + rng.nextDouble() * (layer < 0.4 ? 0.8 : 1.4),
        opacity: 0.2 + rng.nextDouble() * 0.5,
        phase: rng.nextDouble() * 2 * pi,
        speed: 0.3 + rng.nextDouble() * 0.7,
        layer: layer,
      );
    });

    // Slow twinkle — one full cycle every ~8 seconds
    _twinkleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    widget.scrollController?.addListener(_onScroll);
  }

  void _onScroll() {
    final sc = widget.scrollController!;
    setState(() {
      _scrollOffset = sc.offset;
      _maxScroll = sc.position.maxScrollExtent;
    });
  }

  @override
  void didUpdateWidget(SpaceBackground old) {
    super.didUpdateWidget(old);
    if (old.scrollController != widget.scrollController) {
      old.scrollController?.removeListener(_onScroll);
      widget.scrollController?.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_onScroll);
    _twinkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Starfield + horizon ─────────────────────────────────────────────
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _twinkleController,
            builder: (context, _) => CustomPaint(
              painter: _SpacePainter(
                stars: _stars,
                twinkleValue: _twinkleController.value,
                scrollOffset: _scrollOffset,
                maxScroll: _maxScroll,
              ),
            ),
          ),
        ),
        // ── Content ─────────────────────────────────────────────────────────
        widget.child,
      ],
    );
  }
}