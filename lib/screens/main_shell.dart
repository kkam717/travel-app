import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/app_bottom_nav_2026.dart';

class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final location = GoRouterState.of(context).matchedLocation;
    final isCreateOrEditTrip = location == '/create' ||
        (location.startsWith('/itinerary/') && location.endsWith('/edit'));
    final showNav = !keyboardVisible && !isCreateOrEditTrip;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: child,
          ),
          if (showNav)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: const AppBottomNav2026(),
            ),
        ],
      ),
    );
  }
}
