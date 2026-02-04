import 'package:flutter/material.dart';
import '../data/countries.dart';
import '../data/country_names_localized.dart';

/// Horizontal scroll of country filter chips (flag + name). Soft pills.
class CountryFilterChips extends StatelessWidget {
  final List<String> countryCodes;
  final String? selectedCode;
  final ValueChanged<String?> onSelected;

  const CountryFilterChips({
    super.key,
    required this.countryCodes,
    this.selectedCode,
    required this.onSelected,
  });

  /// Flag emoji from ISO 3166-1 alpha-2 code (e.g. "US" -> 🇺🇸).
  static String flagEmoji(String code) {
    if (code.length != 2) return '';
    final a = 0x1F1E6 + (code.codeUnitAt(0) - 0x41);
    final b = 0x1F1E6 + (code.codeUnitAt(1) - 0x41);
    return String.fromCharCodes([a, b]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (countryCodes.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: countryCodes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final code = countryCodes[i];
          final name = getCountryName(context, code);
          final isSelected = selectedCode == code;
          return Material(
            color: isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.6)
                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: () => onSelected(isSelected ? null : code),
              borderRadius: BorderRadius.circular(999),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Center(
                        child: Text(
                          flagEmoji(code),
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface,
                            height: 1.0,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Center(
                        child: Text(
                          name.length > 12 ? '${name.substring(0, 12)}…' : name,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
