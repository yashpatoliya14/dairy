import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/app_language.dart';

/// Global loading manager that tracks active API requests.
class DairyMilkLoadingService {
  DairyMilkLoadingService._();

  static int _activeCount = 0;
  static final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);
  static final ValueNotifier<String?> currentMessage = ValueNotifier<String?>(null);

  static String? _pendingMessage;
  static bool _updateScheduled = false;

  /// Increment active API request count and display loader.
  static void show({String? message}) {
    _activeCount++;
    if (message != null && message.isNotEmpty) {
      _pendingMessage = message;
    }
    _scheduleUpdate();
  }

  /// Decrement active API request count. When 0, hide loader.
  static void hide() {
    if (_activeCount > 0) {
      _activeCount--;
    }
    _scheduleUpdate();
  }

  /// Force reset loading state (e.g. on logout or critical error).
  static void reset() {
    _activeCount = 0;
    _pendingMessage = null;
    _scheduleUpdate();
  }

  static void _scheduleUpdate() {
    if (_updateScheduled) return;
    _updateScheduled = true;

    void applyUpdate() {
      _updateScheduled = false;
      final shouldBeLoading = _activeCount > 0;
      if (currentMessage.value != _pendingMessage) {
        currentMessage.value = _pendingMessage;
      }
      if (isLoading.value != shouldBeLoading) {
        isLoading.value = shouldBeLoading;
      }
      if (!shouldBeLoading) {
        _pendingMessage = null;
        currentMessage.value = null;
      }
    }

    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) => applyUpdate());
  }

  /// Convenience wrapper for async tasks with automatic loader lifecycle.
  static Future<R> wrap<R>(
    Future<R> Function() task, {
    String? message,
  }) async {
    show(message: message);
    try {
      return await task();
    } finally {
      hide();
    }
  }
}

/// A global non-intrusive overlay inserted into [GetMaterialApp.builder] to display
/// a sleek, compact, animated Dairy Milk badge during API requests.
class DairyMilkOverlay extends StatelessWidget {
  const DairyMilkOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        ValueListenableBuilder<bool>(
          valueListenable: DairyMilkLoadingService.isLoading,
          builder: (context, loading, _) {
            return IgnorePointer(
              ignoring: !loading,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                opacity: loading ? 1.0 : 0.0,
                child: loading
                    ? ValueListenableBuilder<String?>(
                        valueListenable: DairyMilkLoadingService.currentMessage,
                        builder: (context, message, _) {
                          return _CompactFloatingHud(message: message);
                        },
                      )
                    : const SizedBox.shrink(),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// A small, elegant, glassmorphic floating HUD card for global API loading.
class _CompactFloatingHud extends StatelessWidget {
  const _CompactFloatingHud({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Soft dimming background with subtle blur
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5),
              child: Container(
                color: const Color(0x2210261A),
              ),
            ),
          ),
          // Small centered floating badge
          Center(
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              tween: Tween<double>(begin: 0.88, end: 1.0),
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: child,
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFAFFFFFF),
                      Color(0xF5F2F8F4),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0x382D7A55),
                    width: 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x220D3D22),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: Color(0x0F000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Small animated milk loader bottle
                    const DairyMilkLoader(
                      size: 38,
                      showText: false,
                    ),
                    const SizedBox(width: 13),
                    // Status text and animated dancing dots
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          T.t(message ?? 'Pouring fresh milk...'),
                          style: GoogleFonts.manrope(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E4B35),
                            letterSpacing: 0.1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const _SmallDancingDots(),
                      ],
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The Animated Dairy Milk Loader widget with liquid wave physics,
/// pouring milk droplets, ripple splash rings, and rising bubbles.
class DairyMilkLoader extends StatefulWidget {
  const DairyMilkLoader({
    super.key,
    this.size = 46,
    this.message,
    this.subtitle,
    this.showText = true,
    this.bottleColor,
    this.milkColor,
    this.accentColor,
  });

  /// Size of the animated bottle container (defaults to compact 46px).
  final double size;

  /// Custom status text displayed under the loader.
  final String? message;

  /// Secondary subtitle or brand label.
  final String? subtitle;

  /// Whether to render animated status text.
  final bool showText;

  /// Bottle outline color (defaults to Dairy green `#2D7A55`).
  final Color? bottleColor;

  /// Primary liquid milk color (defaults to creamy `#FFFFFF`).
  final Color? milkColor;

  /// Cap/accent color (defaults to Dairy golden `#F6C95D`).
  final Color? accentColor;

  /// Quick constructor for mini buttons or compact areas (20px to 26px).
  static Widget mini({
    Key? key,
    double size = 20,
    Color color = Colors.white,
    Color? waveColor,
  }) {
    return DairyMilkMiniLoader(
      key: key,
      size: size,
      color: color,
      waveColor: waveColor,
    );
  }

  @override
  State<DairyMilkLoader> createState() => _DairyMilkLoaderState();
}

class _DairyMilkLoaderState extends State<DairyMilkLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBottleColor =
        widget.bottleColor ?? const Color(0xFF2D7A55);
    final effectiveMilkColor =
        widget.milkColor ?? Colors.white;
    final effectiveAccentColor =
        widget.accentColor ?? const Color(0xFFF6C95D);

    final bottleWidget = AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // Subtle tilt/breathing wobble to feel alive
        final tilt = math.sin(_controller.value * 2 * math.pi) * 0.04;
        return Transform.rotate(
          angle: tilt,
          child: CustomPaint(
            size: Size(widget.size * 0.82, widget.size),
            painter: _DairyMilkPainter(
              animationProgress: _controller.value,
              bottleColor: effectiveBottleColor,
              milkColor: effectiveMilkColor,
              accentColor: effectiveAccentColor,
            ),
          ),
        );
      },
    );

    if (!widget.showText) {
      return bottleWidget;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        bottleWidget,
        const SizedBox(height: 10),
        Text(
          T.t(widget.message ?? 'Pouring fresh milk...'),
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: widget.size > 60 ? 14 : 12.5,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E4B35),
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 4),
        const _SmallDancingDots(),
        if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            T.t(widget.subtitle!),
            style: GoogleFonts.dmSans(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6B8779),
            ),
          ),
        ],
      ],
    );
  }
}

/// Custom painter rendering the dairy milk bottle, wave liquid,
/// dropping milk stream, and splash ripples.
class _DairyMilkPainter extends CustomPainter {
  _DairyMilkPainter({
    required this.animationProgress,
    required this.bottleColor,
    required this.milkColor,
    required this.accentColor,
  });

  final double animationProgress;
  final Color bottleColor;
  final Color milkColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // Bottle proportions
    final topY = h * 0.20;
    final botY = h * 0.94;
    final neckWidth = w * 0.34;
    final bodyWidth = w * 0.74;
    final shoulderY = topY + (botY - topY) * 0.20;
    final cornerRadius = w * 0.16;

    // Construct the closed inner contour of the milk bottle
    final bottlePath = Path();
    // Start at top-left rim
    bottlePath.moveTo(cx - neckWidth / 2, topY);
    // Neck down to shoulder left
    bottlePath.lineTo(cx - neckWidth / 2, shoulderY - 3);
    // Shoulder curve out to body left
    bottlePath.cubicTo(
      cx - neckWidth / 2,
      shoulderY + 3,
      cx - bodyWidth / 2,
      shoulderY + 4,
      cx - bodyWidth / 2,
      shoulderY + 12,
    );
    // Body left down to bottom-left rounded corner
    bottlePath.lineTo(cx - bodyWidth / 2, botY - cornerRadius);
    bottlePath.arcToPoint(
      Offset(cx - bodyWidth / 2 + cornerRadius, botY),
      radius: Radius.circular(cornerRadius),
      clockwise: false,
    );
    // Base bottom line
    bottlePath.lineTo(cx + bodyWidth / 2 - cornerRadius, botY);
    // Bottom-right rounded corner
    bottlePath.arcToPoint(
      Offset(cx + bodyWidth / 2, botY - cornerRadius),
      radius: Radius.circular(cornerRadius),
      clockwise: false,
    );
    // Body right up to shoulder
    bottlePath.lineTo(cx + bodyWidth / 2, shoulderY + 12);
    // Shoulder curve in to neck right
    bottlePath.cubicTo(
      cx + bodyWidth / 2,
      shoulderY + 4,
      cx + neckWidth / 2,
      shoulderY + 3,
      cx + neckWidth / 2,
      shoulderY - 3,
    );
    // Neck right up to top-right rim
    bottlePath.lineTo(cx + neckWidth / 2, topY);
    bottlePath.close();

    // =========================================================
    // 1. DRAW BOTTLE BACKGROUND (Within bottle clip)
    // =========================================================
    canvas.save();
    canvas.clipPath(bottlePath);

    // Light milky translucent glass backdrop
    final bgPaint = Paint()
      ..color = const Color(0xFFF1F6F3)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // =========================================================
    // 2. LIQUID MILK WAVES
    // =========================================================
    // Dynamic liquid fill level (~60% full with gentle wave oscillation)
    final liquidBaseY = botY - (botY - shoulderY) * 0.60 +
        math.sin(animationProgress * 2 * math.pi) * 1.8;

    // --- Wave 1: Back Cream Wave (slight cream/greenish-cream tint) ---
    final backWavePath = Path();
    final phase1 = animationProgress * 2 * math.pi;
    final amp1 = (w * 0.075).clamp(2.0, 4.0);
    backWavePath.moveTo(cx - bodyWidth, botY + 10);
    backWavePath.lineTo(cx - bodyWidth, liquidBaseY);
    for (double x = cx - bodyWidth; x <= cx + bodyWidth; x += 2.5) {
      final y = liquidBaseY +
          amp1 * math.sin(2 * math.pi * (x / (bodyWidth * 0.8)) + phase1);
      backWavePath.lineTo(x, y);
    }
    backWavePath.lineTo(cx + bodyWidth, botY + 10);
    backWavePath.close();

    final backWavePaint = Paint()
      ..color = const Color(0xFFDDEEE3)
      ..style = PaintingStyle.fill;
    canvas.drawPath(backWavePath, backWavePaint);

    // --- Wave 2: Front Rich Milk Wave (pure white creamy milk) ---
    final frontWavePath = Path();
    final phase2 = -animationProgress * 2 * math.pi * 1.35;
    final amp2 = (w * 0.085).clamp(2.5, 4.5);
    frontWavePath.moveTo(cx - bodyWidth, botY + 10);
    frontWavePath.lineTo(cx - bodyWidth, liquidBaseY);
    for (double x = cx - bodyWidth; x <= cx + bodyWidth; x += 2.5) {
      final y = liquidBaseY +
          amp2 *
              math.cos(
                2 * math.pi * (x / (bodyWidth * 0.7)) + phase2 + math.pi / 4,
              );
      frontWavePath.lineTo(x, y);
    }
    frontWavePath.lineTo(cx + bodyWidth, botY + 10);
    frontWavePath.close();

    final frontWavePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          milkColor,
          const Color(0xFFF7FAF8),
          const Color(0xFFEBF3EE),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTRB(cx - bodyWidth, liquidBaseY - 4, cx + bodyWidth, botY))
      ..style = PaintingStyle.fill;
    canvas.drawPath(frontWavePath, frontWavePaint);

    // =========================================================
    // 3. RISING MILK BUBBLES
    // =========================================================
    final bubbleSeeds = [
      {'xRel': -0.20, 'speed': 1.0, 'size': 1.6, 'offset': 0.15},
      {'xRel': 0.15, 'speed': 1.25, 'size': 2.0, 'offset': 0.45},
      {'xRel': -0.05, 'speed': 0.85, 'size': 1.4, 'offset': 0.70},
    ];

    for (final b in bubbleSeeds) {
      final bProgress =
          (animationProgress * (b['speed'] as double) + (b['offset'] as double)) %
              1.0;
      final bx = cx + (b['xRel'] as double) * bodyWidth +
          math.sin(bProgress * 4 * math.pi) * 2.0;
      final by = botY - 4 - bProgress * (botY - liquidBaseY);

      if (by >= liquidBaseY) {
        final bAlpha = (1.0 - (bProgress * 0.5)).clamp(0.2, 0.85);
        final bubblePaint = Paint()
          ..color = Colors.white.withValues(alpha: bAlpha)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(bx, by), (b['size'] as double), bubblePaint);
      }
    }

    // =========================================================
    // 4. SURFACE RIPPLE EXPANSIONS (Triggered by milk drop impact)
    // =========================================================
    if (animationProgress >= 0.40 && animationProgress <= 0.85) {
      final rippleP = (animationProgress - 0.40) / 0.45;
      final rippleR = rippleP * (bodyWidth * 0.35);
      final rippleAlpha = (1.0 - rippleP).clamp(0.0, 0.65);

      final ripplePaint = Paint()
        ..color = bottleColor.withValues(alpha: rippleAlpha * 0.5)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, liquidBaseY + 1),
          width: rippleR * 2,
          height: rippleR * 0.5,
        ),
        ripplePaint,
      );

      // Splash micro-droplets bouncing up
      if (rippleP <= 0.5) {
        final splashH = math.sin(rippleP * math.pi * 2) * 6;
        final splashDropPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset(cx - 4 - rippleP * 8, liquidBaseY - splashH),
          1.2,
          splashDropPaint,
        );
        canvas.drawCircle(
          Offset(cx + 4 + rippleP * 8, liquidBaseY - splashH * 0.8),
          1.1,
          splashDropPaint,
        );
      }
    }

    // =========================================================
    // 5. GLASS SPECULAR HIGHLIGHT STRIP
    // =========================================================
    final highlightW = (w * 0.08).clamp(2.0, 5.0);
    final glassHighlightPath = Path();
    glassHighlightPath.moveTo(cx - bodyWidth / 2 + 3, shoulderY + 14);
    glassHighlightPath.lineTo(cx - bodyWidth / 2 + 3, botY - cornerRadius);
    glassHighlightPath.arcToPoint(
      Offset(cx - bodyWidth / 2 + cornerRadius, botY - 2),
      radius: Radius.circular(cornerRadius),
      clockwise: false,
    );
    glassHighlightPath.lineTo(cx - bodyWidth / 2 + cornerRadius + highlightW, botY - 2);
    glassHighlightPath.lineTo(cx - bodyWidth / 2 + 3 + highlightW, shoulderY + 14);
    glassHighlightPath.close();

    final glassHighlightPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.5),
          Colors.white.withValues(alpha: 0.1),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(cx - bodyWidth / 2, shoulderY, highlightW * 2, botY - shoulderY))
      ..style = PaintingStyle.fill;
    canvas.drawPath(glassHighlightPath, glassHighlightPaint);

    // =========================================================
    // 6. VOLUME MEASUREMENT NOTCHES
    // =========================================================
    final notchPaint = Paint()
      ..color = bottleColor.withValues(alpha: 0.35)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    final notchX = cx + bodyWidth / 2 - 2;
    canvas.drawLine(
      Offset(notchX, botY - (botY - shoulderY) * 0.32),
      Offset(notchX - 4, botY - (botY - shoulderY) * 0.32),
      notchPaint,
    );
    canvas.drawLine(
      Offset(notchX, botY - (botY - shoulderY) * 0.54),
      Offset(notchX - 6, botY - (botY - shoulderY) * 0.54),
      notchPaint,
    );
    canvas.drawLine(
      Offset(notchX, botY - (botY - shoulderY) * 0.76),
      Offset(notchX - 4, botY - (botY - shoulderY) * 0.76),
      notchPaint,
    );

    // Restore canvas from bottle clipping
    canvas.restore();

    // =========================================================
    // 7. BOTTLE GLASS OUTLINE & EMBOSSED RIM
    // =========================================================
    final outlinePaint = Paint()
      ..color = bottleColor.withValues(alpha: 0.75)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    canvas.drawPath(bottlePath, outlinePaint);

    // Bottle mouth collar / golden lip ring
    final rimRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, topY),
        width: neckWidth + 5,
        height: 4.5,
      ),
      const Radius.circular(2.5),
    );
    final rimPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rimRect, rimPaint);

    final rimBorder = Paint()
      ..color = bottleColor.withValues(alpha: 0.8)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(rimRect, rimBorder);

    // Golden Dairy band below collar
    final bandRect = Rect.fromCenter(
      center: Offset(cx, topY + 5),
      width: neckWidth - 2,
      height: 3.0,
    );
    final bandPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    canvas.drawRect(bandRect, bandPaint);

    // =========================================================
    // 8. FALLING MILK TEARDROP / POUR STREAM
    // =========================================================
    if (animationProgress <= 0.42) {
      final dropP = animationProgress / 0.42;
      final easedP = Curves.easeInQuad.transform(dropP);
      final startY = h * 0.04;
      final targetY = liquidBaseY;
      final currentY = startY + (targetY - startY) * easedP;

      if (currentY < liquidBaseY) {
        final dropScale = (w / 40).clamp(0.8, 1.2);
        final dropPath = Path();
        dropPath.moveTo(cx, currentY - 5 * dropScale);
        dropPath.cubicTo(
          cx + 3 * dropScale,
          currentY - 1 * dropScale,
          cx + 3 * dropScale,
          currentY + 3 * dropScale,
          cx,
          currentY + 3 * dropScale,
        );
        dropPath.cubicTo(
          cx - 3 * dropScale,
          currentY + 3 * dropScale,
          cx - 3 * dropScale,
          currentY - 1 * dropScale,
          cx,
          currentY - 5 * dropScale,
        );
        dropPath.close();

        final dropPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawPath(dropPath, dropPaint);

        final dropStroke = Paint()
          ..color = bottleColor.withValues(alpha: 0.3)
          ..strokeWidth = 0.8
          ..style = PaintingStyle.stroke;
        canvas.drawPath(dropPath, dropStroke);
      }
    } else if (animationProgress >= 0.80) {
      // New droplet forming at the top source
      final formP = (animationProgress - 0.80) / 0.20;
      final formY = h * 0.04 + formP * 4.0;
      final radius = 1.2 + formP * 2.0;

      final formPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, formY), radius, formPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DairyMilkPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
        oldDelegate.bottleColor != bottleColor ||
        oldDelegate.milkColor != milkColor ||
        oldDelegate.accentColor != accentColor;
  }
}

/// Compact mini version of the Dairy Milk loader, optimized for buttons & compact tags.
class DairyMilkMiniLoader extends StatefulWidget {
  const DairyMilkMiniLoader({
    super.key,
    this.size = 20,
    this.color = Colors.white,
    this.waveColor,
  });

  final double size;
  final Color color;
  final Color? waveColor;

  @override
  State<DairyMilkMiniLoader> createState() => _DairyMilkMiniLoaderState();
}

class _DairyMilkMiniLoaderState extends State<DairyMilkMiniLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.size * 0.82, widget.size),
          painter: _DairyMilkMiniPainter(
            progress: _controller.value,
            color: widget.color,
            waveColor: widget.waveColor ?? widget.color.withValues(alpha: 0.85),
          ),
        );
      },
    );
  }
}

class _DairyMilkMiniPainter extends CustomPainter {
  _DairyMilkMiniPainter({
    required this.progress,
    required this.color,
    required this.waveColor,
  });

  final double progress;
  final Color color;
  final Color waveColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    final topY = h * 0.22;
    final botY = h * 0.94;
    final neckW = w * 0.36;
    final bodyW = w * 0.74;
    final shoulderY = topY + (botY - topY) * 0.24;

    final bottlePath = Path();
    bottlePath.moveTo(cx - neckW / 2, topY);
    bottlePath.lineTo(cx - neckW / 2, shoulderY);
    bottlePath.quadraticBezierTo(
      cx - bodyW / 2,
      shoulderY + 2,
      cx - bodyW / 2,
      shoulderY + 6,
    );
    bottlePath.lineTo(cx - bodyW / 2, botY - 2.5);
    bottlePath.quadraticBezierTo(cx - bodyW / 2, botY, cx - bodyW / 2 + 2.5, botY);
    bottlePath.lineTo(cx + bodyW / 2 - 2.5, botY);
    bottlePath.quadraticBezierTo(cx + bodyW / 2, botY, cx + bodyW / 2, botY - 2.5);
    bottlePath.lineTo(cx + bodyW / 2, shoulderY + 6);
    bottlePath.quadraticBezierTo(
      cx + bodyW / 2,
      shoulderY + 2,
      cx + neckW / 2,
      shoulderY,
    );
    bottlePath.lineTo(cx + neckW / 2, topY);
    bottlePath.close();

    // Fill inside bottle with wave
    canvas.save();
    canvas.clipPath(bottlePath);

    final liquidBaseY = botY - (botY - shoulderY) * 0.65;
    final wavePath = Path();
    final phase = progress * 2 * math.pi;
    wavePath.moveTo(0, botY + 4);
    wavePath.lineTo(0, liquidBaseY);
    for (double x = 0; x <= w; x += 1.5) {
      final y = liquidBaseY + 1.8 * math.sin(2 * math.pi * (x / w) + phase);
      wavePath.lineTo(x, y);
    }
    wavePath.lineTo(w, botY + 4);
    wavePath.close();

    final fillPaint = Paint()
      ..color = waveColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(wavePath, fillPaint);

    canvas.restore();

    // Outline
    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    canvas.drawPath(bottlePath, strokePaint);

    // Rim collar
    final collarPaint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx - neckW / 2 - 1.5, topY),
      Offset(cx + neckW / 2 + 1.5, topY),
      collarPaint,
    );

    // Small bouncing milk droplet above
    if (progress <= 0.6) {
      final dropP = progress / 0.6;
      final dropY = h * 0.04 + dropP * (topY - h * 0.04);
      final dropPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, dropY), 1.2, dropPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DairyMilkMiniPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.waveColor != waveColor;
  }
}

/// Three small animated bouncing milk dots.
class _SmallDancingDots extends StatefulWidget {
  const _SmallDancingDots();

  @override
  State<_SmallDancingDots> createState() => _SmallDancingDotsState();
}

class _SmallDancingDotsState extends State<_SmallDancingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _dotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _dotController,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final phase = index * 0.28;
            final wave = math.sin((_dotController.value * 2 * math.pi) + phase);
            final bounceY = wave * 2.0;
            final alpha = (0.35 + 0.65 * ((wave + 1) / 2)).clamp(0.2, 1.0);

            return Transform.translate(
              offset: Offset(0, -bounceY),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.0),
                width: 4.0,
                height: 4.0,
                decoration: BoxDecoration(
                  color: const Color(0xFF2D7A55).withValues(alpha: alpha),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
