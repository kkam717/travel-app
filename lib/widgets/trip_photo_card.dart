import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/app_link.dart';
import '../l10n/app_strings.dart';
import '../models/itinerary.dart';
import 'static_map_image.dart';

/// Large photo-background trip card: photo is the card, text overlaid. Reference style.
class TripPhotoCard extends StatelessWidget {
  final Itinerary itinerary;
  final VoidCallback? onRefresh;
  final bool canEdit;

  static const double _cardRadius = 28;
  static const double _heroHeight = 220;

  const TripPhotoCard({
    super.key,
    required this.itinerary,
    this.onRefresh,
    this.canEdit = false,
  });

  String _displayTitle(Itinerary it) => it.title.trim().isNotEmpty ? it.title : it.destination;

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
    final displayTitle = _displayTitle(it);
    final destinationLine = it.destination.trim().isNotEmpty ? it.destination : '${it.daysCount} ${AppStrings.t(context, 'days')}';
    final highlights = _highlights(it);
    final dateStr = _formatDate(it.startDate ?? it.createdAt ?? it.updatedAt);

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.spacingLg, 0, AppTheme.spacingLg, AppTheme.spacingLg),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(_cardRadius),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        child: InkWell(
          onTap: () async {
            await context.push('/itinerary/${it.id}');
            onRefresh?.call();
          },
          borderRadius: BorderRadius.circular(_cardRadius),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              return Stack(
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
                    height: _heroHeight * 0.7,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 16,
                    child: Text(
                      dateStr,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
                      onPressed: () => _showMenu(context),
                      style: IconButton.styleFrom(minimumSize: const Size(40, 40)),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayTitle,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 22,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          destinationLine,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 16, color: Colors.white.withValues(alpha: 0.95)),
                            const SizedBox(width: 6),
                            Text(
                              '${it.daysCount} ${AppStrings.t(context, 'days')}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        if (highlights.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            highlights.join(' · '),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
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
              if (canEdit)
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
