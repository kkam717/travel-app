import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Premium profile banner: optional cityscape cover image, map overlay, or gradient fallback.
/// Alignment for cover image: bottom so the top (e.g. sky) is cropped when possible.
const Alignment _kCoverImageAlignment = Alignment(0, 1);

class ProfileBanner2026 extends StatefulWidget {
  final String? currentCity;
  final String? coverImageUrl;
  /// Asset path (e.g. 'assets/images/profile_banner_london.png') for a local banner image.
  final String? coverImageAsset;
  final String? mapPreviewUrl;
  final String seedKey;
  final double height;
  final double bottomRadius;
  final bool enableShimmer;

  const ProfileBanner2026({
    super.key,
    this.currentCity,
    this.coverImageUrl,
    this.coverImageAsset,
    this.mapPreviewUrl,
    required this.seedKey,
    this.height = 260,
    this.bottomRadius = 28,
    this.enableShimmer = true,
  });

  @override
  State<ProfileBanner2026> createState() => _ProfileBanner2026State();
}

class _ProfileBanner2026State extends State<ProfileBanner2026>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final seed = _hashSeed('${widget.seedKey}|${widget.currentCity ?? ''}');
    final palette = _paletteForSeed(seed, isDark);
    final skylineSeed = _hashSeed('skyline|${widget.seedKey}|${widget.currentCity ?? ''}');

    return ClipRRect(
      borderRadius: BorderRadius.only(
        bottomLeft: Radius.circular(widget.bottomRadius),
        bottomRight: Radius.circular(widget.bottomRadius),
      ),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if ((widget.coverImageAsset != null && widget.coverImageAsset!.isNotEmpty) ||
                (widget.coverImageUrl != null && widget.coverImageUrl!.isNotEmpty)) ...[
              // Layer 1a: Cityscape cover image (aligned to bottom to avoid top ~300px / sky)
              Positioned.fill(
                child: widget.coverImageAsset != null && widget.coverImageAsset!.isNotEmpty
                    ? Image.asset(
                        widget.coverImageAsset!,
                        fit: BoxFit.cover,
                        alignment: _kCoverImageAlignment,
                        errorBuilder: (_, __, ___) => _GradientLayer(
                          palette: palette,
                          isDark: isDark,
                          seed: seed,
                          shimmerT: widget.enableShimmer ? _shimmerController : null,
                        ),
                      )
                    : Image.network(
                        widget.coverImageUrl!,
                        fit: BoxFit.cover,
                        alignment: _kCoverImageAlignment,
                        errorBuilder: (_, __, ___) => _GradientLayer(
                          palette: palette,
                          isDark: isDark,
                          seed: seed,
                          shimmerT: widget.enableShimmer ? _shimmerController : null,
                        ),
                      ),
              ),
              // Layer 1b: Dark gradient overlay for text legibility
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.35),
                        Colors.black.withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
              // Layer 1c: Subtle map texture overlay
              Positioned.fill(
                child: CustomPaint(
                  painter: _MapTexturePainter(seed: seed),
                  size: Size.infinite,
                ),
              ),
            ] else ...[
              // Fallback: gradient + noise + skyline + ribbon
              _GradientLayer(
                palette: palette,
                isDark: isDark,
                seed: seed,
                shimmerT: widget.enableShimmer ? _shimmerController : null,
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _NoisePainter(seed: seed, opacity: 0.06),
                  size: Size.infinite,
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: SkylinePainter(
                    seed: skylineSeed,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                  size: Size.infinite,
                ),
              ),
              if (widget.mapPreviewUrl != null && widget.mapPreviewUrl!.isNotEmpty)
                Positioned.fill(
                  child: _MapFadeLayer(
                    imageUrl: widget.mapPreviewUrl!,
                    bottomRadius: widget.bottomRadius,
                  ),
                )
              else
                Positioned.fill(
                  child: CustomPaint(
                    painter: RouteRibbonPainter(seed: seed, isDark: isDark),
                    size: Size.infinite,
                  ),
                ),
            ],
            // Bottom fade into page background
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: widget.height * 0.5,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        theme.colorScheme.surface.withValues(alpha: 0.98),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _hashSeed(String s) {
    int h = 0;
    for (int i = 0; i < s.length; i++) {
      h = 0x1fffffff & (h + s.codeUnitAt(i));
      h = 0x1fffffff & (h + ((h << 10) & 0x1fffffff));
      h ^= h >> 6;
    }
    h += h << 3;
    h ^= h >> 11;
    return h.abs();
  }

  _BannerPalette _paletteForSeed(int seed, bool isDark) {
    final palettes = isDark ? _darkPalettes : _lightPalettes;
    return palettes[seed % palettes.length];
  }
}

class _BannerPalette {
  final List<Color> gradientColors;
  final Color accent;

  const _BannerPalette({required this.gradientColors, required this.accent});
}

// Orangey-blue palettes (light): blue sky with warm orange glow
final List<_BannerPalette> _lightPalettes = [
  _BannerPalette(
    gradientColors: [
      Color(0xFF1E3A5F), // slate blue
      Color(0xFF2E5077),
      Color(0xFFE07A5F).withValues(alpha: 0.5),
    ],
    accent: Color(0xFF2E5077),
  ),
  _BannerPalette(
    gradientColors: [
      Color(0xFF1B4962),
      Color(0xFF3D7A9E),
      Color(0xFFED9B6F).withValues(alpha: 0.45),
    ],
    accent: Color(0xFF3D7A9E),
  ),
  _BannerPalette(
    gradientColors: [
      Color(0xFF2C5282),
      Color(0xFF4A90B8),
      Color(0xFFF4A574).withValues(alpha: 0.4),
    ],
    accent: Color(0xFF4A90B8),
  ),
  _BannerPalette(
    gradientColors: [
      Color(0xFF234E70),
      Color(0xFF3B82C4),
      Color(0xFFE07856).withValues(alpha: 0.45),
    ],
    accent: Color(0xFF3B82C4),
  ),
  _BannerPalette(
    gradientColors: [
      Color(0xFF1A365D),
      Color(0xFF2C5282),
      Color(0xFFD2691E).withValues(alpha: 0.4),
    ],
    accent: Color(0xFF2C5282),
  ),
  _BannerPalette(
    gradientColors: [
      Color(0xFF0F4C75),
      Color(0xFF3282B8),
      Color(0xFFF08080).withValues(alpha: 0.35),
    ],
    accent: Color(0xFF3282B8),
  ),
];

// Orangey-blue palettes (dark)
final List<_BannerPalette> _darkPalettes = [
  _BannerPalette(
    gradientColors: [
      Color(0xFF1E3A5F),
      Color(0xFF0F172A),
      Color(0xFFE07A5F).withValues(alpha: 0.28),
    ],
    accent: Color(0xFF4A90B8),
  ),
  _BannerPalette(
    gradientColors: [
      Color(0xFF1B4962),
      Color(0xFF0A1929),
      Color(0xFFED9B6F).withValues(alpha: 0.25),
    ],
    accent: Color(0xFF3D7A9E),
  ),
  _BannerPalette(
    gradientColors: [
      Color(0xFF2C5282),
      Color(0xFF0F172A),
      Color(0xFFF4A574).withValues(alpha: 0.22),
    ],
    accent: Color(0xFF4A90B8),
  ),
  _BannerPalette(
    gradientColors: [
      Color(0xFF234E70),
      Color(0xFF0C1929),
      Color(0xFFE07856).withValues(alpha: 0.26),
    ],
    accent: Color(0xFF3B82C4),
  ),
  _BannerPalette(
    gradientColors: [
      Color(0xFF1A365D),
      Color(0xFF0A0F1A),
      Color(0xFFD2691E).withValues(alpha: 0.3),
    ],
    accent: Color(0xFF2C5282),
  ),
  _BannerPalette(
    gradientColors: [
      Color(0xFF0F4C75),
      Color(0xFF081C2E),
      Color(0xFFF08080).withValues(alpha: 0.2),
    ],
    accent: Color(0xFF3282B8),
  ),
];

/// Layer 1: Multi-stop gradient with optional shimmer drift.
class _GradientLayer extends StatelessWidget {
  final _BannerPalette palette;
  final bool isDark;
  final int seed;
  final Animation<double>? shimmerT;

  const _GradientLayer({
    required this.palette,
    required this.isDark,
    required this.seed,
    this.shimmerT,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.colorScheme.surface;

    if (shimmerT != null) {
      return AnimatedBuilder(
        animation: shimmerT!,
        builder: (context, child) {
          final drift = 0.03 + 0.04 * math.sin(shimmerT!.value * 6.28);
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1.0 + drift, -1.0),
                end: Alignment(1.0 - drift, 1.0),
                stops: const [0.0, 0.45, 0.85, 1.0],
                colors: [
                  palette.gradientColors[0],
                  palette.gradientColors.length > 1
                      ? palette.gradientColors[1]
                      : palette.gradientColors[0],
                  palette.gradientColors.length > 2
                      ? palette.gradientColors[2]
                      : palette.gradientColors[0].withValues(alpha: 0.5),
                  base.withValues(alpha: 0.0),
                ],
              ),
            ),
          );
        },
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.45, 0.85, 1.0],
          colors: [
            palette.gradientColors[0],
            palette.gradientColors.length > 1
                ? palette.gradientColors[1]
                : palette.gradientColors[0],
            palette.gradientColors.length > 2
                ? palette.gradientColors[2]
                : palette.gradientColors[0].withValues(alpha: 0.5),
            base.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

/// Subtle map-like texture overlay (light lines suggesting roads/geography).
class _MapTexturePainter extends CustomPainter {
  final int seed;

  _MapTexturePainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final rnd = _SeededRandom(seed);
    final spacing = 32.0 + (rnd.next() % 20);
    for (double x = 0; x < size.width + 50; x += spacing + (rnd.next() % 8)) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height + 50; y += spacing + (rnd.next() % 8)) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    final pathPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Path();
    double px = 0;
    double py = size.height * 0.4;
    path.moveTo(px, py);
    for (int i = 0; i < 12; i++) {
      px += 40 + rnd.nextDouble() * 50;
      py += (rnd.nextDouble() - 0.5) * 60;
      path.lineTo(px.clamp(0.0, size.width), py.clamp(0.0, size.height));
    }
    canvas.drawPath(path, pathPaint);
  }

  @override
  bool shouldRepaint(covariant _MapTexturePainter oldDelegate) =>
      oldDelegate.seed != seed;
}

/// Subtle procedural noise.
class _NoisePainter extends CustomPainter {
  final int seed;
  final double opacity;

  _NoisePainter({required this.seed, this.opacity = 0.06});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..strokeWidth = 1;
    int s = seed;
    for (int i = 0; i < 800; i++) {
      s = (s * 1103515245 + 12345) & 0x7fffffff;
      final x = (s % 1000) / 1000.0 * size.width;
      s = (s * 1103515245 + 12345) & 0x7fffffff;
      final y = (s % 1000) / 1000.0 * size.height;
      canvas.drawCircle(Offset(x, y), 0.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NoisePainter oldDelegate) =>
      oldDelegate.seed != seed || oldDelegate.opacity != opacity;
}

/// Layer 3: Stylized skyline silhouette (rectangles of varied heights).
class SkylinePainter extends CustomPainter {
  final int seed;
  final Color color;

  SkylinePainter({required this.seed, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final rnd = _SeededRandom(seed);
    final buildingCount = 14 + (rnd.next() % 6);
    final widths = <double>[];
    double totalW = 0;
    while (totalW < size.width + 40) {
      final w = 24.0 + rnd.nextDouble() * 32;
      widths.add(w);
      totalW += w;
    }
    double x = -20.0;
    for (int i = 0; i < widths.length; i++) {
      final w = widths[i];
      final h = size.height * (0.25 + rnd.nextDouble() * 0.5);
      final y = size.height - h;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h + 20),
          Radius.circular(rnd.nextDouble() * 3 + 1),
        ),
        paint,
      );
      x += w;
    }
  }

  @override
  bool shouldRepaint(covariant SkylinePainter oldDelegate) =>
      oldDelegate.seed != seed || oldDelegate.color != color;
}

/// Simple seeded pseudo-random for deterministic layout.
class _SeededRandom {
  int _s;

  _SeededRandom(int seed) : _s = seed & 0x7fffffff;

  int next() {
    _s = (_s * 1103515245 + 12345) & 0x7fffffff;
    return _s;
  }

  double nextDouble() => next() / 0x7fffffff;
}

/// Layer 4a: Map image with vertical fade-in (transparent top → opaque bottom).
class _MapFadeLayer extends StatelessWidget {
  final String imageUrl;
  final double bottomRadius;

  const _MapFadeLayer({
    required this.imageUrl,
    required this.bottomRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.only(
        bottomLeft: Radius.circular(bottomRadius),
        bottomRight: Radius.circular(bottomRadius),
      ),
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.transparent,
            Colors.white.withValues(alpha: 0.4),
            Colors.white,
          ],
          stops: const [0.0, 0.35, 0.6, 1.0],
        ).createShader(bounds),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// Layer 4b: Abstract route ribbon when no map (curved line).
class RouteRibbonPainter extends CustomPainter {
  final int seed;
  final bool isDark;

  RouteRibbonPainter({required this.seed, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = _SeededRandom(seed);
    final path = Path();
    final yBase = size.height * (0.5 + rnd.nextDouble() * 0.35);
    path.moveTo(0, yBase);
    double x = 0;
    double lastY = yBase;
    while (x < size.width + 20) {
      x += 40 + rnd.nextDouble() * 60;
      final y = yBase + (rnd.nextDouble() - 0.5) * 80;
      path.quadraticBezierTo(
        x - 30,
        (lastY + y) / 2,
        x,
        y,
      );
      lastY = y;
    }
    final paint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant RouteRibbonPainter oldDelegate) =>
      oldDelegate.seed != seed || oldDelegate.isDark != isDark;
}
