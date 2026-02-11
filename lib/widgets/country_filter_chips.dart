import 'package:flutter/material.dart';
import '../data/country_names_localized.dart';

/// Compact horizontal filter chips: small flag + country name. Apple 2026–style.
/// When [showAllChip] is true, prepends an "All" chip (selected when [selectedCode] is null).
class CountryFilterChips extends StatelessWidget {
  final List<String> countryCodes;
  final String? selectedCode;
  final ValueChanged<String?> onSelected;
  final bool showAllChip;

  const CountryFilterChips({
    super.key,
    required this.countryCodes,
    this.selectedCode,
    required this.onSelected,
    this.showAllChip = false,
  });

  /// Flag emoji from ISO 3166-1 alpha-2 code (e.g. "US" -> 🇺🇸).
  static String flagEmoji(String code) {
    if (code.length != 2) return '';
    final a = 0x1F1E6 + (code.codeUnitAt(0) - 0x41);
    final b = 0x1F1E6 + (code.codeUnitAt(1) - 0x41);
    return String.fromCharCodes([a, b]);
  }

  static const double chipRadius = 10;
  static const double chipPaddingH = 10;
  static const double chipPaddingV = 5;
  static const double chipGap = 6;
  static const double chipSpacing = 8;
  static const double flagFontSize = 13;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final list = countryCodes;
    final itemCount = list.isEmpty ? (showAllChip ? 1 : 0) : (showAllChip ? list.length + 1 : list.length);
    if (itemCount == 0) return const SizedBox.shrink();
    final cs = theme.colorScheme;

    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(width: chipSpacing),
        itemBuilder: (context, i) {
          if (showAllChip && i == 0) {
            final isSelected = selectedCode == null;
            return _Chip(
              isSelected: isSelected,
              label: 'All',
              leading: null,
              onTap: () => onSelected(null),
              colorScheme: cs,
              textTheme: theme.textTheme,
            );
          }
          final code = list[showAllChip ? i - 1 : i];
          final name = getCountryName(context, code);
          final isSelected = selectedCode == code;
          return _Chip(
            isSelected: isSelected,
            label: name.length > 14 ? '${name.substring(0, 14)}…' : name,
            leading: flagEmoji(code),
            onTap: () => onSelected(isSelected ? null : code),
            colorScheme: cs,
            textTheme: theme.textTheme,
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final bool isSelected;
  final String label;
  final String? leading;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _Chip({
    required this.isSelected,
    required this.label,
    this.leading,
    required this.onTap,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isSelected ? colorScheme.primary : colorScheme.surfaceContainerHighest;
    final foregroundColor = isSelected ? colorScheme.onPrimary : colorScheme.onSurface;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CountryFilterChips.chipRadius),
        color: backgroundColor,
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.12),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(CountryFilterChips.chipRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(CountryFilterChips.chipRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: CountryFilterChips.chipPaddingH, vertical: CountryFilterChips.chipPaddingV),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[
                  Text(
                    leading!,
                    style: textTheme.labelMedium?.copyWith(
                      fontSize: CountryFilterChips.flagFontSize,
                      height: 1.0,
                      color: foregroundColor,
                    ),
                  ),
                  const SizedBox(width: CountryFilterChips.chipGap),
                ],
                Text(
                  label,
                  style: textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: foregroundColor,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
