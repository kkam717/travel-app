import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../core/analytics.dart';
import '../core/saved_cache.dart';
import '../models/itinerary.dart';
import '../l10n/app_strings.dart';
import '../services/supabase_service.dart';
import '../widgets/static_map_image.dart';

/// Saved / Planning workspace – 2026 editorial style.
/// Bookmarked: compact editorial cards with swipe actions.
/// Planning: active cards with status and "Continue planning".
class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Itinerary> _bookmarked = [];
  List<Itinerary> _planning = [];
  bool _isLoading = false;
  String? _error;
  ScaffoldMessengerState? _scaffoldMessenger;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _initOrLoad();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _initOrLoad() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    if (SavedCache.hasData(userId)) {
      final cached = SavedCache.get(userId);
      if (mounted) {
        setState(() {
          _bookmarked = cached.bookmarked;
          _planning = cached.planning;
          _isLoading = false;
          _error = null;
        });
      }
      _load(silent: true);
    } else {
      _load(silent: false);
    }
  }

  Future<void> _load({bool silent = false}) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    if (!mounted) return;
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        SupabaseService.getBookmarkedItinerariesWithStops(userId),
        SupabaseService.getPlanningItinerariesWithStops(userId),
      ]);
      if (!mounted) return;
      final bookmarked = results[0];
      final planning = results[1];
      SavedCache.put(userId, bookmarked: bookmarked, planning: planning);
      if (mounted) {
        setState(() {
          _bookmarked = bookmarked;
          _planning = planning;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (silent) {
        if (mounted && _scaffoldMessenger != null) {
          _scaffoldMessenger!.showSnackBar(
            SnackBar(content: Text(AppStrings.t(context, 'could_not_refresh'))),
          );
        }
        return;
      }
      if (mounted) {
        setState(() {
          _error = AppStrings.t(context, 'something_went_wrong');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Analytics.logScreenView('saved');
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: _isLoading && _bookmarked.isEmpty && _planning.isEmpty
            ? _buildLoading(theme)
            : _error != null
                ? _buildError(theme)
                : NestedScrollView(
                    headerSliverBuilder: (context, innerBoxIsScrolled) => [
                      SliverToBoxAdapter(child: _buildHeader(theme)),
                      SliverToBoxAdapter(child: _buildSegmentControl(theme)),
                    ],
                    body: RefreshIndicator(
                      onRefresh: () => _load(silent: true),
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _BookmarkedTab(
                            itineraries: _bookmarked,
                            onRefresh: _load,
                            onRemove: _onRemoveBookmark,
                            onMoveToPlanning: _onMoveToPlanning,
                          ),
                          _PlanningTab(
                            itineraries: _planning,
                            onRefresh: _load,
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildLoading(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppTheme.spacingLg),
          Text(
            AppStrings.t(context, 'loading'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bookmark_remove_outlined,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: AppTheme.spacingLg),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: AppTheme.spacingLg),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 20),
              label: Text(AppStrings.t(context, 'retry')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final isBookmarkedTab = _tabController.index == 0;
    final subtitle = isBookmarkedTab
        ? AppStrings.t(context, 'saved_subtitle_bookmarked')
        : AppStrings.t(context, 'saved_subtitle_planning');

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.spacingLg, AppTheme.spacingLg, AppTheme.spacingLg, AppTheme.spacingSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.t(context, 'saved'),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentControl(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.spacingLg, AppTheme.spacingSm, AppTheme.spacingLg, AppTheme.spacingMd),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(999),
        ),
        padding: const EdgeInsets.all(4),
        child: TabBar(
          controller: _tabController,
          tabAlignment: TabAlignment.fill,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          labelColor: theme.colorScheme.primary,
          labelStyle: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          unselectedLabelStyle: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          tabs: [
            Tab(text: AppStrings.t(context, 'bookmarked')),
            Tab(text: AppStrings.t(context, 'planning')),
          ],
        ),
      ),
    );
  }

  Future<void> _onRemoveBookmark(Itinerary it) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await SupabaseService.removeBookmark(userId, it.id);
      if (mounted) _load(silent: true);
      if (mounted) {
        _scaffoldMessenger?.showSnackBar(
          SnackBar(content: Text(AppStrings.t(context, 'remove'))),
        );
      }
    } catch (e) {
      if (mounted) {
        _scaffoldMessenger?.showSnackBar(
          SnackBar(content: Text(AppStrings.t(context, 'could_not_update_bookmark'))),
        );
      }
    }
  }

  Future<void> _onMoveToPlanning(Itinerary it) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final full = await SupabaseService.getItinerary(it.id);
      if (full == null || !mounted) return;
      final stopsData = full.stops
          .asMap()
          .entries
          .map((e) => <String, dynamic>{
                'name': e.value.name,
                'category': e.value.category,
                'stop_type': e.value.stopType,
                'lat': e.value.lat,
                'lng': e.value.lng,
                'external_url': e.value.externalUrl,
                'day': e.value.day,
                'position': e.key,
              })
          .toList();
      await SupabaseService.createItinerary(
        authorId: userId,
        title: '${full.title} (${AppStrings.t(context, 'copy')})',
        destination: full.destination,
        daysCount: full.daysCount,
        styleTags: full.styleTags,
        mode: full.mode ?? 'standard',
        visibility: 'private',
        forkedFromId: full.id,
        stopsData: stopsData,
        transportTransitions: full.transportTransitions,
      );
      await SupabaseService.removeBookmark(userId, full.id);
      if (mounted) _load(silent: true);
      if (mounted) {
        _scaffoldMessenger?.showSnackBar(
          SnackBar(content: Text(AppStrings.t(context, 'move_to_planning'))),
        );
      }
    } catch (e) {
      if (mounted) {
        _scaffoldMessenger?.showSnackBar(
          SnackBar(content: Text(AppStrings.t(context, 'could_not_fork_itinerary'))),
        );
      }
    }
  }
}

// --- Bookmarked tab: compact editorial cards + swipe actions ---

class _BookmarkedTab extends StatelessWidget {
  final List<Itinerary> itineraries;
  final VoidCallback onRefresh;
  final void Function(Itinerary) onRemove;
  final void Function(Itinerary) onMoveToPlanning;

  const _BookmarkedTab({
    required this.itineraries,
    required this.onRefresh,
    required this.onRemove,
    required this.onMoveToPlanning,
  });

  @override
  Widget build(BuildContext context) {
    if (itineraries.isEmpty) {
      return _BookmarkedEmptyState(onExplore: () => context.go('/explore'));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(AppTheme.spacingLg, 0, AppTheme.spacingLg, AppTheme.spacingXl + 80),
      itemCount: itineraries.length,
      addRepaintBoundaries: true,
      itemBuilder: (_, i) {
        final it = itineraries[i];
        return _SavedBookmarkedCard(
          itinerary: it,
          onTap: () => context.push('/itinerary/${it.id}').then((_) => onRefresh()),
          onRemove: () => onRemove(it),
          onMoveToPlanning: () => onMoveToPlanning(it),
        );
      },
    );
  }
}

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

  String _routeTitle(Itinerary it) {
    final locationStops = it.stops.where((s) => s.isLocation).toList();
    if (locationStops.length >= 2) {
      return locationStops.take(3).map((s) => s.name).join(' → ');
    }
    if (locationStops.length == 1) return locationStops.first.name;
    return it.destination.isNotEmpty ? it.destination : it.title;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final it = itinerary;
    final routeTitle = _routeTitle(it);
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
        child: Icon(Icons.bookmark_remove_rounded, color: theme.colorScheme.onErrorContainer, size: 28),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(_cardRadius),
        ),
        child: Icon(Icons.edit_calendar_rounded, color: theme.colorScheme.onPrimaryContainer, size: 28),
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
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(_cardRadius)),
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
                            routeTitle,
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
                              Icon(Icons.calendar_today_rounded, size: 12, color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(
                                '${it.daysCount} ${AppStrings.t(context, 'days')}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 10),
                              if (it.authorPhotoUrl != null && it.authorPhotoUrl!.isNotEmpty)
                                CircleAvatar(
                                  radius: 8,
                                  backgroundImage: NetworkImage(it.authorPhotoUrl!),
                                )
                              else
                                CircleAvatar(
                                  radius: 8,
                                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                  child: Icon(Icons.person_rounded, size: 10, color: theme.colorScheme.onSurfaceVariant),
                                ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  it.authorName ?? AppStrings.t(context, 'unknown'),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: theme.colorScheme.outline.withValues(alpha: 0.25),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    tag,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontSize: 10,
                                      color: theme.colorScheme.onSurfaceVariant,
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
              Icons.auto_awesome_rounded,
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Planning tab: active cards with status + progress ---

class _PlanningTab extends StatelessWidget {
  final List<Itinerary> itineraries;
  final VoidCallback onRefresh;

  const _PlanningTab({required this.itineraries, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (itineraries.isEmpty) {
      return _PlanningEmptyState(onCreateTrip: () => context.push('/create'));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(AppTheme.spacingLg, 0, AppTheme.spacingLg, AppTheme.spacingXl + 80),
      itemCount: itineraries.length,
      addRepaintBoundaries: true,
      itemBuilder: (_, i) {
        final it = itineraries[i];
        return _SavedPlanningCard(
          itinerary: it,
          onTap: () => context.push('/itinerary/${it.id}').then((_) => onRefresh()),
          onContinue: () => context.push('/itinerary/${it.id}/edit').then((_) => onRefresh()),
        );
      },
    );
  }
}

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

class _SavedPlanningCard extends StatelessWidget {
  static const double _cardRadius = 24;

  final Itinerary itinerary;
  final VoidCallback onTap;
  final VoidCallback onContinue;

  const _SavedPlanningCard({
    required this.itinerary,
    required this.onTap,
    required this.onContinue,
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
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isReady
                                  ? theme.colorScheme.primaryContainer
                                  : theme.colorScheme.tertiaryContainer.withValues(alpha: 0.6),
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
                    label: Text(AppStrings.t(context, 'continue_planning')),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

class _PlanningEmptyState extends StatelessWidget {
  final VoidCallback onCreateTrip;

  const _PlanningEmptyState({required this.onCreateTrip});

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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
