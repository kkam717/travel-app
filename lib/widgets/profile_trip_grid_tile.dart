import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_strings.dart';
import '../models/itinerary.dart';
import '../services/supabase_service.dart';
import 'static_map_image.dart';

/// Compact trip card for 2-column profile grid: image, gradient scrim, title, like count.
class ProfileTripGridTile extends StatelessWidget {
  final Itinerary itinerary;
  final VoidCallback? onRefresh;
  final bool canEdit;

  const ProfileTripGridTile({
    super.key,
    required this.itinerary,
    this.onRefresh,
    this.canEdit = false,
  });

  String _displayTitle(Itinerary it) => it.title.trim().isNotEmpty ? it.title : it.destination;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final it = itinerary;
    final displayTitle = _displayTitle(it);
    final likeCount = it.likeCount ?? 0;

    const double radius = 20;
    const double pad = 8;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: pad, vertical: pad),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(radius),
          clipBehavior: Clip.antiAlias,
          elevation: 0,
          child: InkWell(
            onTap: () async {
              await context.push('/itinerary/${it.id}');
              onRefresh?.call();
            },
            borderRadius: BorderRadius.circular(radius),
            child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = w * 1.15;
              return SizedBox(
                width: w,
                height: h,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fill(
                      child: StaticMapImage(
                        itinerary: it,
                        width: w,
                        height: h,
                        pathColor: theme.colorScheme.primary,
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: h * 0.65,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.6),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            displayTitle,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.favorite_rounded,
                                size: 14,
                                color: Colors.white.withValues(alpha: 0.95),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$likeCount',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (canEdit)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: PopupMenuButton<String>(
                          icon: Icon(Icons.more_horiz_rounded, size: 20, color: Colors.white.withValues(alpha: 0.9)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          position: PopupMenuPosition.over,
                          color: theme.colorScheme.surface,
                          onSelected: (value) async {
                            if (value == 'edit') {
                              context.push('/itinerary/${it.id}/edit').then((_) => onRefresh?.call());
                            } else if (value == 'delete') {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(AppStrings.t(ctx, 'delete_trip')),
                                  content: Text(AppStrings.t(ctx, 'delete_trip_confirm')),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: Text(AppStrings.t(ctx, 'cancel')),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
                                      child: Text(AppStrings.t(ctx, 'delete_trip')),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true && context.mounted) {
                                try {
                                  await SupabaseService.deleteItinerary(it.id);
                                  onRefresh?.call();
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(AppStrings.t(context, 'could_not_load_itinerary'))),
                                    );
                                  }
                                }
                              }
                            }
                          },
                          itemBuilder: (ctx) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.edit_outlined),
                                title: Text(AppStrings.t(ctx, 'edit_trip')),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                                title: Text(AppStrings.t(ctx, 'delete_trip'), style: TextStyle(color: theme.colorScheme.error)),
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
        ),
      ),
    ),
    );
  }
}

/// Empty state as a grid tile: "No trips yet" + optional "Create trip" button. Same card dimensions as [ProfileTripGridTile].
/// Set [showCreateButton] to false when showing another user's profile (no add-trip button).
class ProfileTripEmptyTile extends StatelessWidget {
  final VoidCallback? onCreateTap;
  /// When false, only the empty message is shown (e.g. on another user's profile). Default true.
  final bool showCreateButton;

  const ProfileTripEmptyTile({
    super.key,
    this.onCreateTap,
    this.showCreateButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const double radius = 20;
    const double pad = 8;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: pad, vertical: pad),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(radius),
          child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = w * 1.15;
            return SizedBox(
              width: w,
              height: h,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      AppStrings.t(context, 'no_trips_yet'),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      showCreateButton
                          ? AppStrings.t(context, 'create_first_trip_to_start')
                          : AppStrings.t(context, 'no_trips_yet_other'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                    const Spacer(),
                    if (showCreateButton && onCreateTap != null)
                      SizedBox(
                        width: double.infinity,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.shadow.withValues(alpha: 0.06),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            borderRadius: BorderRadius.circular(20),
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
                            child: InkWell(
                              onTap: onCreateTap,
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add, size: 20, color: theme.colorScheme.onSurface),
                                      const SizedBox(width: 8),
                                      Text(
                                        AppStrings.t(context, 'create_trip'),
                                        style: theme.textTheme.labelLarge?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
    );
  }
}
