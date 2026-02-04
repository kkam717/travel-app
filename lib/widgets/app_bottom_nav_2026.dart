import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../core/profile_refresh_notifier.dart';
import '../l10n/app_strings.dart';

/// 2026 concept: rounded glass bar above bottom edge, minimal outlined icons,
/// prominent centered floating Create pill. Same routes and tab behavior.
class AppBottomNav2026 extends StatelessWidget {
  const AppBottomNav2026({super.key});

  static const double _barHeight = 64;
  static const double _barRadius = 28;
  static const double _barTopPadding = 12;
  static const double _barHorizontalMargin = 16;
  static const double _createPillWidth = 104;
  static const double _createPillHeight = 60;
  static const double _createPillRadius = 22;
  static const double _createOverlap = 8;
  static const double _iconSize = 24;
  static const double _labelFontSize = 11;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    const barBottomPadding = 8.0;
    return Padding(
      padding: EdgeInsets.only(bottom: safeBottom + barBottomPadding),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // Floating glass bubble (tabs inside)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _barHorizontalMargin),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_barRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  height: _barHeight + _barTopPadding,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_barRadius),
                    color: colorScheme.surface.withValues(alpha: 0.85),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: _barTopPadding / 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _NavItem2026(
                          icon: Icons.home_outlined,
                          activeIcon: Icons.home_rounded,
                          label: AppStrings.t(context, 'home'),
                          path: '/home',
                        ),
                        _NavItem2026(
                          icon: Icons.explore_outlined,
                          activeIcon: Icons.explore_rounded,
                          label: AppStrings.t(context, 'explore'),
                          path: '/explore',
                        ),
                        const SizedBox(width: _createPillWidth),
                        _NavItem2026(
                          icon: Icons.bookmark_outline_rounded,
                          activeIcon: Icons.bookmark_rounded,
                          label: AppStrings.t(context, 'saved'),
                          path: '/saved',
                        ),
                        _NavItem2026(
                          icon: Icons.person_outline_rounded,
                          activeIcon: Icons.person_rounded,
                          label: AppStrings.t(context, 'profile'),
                          path: '/profile',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Centered floating Create pill (overlaps bubble)
          Positioned(
            bottom: _barHeight + _barTopPadding - _createPillHeight + _createOverlap,
            child: _CreatePillButton(
              onPressed: () => context.go('/create'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatePillButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _CreatePillButton({required this.onPressed});

  @override
  State<_CreatePillButton> createState() => _CreatePillButtonState();
}

class _CreatePillButtonState extends State<_CreatePillButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scale = Tween<double>(begin: 1, end: 0.94).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) => _controller.forward();
  void _handleTapUp(TapUpDetails _) => _controller.reverse();
  void _handleTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final shadowColor = isDark
        ? Colors.white.withValues(alpha: 0.2)
        : Colors.black.withValues(alpha: 0.18);

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onPressed();
      },
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: AppBottomNav2026._createPillWidth,
          height: AppBottomNav2026._createPillHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppBottomNav2026._createPillRadius),
            color: colorScheme.primary,
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: isDark ? 0.25 : 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: shadowColor,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, size: 26, color: colorScheme.onPrimary),
              const SizedBox(height: 2),
              Text(
                'Create',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem2026 extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;

  const _NavItem2026({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.path,
  });

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final isSelected = location == path;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant;
    final iconToShow = isSelected ? activeIcon : icon;

    return Expanded(
      child: InkResponse(
        onTap: () {
          HapticFeedback.selectionClick();
          context.go(path);
          if (path == '/profile') {
            WidgetsBinding.instance.addPostFrameCallback((_) => ProfileRefreshNotifier.notify());
          }
        },
        borderRadius: BorderRadius.circular(14),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(iconToShow, size: AppBottomNav2026._iconSize, color: color),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: AppBottomNav2026._labelFontSize,
                    color: color,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
