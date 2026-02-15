import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/app_link.dart';
import '../models/itinerary.dart';
import '../l10n/app_strings.dart';
import '../services/supabase_service.dart';

/// Profile tab: user's draft / planning itineraries.
class DraftsTab extends StatelessWidget {
  final List<Itinerary> planning;
  final VoidCallback onRefresh;

  const DraftsTab({
    super.key,
    required this.planning,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (planning.isEmpty) {
      return _DraftsEmptyState(
          onCreateTrip: () => context.push('/create'));
    }
    return ListView.builder(
      key: const PageStorageKey('drafts'),
      padding: const EdgeInsets.fromLTRB(
          AppTheme.spacingLg, AppTheme.spacingMd, AppTheme.spacingLg, AppTheme.spacingXl + 80),
      itemCount: planning.length,
      addRepaintBoundaries: true,
      itemBuilder: (_, i) {
        final it = planning[i];
        return _DraftPlanningCard(
          itinerary: it,
          onTap: () =>
              context.push('/itinerary/${it.id}').then((_) => onRefresh()),
          onContinue: () => context
              .push('/itinerary/${it.id}/edit')
              .then((_) => onRefresh()),
          onRefresh: onRefresh,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

int _daysPlannedCount(Itinerary it) {
  if (it.stops.isEmpty) return 0;
  final days = it.stops.map((s) => s.day).toSet();
  return days.length;
}

String _planningStatusKey(Itinerary it) {
  final planned = _daysPlannedCount(it);
  final total = it.daysCount;
  if (planned == 0) return 'status_draft';
  if (planned >= total) return 'status_ready';
  return 'status_in_progress';
}

// ─────────────────────────────────────────────────────────────────────────────
// Draft planning card
// ─────────────────────────────────────────────────────────────────────────────

class _DraftPlanningCard extends StatelessWidget {
  static const double _cardRadius = 24;

  final Itinerary itinerary;
  final VoidCallback onTap;
  final VoidCallback onContinue;
  final VoidCallback onRefresh;

  const _DraftPlanningCard({
    required this.itinerary,
    required this.onTap,
    required this.onContinue,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final it = itinerary;
    final planned = _daysPlannedCount(it);
    final statusKey = _planningStatusKey(it);
    final isReady = statusKey == 'status_ready';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(_cardRadius),
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_cardRadius),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            it.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            it.destination,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isReady
                                  ? theme.colorScheme.primaryContainer
                                  : theme.colorScheme.tertiaryContainer
                                      .withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              AppStrings.t(context, statusKey),
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isReady
                                    ? theme.colorScheme.onPrimaryContainer
                                    : theme.colorScheme.onTertiaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_horiz_rounded,
                          color: theme.colorScheme.onSurfaceVariant),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 40, minHeight: 40),
                      position: PopupMenuPosition.over,
                      onSelected: (value) async {
                        HapticFeedback.lightImpact();
                        if (value == 'share') {
                          shareItineraryLink(it.id, title: it.title);
                        } else if (value == 'edit') {
                          context
                              .push('/itinerary/${it.id}/edit')
                              .then((_) => onRefresh());
                        } else if (value == 'delete') {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(AppStrings.t(ctx, 'delete_trip')),
                              content:
                                  Text(AppStrings.t(ctx, 'delete_trip_confirm')),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(AppStrings.t(ctx, 'cancel')),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: FilledButton.styleFrom(
                                      backgroundColor:
                                          theme.colorScheme.error),
                                  child:
                                      Text(AppStrings.t(ctx, 'delete_trip')),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true && context.mounted) {
                            try {
                              await SupabaseService.deleteItinerary(it.id);
                              if (context.mounted) onRefresh();
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(AppStrings.t(
                                          context,
                                          'could_not_load_itinerary'))),
                                );
                              }
                            }
                          }
                        }
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'share',
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.share_outlined),
                            title: Text(AppStrings.t(ctx, 'share_link')),
                          ),
                        ),
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
                            leading: Icon(Icons.delete_outline,
                                color: theme.colorScheme.error),
                            title: Text(AppStrings.t(ctx, 'delete_trip'),
                                style: TextStyle(
                                    color: theme.colorScheme.error)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '$planned of ${it.daysCount} ${AppStrings.t(context, 'days_planned')}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      onContinue();
                    },
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label:
                        Text(AppStrings.t(context, 'continue_planning')),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _DraftsEmptyState extends StatelessWidget {
  final VoidCallback onCreateTrip;

  const _DraftsEmptyState({required this.onCreateTrip});

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
              Icons.edit_calendar_rounded,
              size: 56,
              color: theme.colorScheme.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: AppTheme.spacingLg),
            Text(
              AppStrings.t(context, 'planning_empty_message'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppTheme.spacingXl),
            FilledButton.icon(
              onPressed: onCreateTrip,
              icon: const Icon(Icons.add_rounded, size: 22),
              label: Text(AppStrings.t(context, 'create_trip')),
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
