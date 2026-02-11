import 'package:flutter/material.dart';
import 'visited_countries_map_screen.dart';

/// Pushes the full countries map with an animation that expands from [sourceRect]
/// (e.g. the profile hero map card) to full screen.
class ExpandMapRoute extends PageRoute<void> {
  ExpandMapRoute({
    required this.codes,
    this.canEdit = false,
    Rect? sourceRect,
  }) : _sourceRect = sourceRect;

  final List<String> codes;
  final bool canEdit;
  final Rect? _sourceRect;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 400);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return VisitedCountriesMapScreen(visitedCountryCodes: codes, canEdit: canEdit);
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    final rect = _sourceRect;
    if (rect == null) {
      return FadeTransition(opacity: animation, child: child);
    }
    final screenSize = MediaQuery.of(context).size;
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic);
    return AnimatedBuilder(
      animation: curved,
      builder: (context, _) {
        final t = curved.value;
        final scaleX = rect.width / screenSize.width + (1 - rect.width / screenSize.width) * t;
        final scaleY = rect.height / screenSize.height + (1 - rect.height / screenSize.height) * t;
        final offsetX = rect.left * (1 - t);
        final offsetY = rect.top * (1 - t);
        return Transform.translate(
          offset: Offset(offsetX, offsetY),
          child: Transform.scale(
            scaleX: scaleX,
            scaleY: scaleY,
            alignment: Alignment.topLeft,
            child: child,
          ),
        );
      },
    );
  }
}
