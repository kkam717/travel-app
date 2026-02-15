import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../models/itinerary.dart';
import '../l10n/app_strings.dart';
import 'static_map_image.dart';

/// Profile tab: user's bookmarked itineraries from other travelers.
class SavedTab extends StatelessWidget {
  final List<Itinerary> bookmarked;
  final VoidCallback onRefresh;
  final void Function(Itinerary) onRemove;
  final void Function(Itinerary) onMoveToPlanning;

  const SavedTab({
    super.key,
    required this.bookmarked,
    required this.onRefresh,
    required this.onRemove,
    required this.onMoveToPlanning,
  });

  @override
  Widget build(BuildContext context) {
    if (bookmarked.isEmpty) {
      return _BookmarkedEmptyState(onExplore: () => context.go('/explore'));
    }
    return ListView.builder(
      key: const PageStorageKey('saved'),
      padding: const EdgeInsets.fromLTRB(
          AppTheme.spacingLg, AppTheme.spacingMd, AppTheme.spacingLg, AppTheme.spacingXl + 80),
      itemCount: bookmarked.length,
      addRepaintBoundaries: true,
      itemBuilder: (_, i) {
        final it = bookmarked[i];
        return _SavedBookmarkedCard(
          itinerary: it,
          onTap: () =>
              context.push('/itinerary/${it.id}').then((_) => onRefresh()),
          onRemove: () => onRemove(it),
          onMoveToPlanning: () => onMoveToPlanning(it),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bookmarked card – compact editorial card with swipe-to-remove / move
// ─────────────────────────────────────────────────────────────────────────────

class _SavedBookmarkedCard extends StatelessWidget {
  static const double _cardRadius = 26.0;
  static const double _cardHeight = 140.0;

  final Itinerary itinerary;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final VoidCallback onMoveToPlanning;

  const _SavedBookmarkedCard({
    required this.itinerary,
    required this.onTap,
    required this.onRemove,
    required this.onMoveToPlanning,
  });

  String _displayTitle(Itinerary it) =>
      it.title.trim().isNotEmpty ? it.title : it.destination;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final it = itinerary;
    final displayTitle = _displayTitle(it);
    final styleTags = it.styleTags.take(2).toList();

    return Dismissible(
      key: ValueKey(it.id),
      direction: DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(_cardRadius),
        ),
        child: Icon(Icons.bookmark_remove_rounded,
            color: theme.colorScheme.onErrorContainer, size: 28),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(_cardRadius),
        ),
        child: Icon(Icons.edit_calendar_rounded,
            color: theme.colorScheme.onPrimaryContainer, size: 28),
      ),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.endToStart) {
          onRemove();
          return true;
        }
        onMoveToPlanning();
        return true;
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.spacingMd),
        child: Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(_cardRadius),
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(_cardRadius),
            child: SizedBox(
              height: _cardHeight,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(_cardRadius)),
                    child: SizedBox(
                      width: _cardHeight,
                      height: _cardHeight,
                      child: StaticMapImage(
                        itinerary: it,
                        width: _cardHeight,
                        height: _cardHeight,
                        pathColor: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            displayTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_rounded,
                                  size: 12,
                                  color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(
                                '${it.daysCount} ${AppStrings.t(context, 'days')}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 10),
                              if (it.authorPhotoUrl != null &&
                                  it.authorPhotoUrl!.isNotEmpty)
                                CircleAvatar(
                                  radius: 8,
                                  backgroundImage:
                                      NetworkImage(it.authorPhotoUrl!),
                                )
                              else
                                CircleAvatar(
                                  radius: 8,
                                  backgroundColor:
                                      theme.colorScheme.surfaceContainerHighest,
                                  child: Icon(Icons.person_rounded,
                                      size: 10,
                                      color:
                                          theme.colorScheme.onSurfaceVariant),
                                ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  it.authorName ??
                                      AppStrings.t(context, 'unknown'),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (styleTags.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 4,
                              runSpacing: 2,
                              children: styleTags.map((tag) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: theme.colorScheme.outline
                                          .withValues(alpha: 0.25),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    tag,
                                    style:
                                        theme.textTheme.labelSmall?.copyWith(
                                      fontSize: 10,
                                      color:
                                          theme.colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _BookmarkedEmptyState extends StatelessWidget {
  final VoidCallback onExplore;

  const _BookmarkedEmptyState({required this.onExplore});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bookmark_outline_rounded,
              size: 56,
              color: theme.colorScheme.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: AppTheme.spacingLg),
            Text(
              AppStrings.t(context, 'bookmarked_empty_message'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppTheme.spacingXl),
            FilledButton.icon(
              onPressed: onExplore,
              icon: const Icon(Icons.explore_rounded, size: 20),
              label: Text(AppStrings.t(context, 'explore_trips')),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
