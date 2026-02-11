import 'package:flutter/material.dart';
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

  // Soft UI: generous padding, 18–24 radius, subtle shadow, no harsh dividers
  static const double _iconSize = 20;
  static const double _textFontSize = 14;
  static const double _textHeight = 1.25;
  static const double _gapAfterIcon = 4;
  static const double _gapBeforeLabel = 2;
  static const double _paddingH = 14;
  static const double _paddingV = 12;
  static const double _radius = 20;
  static const double _shadowBlur = 8;
  static const double _shadowOpacity = 0.06;
  static const double _shadowOffsetY = 2;
  static const double _chevronSize = 18;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelColor = widget.foregroundColor.withValues(alpha: 0.85);
    // Match screenshot: consistent dark gray text, medium weight
    final textStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w500,
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
      // One line: icon + "primaryText label" (e.g. "33 Countries", "14 Places Lived")
      final lineText = widget.label.isNotEmpty
          ? '${widget.primaryText} ${widget.label}'
          : widget.primaryText;
      columnChildren = [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: _iconSize, color: widget.foregroundColor),
            const SizedBox(width: 6),
            Text(
              lineText,
              style: textStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
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

    // No border per screenshot; distinction from background color and shadow only
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: _paddingH, vertical: _paddingV),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        color: widget.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _shadowOpacity),
            blurRadius: _shadowBlur,
            offset: Offset(0, _shadowOffsetY),
          ),
        ],
      ),
      alignment: Alignment.centerLeft,
      child: content,
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

/// One-line insight row: "X Countries · Y Places Lived". No current location (shown in identity row above).
class ProfileInsightCardsRow extends StatelessWidget {
  final int countriesCount;
  final int placesCount;
  final VoidCallback? onCountriesTap;
  final VoidCallback? onPlacesTap;

  const ProfileInsightCardsRow({
    super.key,
    required this.countriesCount,
    required this.placesCount,
    this.onCountriesTap,
    this.onPlacesTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface,
      fontWeight: FontWeight.w500,
    );

    final countriesText = '$countriesCount ${AppStrings.t(context, 'countries')}';
    final placesText = '$placesCount ${AppStrings.t(context, 'places_lived')}';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onCountriesTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Text(countriesText, style: style),
          ),
        ),
        Text(' · ', style: style),
        InkWell(
          onTap: onPlacesTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Text(placesText, style: style),
          ),
        ),
      ],
    );
  }
}
