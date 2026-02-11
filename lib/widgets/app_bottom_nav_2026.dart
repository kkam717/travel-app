import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../core/profile_refresh_notifier.dart';

/// 2026 concept: dark pill bar with rounded ends; selected tab is a pill (primary
/// colour + icon only) that animates between tabs; unselected tabs are icon-only;
/// vertical separator and circular Create button on the far right.
class AppBottomNav2026 extends StatelessWidget {
  const AppBottomNav2026({super.key});

  static const double _barHeight = 44;
  static const double _barRadius = 22;
  static const double _barTopPadding = 8;
  static const double _barHorizontalMargin = 12;
  static const double _createButtonSize = 36;
  static const double _iconSize = 20;
  static const double _selectedPillRadius = 14;
  static const double _pillHeight = 28;
  static const double _pillWidth = 40;

  /// Dark gray bar background (matches reference design).
  static const Color _barBackground = Color(0xFF2B2F38);

  static int _pathToIndex(String path) {
    switch (path) {
      case '/home':
        return 0;
      case '/explore':
        return 1;
      case '/saved':
        return 2;
      case '/profile':
        return 3;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    const barBottomPadding = 6.0;

    final items = [
      (path: '/home', icon: Icons.home_outlined, activeIcon: Icons.home_rounded),
      (path: '/explore', icon: Icons.explore_outlined, activeIcon: Icons.explore_rounded),
      (path: '/saved', icon: Icons.bookmark_outline_rounded, activeIcon: Icons.bookmark_rounded),
      (path: '/profile', icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded),
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: safeBottom + barBottomPadding),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _barHorizontalMargin),
        child: Container(
          height: _barHeight + _barTopPadding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_barRadius),
            color: _barBackground,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: _barTopPadding / 2,
              horizontal: 8,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _SlidingPillNav(
                    items: items,
                    selectionColor: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 1,
                  height: 18,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
                const SizedBox(width: 8),
                _CreateCircleButton(
                  size: _createButtonSize,
                  onPressed: () => context.go('/create'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SlidingPillNav extends StatefulWidget {
  final List<({String path, IconData icon, IconData activeIcon})> items;
  final Color selectionColor;

  const _SlidingPillNav({
    required this.items,
    required this.selectionColor,
  });

  @override
  State<_SlidingPillNav> createState() => _SlidingPillNavState();
}

class _SlidingPillNavState extends State<_SlidingPillNav>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  int _currentIndex = 0;
  int _previousIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onRouteChanged(int newIndex) {
    if (newIndex == _currentIndex) return;
    final wasIdle = _controller.status != AnimationStatus.forward && _controller.value == 0;
    if (wasIdle && _previousIndex == _currentIndex) {
      setState(() {
        _previousIndex = newIndex;
        _currentIndex = newIndex;
      });
      return;
    }
    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex = newIndex;
    });
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = AppBottomNav2026._pathToIndex(location);

    if (index != _currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onRouteChanged(index);
      });
    }

    final current = widget.items[_currentIndex];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = constraints.maxWidth / widget.items.length;

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.centerLeft,
          children: [
            Row(
              children: [
                for (int i = 0; i < widget.items.length; i++) ...[
                  Expanded(
                    child: _NavSlot(
                      icon: widget.items[i].icon,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        context.go(widget.items[i].path);
                        if (widget.items[i].path == '/profile') {
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => ProfileRefreshNotifier.notify(),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ],
            ),
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                final animatedIndex = _previousIndex + (_currentIndex - _previousIndex) * _animation.value;
                final pillLeft = (animatedIndex + 0.5) * cellWidth - AppBottomNav2026._pillWidth / 2;
                return Positioned(
                  left: pillLeft.clamp(0.0, constraints.maxWidth - AppBottomNav2026._pillWidth),
                  top: (constraints.maxHeight - AppBottomNav2026._pillHeight) / 2,
                  child: _SelectedPillContent(
                    icon: current.activeIcon,
                    selectionColor: widget.selectionColor,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _NavSlot extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavSlot({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppBottomNav2026._selectedPillRadius),
      child: Center(
        child: Icon(
          icon,
          size: AppBottomNav2026._iconSize,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}

class _SelectedPillContent extends StatelessWidget {
  final IconData icon;
  final Color selectionColor;

  const _SelectedPillContent({
    required this.icon,
    required this.selectionColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppBottomNav2026._pillWidth,
      height: AppBottomNav2026._pillHeight,
      decoration: BoxDecoration(
        color: selectionColor,
        borderRadius: BorderRadius.circular(AppBottomNav2026._selectedPillRadius),
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: AppBottomNav2026._iconSize,
        color: Colors.white,
      ),
    );
  }
}

class _CreateCircleButton extends StatefulWidget {
  final double size;
  final VoidCallback onPressed;

  const _CreateCircleButton({
    required this.size,
    required this.onPressed,
  });

  @override
  State<_CreateCircleButton> createState() => _CreateCircleButtonState();
}

class _CreateCircleButtonState extends State<_CreateCircleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scale = Tween<double>(begin: 1, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: _controller.reverse,
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onPressed();
      },
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Icon(
            Icons.add_rounded,
            size: 22,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}
