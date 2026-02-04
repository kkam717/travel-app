import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../l10n/app_strings.dart';

/// Three large stat tiles in a frosted/glass container (Countries, Lived, Home pin).
class ProfileStatTilesRow extends StatelessWidget {
  final int countriesCount;
  final int livedCount;
  final String? currentCity;
  final VoidCallback? onCountriesTap;
  final VoidCallback? onLivedTap;
  final VoidCallback? onHomeTap;

  const ProfileStatTilesRow({
    super.key,
    required this.countriesCount,
    required this.livedCount,
    this.currentCity,
    this.onCountriesTap,
    this.onLivedTap,
    this.onHomeTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatTile(
              icon: Icons.public_rounded,
              label: '${AppStrings.t(context, 'countries')} ($countriesCount)',
              tint: theme.colorScheme.primary.withValues(alpha: 0.25),
              onTap: onCountriesTap,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _StatTile(
              icon: Icons.location_city_rounded,
              label: '${AppStrings.t(context, 'lived')} ($livedCount)',
              tint: Colors.orange.withValues(alpha: 0.25),
              onTap: onLivedTap,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _StatTile(
              icon: Icons.location_on_rounded,
              label: currentCity?.trim().isNotEmpty == true ? currentCity! : AppStrings.t(context, 'home'),
              tint: Colors.amber.withValues(alpha: 0.25),
              onTap: onHomeTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color tint;
  final VoidCallback? onTap;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.tint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final child = Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: tint,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: theme.colorScheme.onSurface.withValues(alpha: 0.9)),
            const SizedBox(height: 6),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
                fontSize: 11,
                height: 1.0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: child,
      );
    }
    return child;
  }
}
