import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../l10n/app_strings.dart';

/// Editorial insight card for profile KPIs: soft rounded container, icon + value + label.
/// Used in a horizontal row; no dividers, no harsh borders/shadows.
class ProfileInsightCard extends StatefulWidget {
  final IconData icon;
  /// Primary value (e.g. "10") or text (e.g. city name). Shown medium-large, semibold.
  final String primaryText;
  /// Label below primary (e.g. "Countries", "Places", "Based in or Home"). Small, muted.
  final String label;
  /// Soft background tint for the card (e.g. teal, warm neutral, location accent).
  final Color backgroundColor;
  /// Icon and text accent; should work on [backgroundColor].
  final Color foregroundColor;
  final VoidCallback? onTap;

  const ProfileInsightCard({
    super.key,
    required this.icon,
    required this.primaryText,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.onTap,
  });

  @override
  State<ProfileInsightCard> createState() => _ProfileInsightCardState();
}

class _ProfileInsightCardState extends State<ProfileInsightCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
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
    final theme = Theme.of(context);
    final labelColor = widget.foregroundColor.withValues(alpha: 0.85);

    Widget card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: widget.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            widget.icon,
            size: 20,
            color: widget.foregroundColor,
          ),
          const SizedBox(height: 6),
          Text(
            widget.primaryText,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: widget.foregroundColor,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (widget.label.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              widget.label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: labelColor,
                fontWeight: FontWeight.w500,
                fontSize: 11,
                height: 1.0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );

    if (widget.onTap != null) {
      return GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) => _controller.reverse(),
        onTapCancel: () => _controller.reverse(),
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _scale,
          builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
          child: card,
        ),
      );
    }
    return card;
  }
}

/// Three horizontally aligned insight cards: Countries, Places, Base/Location.
/// Editorial style; equal height, flexible width; no dividers.
class ProfileInsightCardsRow extends StatelessWidget {
  final int countriesCount;
  final int placesCount;
  final String? currentCity;
  final VoidCallback? onCountriesTap;
  final VoidCallback? onPlacesTap;
  final VoidCallback? onBaseTap;

  const ProfileInsightCardsRow({
    super.key,
    required this.countriesCount,
    required this.placesCount,
    this.currentCity,
    this.onCountriesTap,
    this.onPlacesTap,
    this.onBaseTap,
  });

  /// Below this width, cards use a minimum width and row scrolls horizontally.
  static const double _minWidthForFlexRow = 320;
  static const double _minCardWidth = 96;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Card 1: cool / teal tint
    final tealTint = cs.primary.withValues(alpha: 0.22);
    final tealFg = cs.primary.withValues(alpha: 0.95);
    // Card 2: warm / neutral tint
    final warmTint = const Color(0xFFE07856).withValues(alpha: 0.2);
    final warmFg = const Color(0xFFB4532A);
    // Card 3: location-accent tint
    final locationTint = const Color(0xFFD97706).withValues(alpha: 0.2);
    final locationFg = const Color(0xFF92400E);

    final cards = [
      ProfileInsightCard(
        icon: Icons.public_rounded,
        primaryText: '$countriesCount',
        label: AppStrings.t(context, 'countries'),
        backgroundColor: tealTint,
        foregroundColor: tealFg,
        onTap: onCountriesTap,
      ),
      ProfileInsightCard(
        icon: Icons.location_city_rounded,
        primaryText: AppStrings.t(context, 'travel_profile'),
        label: '',
        backgroundColor: warmTint,
        foregroundColor: warmFg,
        onTap: onPlacesTap,
      ),
      ProfileInsightCard(
        icon: Icons.location_on_rounded,
        primaryText: currentCity?.trim().isNotEmpty == true
            ? currentCity!
            : AppStrings.t(context, 'home'),
        label: '',
        backgroundColor: locationTint,
        foregroundColor: locationFg,
        onTap: onBaseTap,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _minWidthForFlexRow) {
          return Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 8),
              Expanded(child: cards[1]),
              const SizedBox(width: 8),
              Expanded(child: cards[2]),
            ],
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: _minCardWidth, child: cards[0]),
              const SizedBox(width: 8),
              SizedBox(width: _minCardWidth, child: cards[1]),
              const SizedBox(width: 8),
              SizedBox(width: _minCardWidth, child: cards[2]),
            ],
          ),
        );
      },
    );
  }
}
