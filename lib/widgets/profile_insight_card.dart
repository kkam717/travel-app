import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../l10n/app_strings.dart';

/// Editorial insight card for profile KPIs: soft rounded container, icon + value + label.
/// Used in a horizontal row; no dividers, no harsh borders/shadows.
class ProfileInsightCard extends StatefulWidget {
  final IconData icon;
  /// Primary value (e.g. "10") or text (e.g. city name). Shown medium-large, semibold.
  final String primaryText;
  /// Label below primary (e.g. "Countries"). Omit for single-line cards.
  final String label;
  /// Soft background tint for the card (e.g. teal, warm neutral, location accent).
  final Color backgroundColor;
  /// Icon and text accent; should work on [backgroundColor].
  final Color foregroundColor;
  /// When true, show a trailing chevron so the card reads as a navigational entry (e.g. Travel Profile).
  final bool showAsNavigation;
  /// When true, show primary text on the same line as the icon, to its right (e.g. Countries: [globe] 7).
  final bool primarySameLineAsIcon;
  final VoidCallback? onTap;

  const ProfileInsightCard({
    super.key,
    required this.icon,
    required this.primaryText,
    this.label = '',
    required this.backgroundColor,
    required this.foregroundColor,
    this.showAsNavigation = false,
    this.primarySameLineAsIcon = false,
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

  // Compact layout so cards don't compete with profile header
  static const double _iconSize = 18;
  static const double _textFontSize = 13;
  static const double _textHeight = 1.2;
  static const double _gapAfterIcon = 4;
  static const double _gapBeforeLabel = 2;
  static const double _paddingH = 10;
  static const double _paddingV = 8;
  static const double _radius = 14;
  static const double _shadowBlur = 4;
  static const double _shadowOpacity = 0.03;
  static const double _chevronSize = 16;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelColor = widget.foregroundColor.withValues(alpha: 0.85);

    final textStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: _textFontSize,
      color: widget.foregroundColor,
      height: _textHeight,
    );
    final labelStyle = textStyle?.copyWith(color: labelColor);

    Widget primaryContent;
    if (widget.showAsNavigation) {
      primaryContent = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              widget.primaryText,
              style: textStyle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, size: _chevronSize, color: widget.foregroundColor),
        ],
      );
    } else {
      primaryContent = Text(
        widget.primaryText,
        style: textStyle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    final List<Widget> columnChildren;
    if (widget.primarySameLineAsIcon) {
      columnChildren = [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: _iconSize, color: widget.foregroundColor),
            const SizedBox(width: 6),
            Text(
              widget.primaryText,
              style: textStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        if (widget.label.isNotEmpty) ...[
          const SizedBox(height: _gapBeforeLabel),
          Text(
            widget.label,
            style: labelStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ];
    } else {
      columnChildren = [
        Icon(widget.icon, size: _iconSize, color: widget.foregroundColor),
        const SizedBox(height: _gapAfterIcon),
        primaryContent,
        if (widget.label.isNotEmpty) ...[
          const SizedBox(height: _gapBeforeLabel),
          Text(
            widget.label,
            style: labelStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ];
    }

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: columnChildren,
    );

    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: _paddingH, vertical: _paddingV),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        color: widget.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _shadowOpacity),
            blurRadius: _shadowBlur,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.centerLeft,
      child: SizedBox(width: double.infinity, child: content),
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

  static const double _minWidthForFlexRow = 320;
  static const double _minCardWidth = 96;
  static const double _cardGap = 8;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tealTint = cs.primary.withValues(alpha: 0.22);
    final tealFg = cs.primary.withValues(alpha: 0.95);
    final warmTint = const Color(0xFFE07856).withValues(alpha: 0.2);
    final warmFg = const Color(0xFFB4532A);
    final locationTint = const Color(0xFFD97706).withValues(alpha: 0.2);
    final locationFg = const Color(0xFF92400E);

    final cityLabel = currentCity?.trim().isNotEmpty == true
        ? currentCity!
        : AppStrings.t(context, 'home');

    final cards = [
      ProfileInsightCard(
        icon: Icons.public_rounded,
        primaryText: '$countriesCount',
        label: AppStrings.t(context, 'countries'),
        backgroundColor: tealTint,
        foregroundColor: tealFg,
        primarySameLineAsIcon: true,
        onTap: onCountriesTap,
      ),
      ProfileInsightCard(
        icon: Icons.location_city_rounded,
        primaryText: AppStrings.t(context, 'travel_profile'),
        label: '',
        backgroundColor: warmTint,
        foregroundColor: warmFg,
        showAsNavigation: true,
        onTap: onPlacesTap,
      ),
      ProfileInsightCard(
        icon: Icons.location_on_rounded,
        primaryText: cityLabel,
        label: '',
        backgroundColor: locationTint,
        foregroundColor: locationFg,
        onTap: onBaseTap,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useFlex = constraints.maxWidth >= _minWidthForFlexRow;
        final row = IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: useFlex ? MainAxisSize.max : MainAxisSize.min,
            children: [
              useFlex ? Expanded(child: cards[0]) : SizedBox(width: _minCardWidth, child: cards[0]),
              const SizedBox(width: _cardGap),
              useFlex ? Expanded(child: cards[1]) : SizedBox(width: _minCardWidth, child: cards[1]),
              const SizedBox(width: _cardGap),
              useFlex ? Expanded(child: cards[2]) : SizedBox(width: _minCardWidth, child: cards[2]),
            ],
          ),
        );
        if (useFlex) return row;
        return SingleChildScrollView(scrollDirection: Axis.horizontal, child: row);
      },
    );
  }
}
