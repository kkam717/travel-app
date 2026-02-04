import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/app_link.dart';
import '../l10n/app_strings.dart';
import '../models/itinerary.dart';
import 'static_map_image.dart';

/// 2026-style trip card for profile: date + menu, title, subtitle, chips, highlights, hero.
/// Actions in overflow menu (Share, Edit); tap opens itinerary.
class TripCardModern extends StatelessWidget {
  final Itinerary itinerary;
  final VoidCallback? onRefresh;

  static const double _heroHeight = 200;
  static const double _cardRadius = 24;

  const TripCardModern({
    super.key,
    required this.itinerary,
    this.onRefresh,
  });

  String _routeTitle(Itinerary it) {
    final locationStops = it.stops.where((s) => s.isLocation).toList();
    if (locationStops.length >= 2) {
      return locationStops.take(4).map((s) => s.name).join(' → ');
    }
    if (locationStops.length == 1) return locationStops.first.name;
    return it.destination.isNotEmpty ? it.destination : it.title;
  }

  List<String> _highlights(Itinerary it) {
    return it.stops.where((s) => s.isVenue).take(2).map((s) => s.name).toList();
  }

  static String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final it = itinerary;
    final routeTitle = _routeTitle(it);
    final subtitle = it.destination.trim().isNotEmpty
        ? '${it.destination} · ${it.daysCount} ${AppStrings.t(context, 'days')}'
        : '${it.daysCount} ${AppStrings.t(context, 'days')}';
    final hasStyle = it.styleTags.isNotEmpty;
    final hasMode = it.mode != null && it.mode!.trim().isNotEmpty;
    final highlights = _highlights(it);
    final dateStr = _formatDate(it.startDate ?? it.createdAt ?? it.updatedAt);

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.spacingLg, 0, AppTheme.spacingLg, AppTheme.spacingLg),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(_cardRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            await context.push('/itinerary/${it.id}');
            onRefresh?.call();
          },
          borderRadius: BorderRadius.circular(_cardRadius),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top row: date (muted) + overflow menu
              Padding(
                padding: const EdgeInsets.fromLTRB(AppTheme.spacingMd, AppTheme.spacingMd, AppTheme.spacingSm, 0),
                child: Row(
                  children: [
                    if (dateStr.isNotEmpty)
                      Text(
                        dateStr,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.more_horiz_rounded),
                      onPressed: () => _showMenu(context),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(40, 40),
                        foregroundColor: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.fromLTRB(AppTheme.spacingMd, 0, AppTheme.spacingMd, 4),
                child: Text(
                  routeTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 22,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Subtitle
              Padding(
                padding: const EdgeInsets.fromLTRB(AppTheme.spacingMd, 0, AppTheme.spacingMd, 0),
                child: Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Chips row
              if (hasStyle || hasMode) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppTheme.spacingMd, 0, AppTheme.spacingMd, 0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (hasStyle)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            it.styleTags.first.length > 1
                                ? '${it.styleTags.first[0].toUpperCase()}${it.styleTags.first.substring(1).toLowerCase()}'
                                : it.styleTags.first,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      if (hasMode)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: (it.mode == 'luxury' ? Colors.purple : theme.colorScheme.primary).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            it.mode!.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: it.mode == 'luxury' ? Colors.purple.shade700 : theme.colorScheme.primary.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              // Highlights line
              if (highlights.isNotEmpty) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppTheme.spacingMd, 0, AppTheme.spacingMd, 0),
                  child: Text(
                    highlights.join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const SizedBox(height: AppTheme.spacingMd),
              // Hero visual
              LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  return ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(_cardRadius),
                      bottomRight: Radius.circular(_cardRadius),
                    ),
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        SizedBox(
                          height: _heroHeight,
                          width: w,
                          child: StaticMapImage(
                            itinerary: it,
                            width: w,
                            height: _heroHeight,
                            pathColor: theme.colorScheme.primary,
                          ),
                        ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 80,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.35),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: AppTheme.spacingMd,
                      bottom: AppTheme.spacingMd,
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 16, color: Colors.white.withValues(alpha: 0.95)),
                          const SizedBox(width: 6),
                          Text(
                            '${it.daysCount} ${AppStrings.t(context, 'days')}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    HapticFeedback.lightImpact();
    final it = itinerary;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: Text(AppStrings.t(ctx, 'share_link')),
                onTap: () {
                  Navigator.pop(ctx);
                  shareItineraryLink(it.id, title: it.title);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(AppStrings.t(ctx, 'edit_trip')),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/itinerary/${it.id}/edit').then((_) => onRefresh?.call());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
