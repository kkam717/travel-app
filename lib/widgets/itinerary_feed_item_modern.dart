import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import '../core/app_link.dart';
import '../l10n/app_strings.dart';
import '../models/itinerary.dart';
import 'static_map_image.dart';

/// Editorial, content-first feed item. No card container, edge-to-edge hero, no visible action row.
/// Actions: ⋯ menu, double-tap hero → like, long-press → bottom sheet.
class ItineraryFeedItemModern extends StatelessWidget {
  final Itinerary itinerary;
  final String description;
  final String locations;
  final bool isBookmarked;
  final VoidCallback onBookmark;
  final bool isLiked;
  final int likeCount;
  final VoidCallback? onLike;
  final VoidCallback onTap;
  final VoidCallback onAuthorTap;

  static const double _heroHeight = 300;

  const ItineraryFeedItemModern({
    super.key,
    required this.itinerary,
    required this.description,
    required this.locations,
    required this.isBookmarked,
    required this.onBookmark,
    required this.isLiked,
    required this.likeCount,
    this.onLike,
    required this.onTap,
    required this.onAuthorTap,
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

  static String _relativeTime(BuildContext context, DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}${AppStrings.t(context, 'time_d_ago')}';
    if (diff.inHours > 0) return '${diff.inHours}${AppStrings.t(context, 'time_h_ago')}';
    if (diff.inMinutes > 0) return '${diff.inMinutes}${AppStrings.t(context, 'time_m_ago')}';
    return AppStrings.t(context, 'just_now');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final it = itinerary;
    final routeTitle = _routeTitle(it);
    final highlights = _highlights(it);
    final subtitleText = it.destination.trim().isNotEmpty
        ? '${it.daysCount} ${AppStrings.t(context, 'days')} ${AppStrings.t(context, 'across')} ${it.destination}'
        : '${it.daysCount} ${AppStrings.t(context, 'days')}';
    final hasStyleChip = it.styleTags.isNotEmpty;
    final hasModeChip = it.mode != null && it.mode!.trim().isNotEmpty;
    final createdAt = it.createdAt ?? it.updatedAt;
    final showSocialProof = it.bookmarkCount != null && it.bookmarkCount! > 0;

    return InkWell(
      onTap: onTap,
      onLongPress: () => _showSheet(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Author row (no container)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
            child: Row(
              children: [
                InkWell(
                  onTap: onAuthorTap,
                  borderRadius: BorderRadius.circular(20),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        backgroundImage: it.authorPhotoUrl != null && it.authorPhotoUrl!.isNotEmpty
                            ? NetworkImage(it.authorPhotoUrl!)
                            : null,
                        child: it.authorPhotoUrl == null || it.authorPhotoUrl!.isEmpty
                            ? Icon(Icons.person_outline_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              it.authorName ?? AppStrings.t(context, 'unknown'),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (createdAt != null)
                              Text(
                                _relativeTime(context, createdAt),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.more_horiz_rounded),
                  onPressed: () => _showSheet(context),
                  style: IconButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurfaceVariant,
                    minimumSize: const Size(40, 40),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          // 2. Title block (high emphasis)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  routeTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitleText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          // 3. Meta chips (one style, one mode; soft pills)
          if (hasStyleChip || hasModeChip) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (hasStyleChip)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(16),
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
                  if (hasModeChip)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: (it.mode == 'luxury' ? Colors.purple : theme.colorScheme.primary).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
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
          const SizedBox(height: AppTheme.spacingMd),
          // 4. Hero visual (full-bleed, primary focus)
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              return Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  SizedBox(
                      height: _heroHeight,
                      width: w,
                      child: GestureDetector(
                        onDoubleTap: () {
                          if (onLike != null) {
                            HapticFeedback.mediumImpact();
                            onLike!();
                          }
                        },
                        child: StaticMapImage(
                          itinerary: it,
                          width: w,
                          height: _heroHeight,
                          pathColor: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 100,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.25),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppTheme.spacingMd),
          // 5. Social proof (text only)
          if (showSocialProof) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
              child: Text(
                '${it.bookmarkCount} ${AppStrings.t(context, 'saved_count')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
          ],
          // 6. Highlights (plain text, muted; max 2)
          if (highlights.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.t(context, 'from_someone_who_lived_here'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    highlights.join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingLg),
          ] else
            const SizedBox(height: AppTheme.spacingLg),
        ],
      ),
    );
  }

  void _showSheet(BuildContext context) {
    HapticFeedback.lightImpact();
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
                  shareItineraryLink(itinerary.id, title: itinerary.title);
                },
              ),
              ListTile(
                leading: Icon(isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
                title: Text(isBookmarked ? AppStrings.t(ctx, 'bookmarked') : AppStrings.t(ctx, 'save')),
                onTap: () {
                  Navigator.pop(ctx);
                  onBookmark();
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: Text(AppStrings.t(ctx, 'view_author_profile')),
                onTap: () {
                  Navigator.pop(ctx);
                  onAuthorTap();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
