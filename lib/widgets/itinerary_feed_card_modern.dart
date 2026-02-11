import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import '../core/app_link.dart';
import '../l10n/app_strings.dart';
import '../models/itinerary.dart';
import '../models/user_city.dart';
import 'static_map_image.dart';

/// Home feed card matching mock: white card, author row, title/meta, chips, media, like row, optional lived-here.
/// Same API as ItineraryFeedItemModern; no save icon on card (bookmark via long-press sheet and detail).
class ItineraryFeedCardModern extends StatelessWidget {
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
  final List<UserTopSpot>? authorLivedHereSpots;
  final bool isAuthorFriend;

  static const double _cardRadius = 22;
  static const double _mediaRadius = 16;
  static const double _livedHereRadius = 14;
  static const double _heroHeight = 220;
  static const double _avatarRadius = 20;
  static const EdgeInsets _cardMargin = EdgeInsets.symmetric(horizontal: 16, vertical: 6);
  static const EdgeInsets _cardPadding = EdgeInsets.fromLTRB(24, 20, 24, 20);

  const ItineraryFeedCardModern({
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
    this.authorLivedHereSpots,
    this.isAuthorFriend = false,
  });

  static String _categoryLabel(BuildContext context, String cat) {
    switch (cat) {
      case 'eat': return AppStrings.t(context, 'top_spot_eat');
      case 'drink': return AppStrings.t(context, 'top_spot_drink');
      case 'date': return AppStrings.t(context, 'top_spot_date');
      case 'chill': return AppStrings.t(context, 'top_spot_chill');
      default: return cat;
    }
  }

  String _displayTitle(Itinerary it) => it.title.trim().isNotEmpty ? it.title : it.destination;

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
    final displayTitle = _displayTitle(it);
    final livedHereSpots = authorLivedHereSpots;
    final createdAt = it.createdAt ?? it.updatedAt;
    final timeStr = createdAt != null ? _relativeTime(context, createdAt) : null;
    final metaLine = it.destination.trim().isNotEmpty && timeStr != null
        ? '${it.destination.toUpperCase()} • ${timeStr.toUpperCase()}'
        : (timeStr ?? '').toUpperCase();
    final daysPillLabel = '${it.daysCount} ${AppStrings.t(context, 'days').toUpperCase()}';

    return Container(
      margin: _cardMargin,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(_cardRadius),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: () => _showSheet(context),
          child: Padding(
            padding: _cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Author row only: avatar + name + meta, friend pill, subtle share icon
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: onAuthorTap,
                      borderRadius: BorderRadius.circular(_avatarRadius + 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: _avatarRadius,
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            backgroundImage: it.authorPhotoUrl != null && it.authorPhotoUrl!.isNotEmpty
                                ? NetworkImage(it.authorPhotoUrl!)
                                : null,
                            child: it.authorPhotoUrl == null || it.authorPhotoUrl!.isEmpty
                                ? Icon(Icons.person_outline_rounded, size: 24, color: theme.colorScheme.onSurfaceVariant)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        it.authorName ?? AppStrings.t(context, 'unknown'),
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isAuthorFriend) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          AppStrings.t(context, 'following'),
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (metaLine.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    metaLine,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () => shareItineraryLink(it.id, title: it.title),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.share_outlined,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 2. Media: full-width, rounded; optional "X day path" pill top-left; double-tap like
                ClipRRect(
                  borderRadius: BorderRadius.circular(_mediaRadius),
                  child: SizedBox(
                    height: _heroHeight,
                    width: double.infinity,
                    child: GestureDetector(
                      onDoubleTap: () {
                        if (onLike != null) {
                          HapticFeedback.mediumImpact();
                          onLike!();
                        }
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        alignment: Alignment.topLeft,
                        children: [
                          StaticMapImage(
                            itinerary: it,
                            width: double.infinity,
                            height: _heroHeight,
                            pathColor: theme.colorScheme.primary,
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: 48,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    theme.colorScheme.shadow.withValues(alpha: 0.15),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 12,
                            top: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.route_rounded, size: 14, color: theme.colorScheme.onPrimary),
                                  const SizedBox(width: 6),
                                  Text(
                                    daysPillLabel,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // 3. Title only (no heart/like on card)
                Text(
                  displayTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                // 4. Lived here: minimal inset (only when present)
                if (livedHereSpots != null && livedHereSpots.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(_livedHereRadius),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppStrings.t(context, 'from_someone_who_lived_here'),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...livedHereSpots.map((spot) {
                          final label = _categoryLabel(context, spot.category);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              '${spot.name} · $label',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
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
