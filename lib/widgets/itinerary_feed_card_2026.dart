import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import '../core/app_link.dart';
import '../l10n/app_strings.dart';
import '../models/itinerary.dart';
import '../models/user_city.dart';
import 'static_map_image.dart';

/// 2026-style feed card: content-first, low-chrome, premium look.
/// No DB changes; all data from existing Itinerary. Optional UI hidden when data missing.
class ItineraryFeedCard2026 extends StatelessWidget {
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
  /// Spot-level recommendations (bars/restaurants etc) from author's lived city matching this itinerary's destination. Section only shown when non-null and non-empty.
  final List<UserTopSpot>? authorLivedHereSpots;
  final bool isAuthorFriend;

  static const double _cardRadius = 0; // Sharp edges (no rounded corners on static map)
  static const double _heroHeight = 220;

  const ItineraryFeedCard2026({
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

  /// User-inputted trip title (never route/destination).
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
    final subtitleText = it.destination.trim().isNotEmpty
        ? '${it.daysCount} ${AppStrings.t(context, 'days')} ${AppStrings.t(context, 'across')} ${it.destination}'
        : '${it.daysCount} ${AppStrings.t(context, 'days')}';
    final hasStyleChip = it.styleTags.isNotEmpty;
    final hasModeChip = it.mode != null && it.mode!.trim().isNotEmpty;
    final createdAt = it.createdAt ?? it.updatedAt;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.spacingLg, 0, AppTheme.spacingLg, AppTheme.spacingMd),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(_cardRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(_cardRadius),
            child: InkWell(
              onTap: onTap,
              onLongPress: () => _showCardSheet(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top row: avatar, author, time, more
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppTheme.spacingMd, AppTheme.spacingMd, AppTheme.spacingSm, 0),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: onAuthorTap,
                            borderRadius: BorderRadius.circular(20),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                  backgroundImage: it.authorPhotoUrl != null && it.authorPhotoUrl!.isNotEmpty
                                      ? NetworkImage(it.authorPhotoUrl!)
                                      : null,
                                  child: it.authorPhotoUrl == null || it.authorPhotoUrl!.isEmpty
                                      ? Icon(Icons.person_outline_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant)
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    it.authorName ?? AppStrings.t(context, 'unknown'),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                        ),
                        const Spacer(),
                        if (createdAt != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              _relativeTime(context, createdAt),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        IconButton(
                          icon: const Icon(Icons.more_horiz_rounded),
                          onPressed: () => _showCardSheet(context),
                          style: IconButton.styleFrom(
                            foregroundColor: theme.colorScheme.onSurfaceVariant,
                            minimumSize: const Size(40, 40),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Title block
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppTheme.spacingMd, AppTheme.spacingSm, AppTheme.spacingMd, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayTitle,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitleText,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Social proof (optional): "X saved"
                  if (it.bookmarkCount != null && it.bookmarkCount! > 0) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
                      child: Text(
                        '${it.bookmarkCount} ${AppStrings.t(context, 'saved_count')}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                  // Tag chips
                  if (hasStyleChip || hasModeChip) ...[
                    const SizedBox(height: AppTheme.spacingSm),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (hasStyleChip)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                it.styleTags.first.length > 1
                                    ? '${it.styleTags.first[0].toUpperCase()}${it.styleTags.first.substring(1).toLowerCase()}'
                                    : it.styleTags.first,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          if (hasModeChip)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: it.mode == 'luxury'
                                    ? Colors.purple.withValues(alpha: 0.12)
                                    : theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                it.mode!.toUpperCase(),
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: it.mode == 'luxury'
                                      ? Colors.purple.shade700
                                      : theme.colorScheme.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppTheme.spacingMd),
                  // Hero map with gradient overlay (LayoutBuilder ensures finite width for StaticMapImage)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final heroWidth = constraints.maxWidth;
                        return Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            SizedBox(
                                height: _heroHeight,
                                width: heroWidth,
                                child: GestureDetector(
                                  onDoubleTap: () {
                                    if (onLike != null) {
                                      HapticFeedback.mediumImpact();
                                      onLike!();
                                    }
                                  },
                                  child: StaticMapImage(
                                    itinerary: it,
                                    width: heroWidth,
                                    height: _heroHeight,
                                    pathColor: theme.colorScheme.primary,
                                  ),
                                ),
                            ),  // SizedBox
                            // Gradient overlay for legibility
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
                          ],
                        );
                      },
                    ),
                  ),
                  // From someone who lived here: spot-level recommendations (bars/restaurants etc) from author's lived city matching this itinerary's destination
                  if (livedHereSpots != null && livedHereSpots.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppTheme.spacingMd, AppTheme.spacingSm, AppTheme.spacingMd, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                AppStrings.t(context, 'from_someone_who_lived_here'),
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (isAuthorFriend) ...[
                                const SizedBox(width: 8),
                                Icon(Icons.people_rounded, size: 16, color: theme.colorScheme.primary),
                                const SizedBox(width: 4),
                                Text(
                                  AppStrings.t(context, 'following'),
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          ...livedHereSpots.map((spot) {
                            final label = _categoryLabel(context, spot.category);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.place_rounded,
                                    size: 18,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${spot.name} · $label',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                  // Actions row (bottom-right)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppTheme.spacingMd, AppTheme.spacingSm, AppTheme.spacingMd, AppTheme.spacingMd),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (onLike != null)
                          _ActionChip(
                            icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            label: likeCount > 0 ? '$likeCount' : null,
                            active: isLiked,
                            onTap: onLike!,
                          ),
                        const SizedBox(width: 8),
                        _ActionChip(
                          icon: Icons.share_outlined,
                          onTap: () => shareItineraryLink(it.id, title: it.title),
                        ),
                        const SizedBox(width: 8),
                        _ActionChip(
                          icon: isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                          active: isBookmarked,
                          onTap: onBookmark,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    );
  }

  void _showCardSheet(BuildContext context) {
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

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String? label;
  final bool active;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    this.label,
    this.active = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = active ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            if (label != null) ...[
              const SizedBox(width: 4),
              Text(
                label!,
                style: theme.textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w500),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
