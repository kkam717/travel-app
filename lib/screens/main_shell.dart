import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../core/profile_refresh_notifier.dart';

class _AddTripButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _AddTripButton({required this.onPressed});

  @override
  State<_AddTripButton> createState() => _AddTripButtonState();
}

class _AddTripButtonState extends State<_AddTripButton> {
  static const _debounceMs = 600;
  DateTime? _lastTap;

  void _handleTap() {
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!).inMilliseconds < _debounceMs) return;
    _lastTap = now;

    HapticFeedback.lightImpact();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onPressed();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: _handleTap,
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
      elevation: 4,
      child: const Icon(Icons.add_rounded, size: 28),
    );
  }
}

class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home', path: '/home'),
                _NavItem(icon: Icons.search_rounded, activeIcon: Icons.search_rounded, label: 'Search', path: '/search'),
                const SizedBox(width: 64),
                _NavItem(icon: Icons.bookmark_outline_rounded, activeIcon: Icons.bookmark_rounded, label: 'Saved', path: '/saved'),
                _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile', path: '/profile'),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: Transform.translate(
        offset: const Offset(0, 20),
        child: _AddTripButton(onPressed: () => context.go('/create')),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.path,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = GoRouterState.of(context).matchedLocation == path;
    final color = isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: () {
        context.go(path);
        if (path == '/profile') {
          WidgetsBinding.instance.addPostFrameCallback((_) => ProfileRefreshNotifier.notify());
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isSelected ? activeIcon : icon, size: 26, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
