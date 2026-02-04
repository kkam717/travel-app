import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../core/analytics.dart';
import '../l10n/app_strings.dart';
import '../models/itinerary.dart';
import '../models/profile.dart';
import '../services/supabase_service.dart';
import '../widgets/static_map_image.dart';

const double _kHeroHeight = 300.0;
const double _kHeroBottomRadius = 28.0;

/// Explore page: editorial discovery with hero banner, people, and trending trips.
/// Replaces Search as the discovery entry point.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  List<ProfileSearchResult> _suggestedPeople = [];
  List<Itinerary> _trendingTrips = [];
  List<ProfileSearchResult> _searchPeople = [];
  List<Itinerary> _searchTrips = [];
  bool _isLoadingDiscovery = true;
  bool _isSearching = false;
  String? _error;
  int? _filterDaysCount;
  String? _filterMode;
  List<String> _filterStyles = [];

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_onSearchFocusChange);
    _searchController.addListener(_onSearchQueryChange);
    _loadDiscovery();
  }

  @override
  void dispose() {
    _searchFocusNode.removeListener(_onSearchFocusChange);
    _searchController.removeListener(_onSearchQueryChange);
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchFocusChange() {
    setState(() {});
  }

  void _onSearchQueryChange() {
    final q = _searchController.text.trim();
    if (q.isEmpty) {
      setState(() {
        _searchPeople = [];
        _searchTrips = [];
      });
      return;
    }
    _runSearch(q);
  }

  /// Only show search results when user has typed something; keep explore content when only focused.
  bool get _hasSearchQuery => _searchController.text.trim().isNotEmpty;

  Future<void> _loadDiscovery() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    setState(() {
      _isLoadingDiscovery = true;
      _error = null;
    });
    try {
      final peopleFuture = SupabaseService.searchProfiles(null, limit: 12);
      final tripsFuture = userId != null
          ? SupabaseService.getDiscoverItineraries(userId, limit: 15)
          : SupabaseService.searchItineraries(limit: 15);
      final results = await Future.wait([peopleFuture, tripsFuture]);
      var people = results[0] as List<ProfileSearchResult>;
      var trips = results[1] as List<Itinerary>;
      if (userId != null) people = people.where((p) => p.id != userId).toList();
      if (trips.isNotEmpty) {
        final ids = trips.map((i) => i.id).toList();
        final likeCounts = await SupabaseService.getLikeCounts(ids);
        trips = trips.map((i) => i.copyWith(likeCount: likeCounts[i.id])).toList();
      }
      if (!mounted) return;
      setState(() {
        _suggestedPeople = people.take(10).toList();
        _trendingTrips = trips;
        _isLoadingDiscovery = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppStrings.t(context, 'could_not_refresh');
        _isLoadingDiscovery = false;
      });
    }
  }


  Future<void> _runSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isSearching = true);
    try {
      final results = await Future.wait([
        SupabaseService.searchProfiles(query, limit: 20),
        SupabaseService.searchItineraries(
          query: query,
          limit: 20,
          daysCount: _filterDaysCount,
          mode: _filterMode,
          styles: _filterStyles.isEmpty ? null : _filterStyles,
        ),
      ]);
      final people = results[0] as List<ProfileSearchResult>;
      var trips = results[1] as List<Itinerary>;
      if (trips.isNotEmpty) {
        final ids = trips.map((i) => i.id).toList();
        final likeCounts = await SupabaseService.getLikeCounts(ids);
        trips = trips.map((i) => i.copyWith(likeCount: likeCounts[i.id])).toList();
      }
      if (!mounted) return;
      setState(() {
        _searchPeople = people;
        _searchTrips = trips;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSearching = false);
    }
  }

  void _showFilterSheet() {
    FocusScope.of(context).unfocus();
    final theme = Theme.of(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ExploreFilterSheet(
        initialDays: _filterDaysCount,
        initialMode: _filterMode,
        initialStyles: _filterStyles,
        onApply: (days, mode, styles) {
          setState(() {
            _filterDaysCount = days;
            _filterMode = mode;
            _filterStyles = styles;
          });
          if (_hasSearchQuery) _runSearch(_searchController.text.trim());
        },
        onClear: () {
          setState(() {
            _filterDaysCount = null;
            _filterMode = null;
            _filterStyles = [];
          });
          if (_hasSearchQuery) _runSearch(_searchController.text.trim());
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Analytics.logScreenView('explore');
    final theme = Theme.of(context);
    final topPadding = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
          SliverToBoxAdapter(
            child: _ExploreHero(
              topPadding: topPadding,
              searchController: _searchController,
              searchFocusNode: _searchFocusNode,
              onFilterTap: _showFilterSheet,
            ),
          ),
          if (_hasSearchQuery) ...[
            _buildSearchResults(theme),
          ] else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppTheme.spacingLg, AppTheme.spacingLg, AppTheme.spacingLg, AppTheme.spacingSm),
                child: Text(
                  AppStrings.t(context, 'explore_looking_for_inspiration'),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            if (_error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
                  child: Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
                ),
              ),
            if (_isLoadingDiscovery)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(AppTheme.spacingXl),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else ...[
              _buildPeopleSection(theme),
              _buildTrendingSection(theme),
              const SliverToBoxAdapter(
                child: SizedBox(height: AppTheme.spacingXl + 80),
              ),
            ],
          ],
        ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(ThemeData theme) {
    final q = _searchController.text.trim();
    if (q.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    if (_isSearching) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(AppTheme.spacingLg),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    final hasPeople = _searchPeople.isNotEmpty;
    final hasTrips = _searchTrips.isNotEmpty;
    if (!hasPeople && !hasTrips) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingXl),
          child: Center(
            child: Text(
              AppStrings.t(context, 'explore_no_matches'),
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(AppTheme.spacingLg, AppTheme.spacingMd, AppTheme.spacingLg, AppTheme.spacingXl),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          if (hasPeople) ...[
            _sectionHeader(theme, AppStrings.t(context, 'profiles'), null),
            const SizedBox(height: 8),
            ..._searchPeople.map((p) => _PeopleRow(profile: p)),
            const SizedBox(height: AppTheme.spacingLg),
          ],
          if (hasTrips) ...[
            _sectionHeader(theme, AppStrings.t(context, 'trips'), null),
            const SizedBox(height: 8),
            ..._searchTrips.map((t) => _ExploreTripCard(itinerary: t)),
          ],
        ]),
      ),
    );
  }

  Widget _buildPeopleSection(ThemeData theme) {
    if (_suggestedPeople.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppTheme.spacingLg, AppTheme.spacingLg, AppTheme.spacingLg, 0),
            child: _sectionHeader(theme, AppStrings.t(context, 'explore_people_you_might_like'), null),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 118,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
              itemCount: _suggestedPeople.length,
              separatorBuilder: (_, __) => const SizedBox(width: 20),
              itemBuilder: (_, i) {
                final p = _suggestedPeople[i];
                return _PeopleChip(profile: p);
              },
            ),
          ),
          const SizedBox(height: AppTheme.spacingMd),
        ],
      ),
    );
  }

  Widget _buildTrendingSection(ThemeData theme) {
    final trips = _trendingTrips;
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppTheme.spacingLg, AppTheme.spacingMd, AppTheme.spacingLg, 0),
            child: _sectionHeader(theme, AppStrings.t(context, 'explore_trending_trips'), null),
          ),
          const SizedBox(height: 12),
          if (trips.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg, vertical: AppTheme.spacingMd),
              child: Text(
                AppStrings.t(context, 'no_trips_found'),
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            )
          else
            ...trips.map((t) => _ExploreTripCard(itinerary: t)),
          const SizedBox(height: AppTheme.spacingLg),
        ],
      ),
    );
  }

  Widget _sectionHeader(ThemeData theme, String title, VoidCallback? onSeeAll) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurfaceVariant,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              AppStrings.t(context, 'explore_see_all'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}

class _ExploreHero extends StatelessWidget {
  final double topPadding;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final VoidCallback? onFilterTap;

  const _ExploreHero({
    required this.topPadding,
    required this.searchController,
    required this.searchFocusNode,
    this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: _kHeroHeight + topPadding,
      width: double.infinity,
      child: Stack(
        children: [
          // Banner image
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(_kHeroBottomRadius),
                bottomRight: Radius.circular(_kHeroBottomRadius),
              ),
              child: Image.asset(
                'assets/images/profile_banner_hero.png',
                fit: BoxFit.cover,
                alignment: const Alignment(0, 1),
              ),
            ),
          ),
          // Gradient overlay for text
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(_kHeroBottomRadius),
                  bottomRight: Radius.circular(_kHeroBottomRadius),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.4),
                    Colors.black.withValues(alpha: 0.2),
                    Colors.black.withValues(alpha: 0.15),
                  ],
                  stops: const [0.0, 0.5, 0.85],
                ),
              ),
            ),
          ),
          // Bottom fade: blend banner into page background (like profile)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(_kHeroBottomRadius),
                  bottomRight: Radius.circular(_kHeroBottomRadius),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    theme.colorScheme.surface.withValues(alpha: 0.3),
                    theme.colorScheme.surface,
                  ],
                  stops: const [0.0, 0.45, 0.75, 1.0],
                ),
              ),
            ),
          ),
          // Title and subtitle
          Positioned(
            top: topPadding + 24,
            left: AppTheme.spacingLg,
            right: AppTheme.spacingLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.t(context, 'explore'),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    shadows: [
                      Shadow(color: Colors.black.withValues(alpha: 0.5), offset: const Offset(0, 1), blurRadius: 6),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  AppStrings.t(context, 'explore_subtitle'),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w400,
                    shadows: [
                      Shadow(color: Colors.black.withValues(alpha: 0.4), offset: const Offset(0, 1), blurRadius: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Search bar at same level as profile page name (just above stat tiles)
          Positioned(
            left: AppTheme.spacingLg,
            right: AppTheme.spacingLg,
            bottom: 56,
            child: Material(
              color: theme.colorScheme.surface.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(999),
              elevation: 0,
              child: TextField(
                controller: searchController,
                focusNode: searchFocusNode,
                decoration: InputDecoration(
                  hintText: AppStrings.t(context, 'explore_search_placeholder'),
                  prefixIcon: Icon(Icons.search_rounded, size: 22, color: theme.colorScheme.onSurfaceVariant),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.tune_rounded, size: 22, color: theme.colorScheme.onSurfaceVariant),
                    onPressed: onFilterTap,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExploreFilterSheet extends StatefulWidget {
  final int? initialDays;
  final String? initialMode;
  final List<String> initialStyles;
  final void Function(int? days, String? mode, List<String> styles) onApply;
  final VoidCallback onClear;

  const _ExploreFilterSheet({
    required this.initialDays,
    required this.initialMode,
    required this.initialStyles,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_ExploreFilterSheet> createState() => _ExploreFilterSheetState();
}

class _ExploreFilterSheetState extends State<_ExploreFilterSheet> {
  late int? _days;
  late String? _mode;
  late List<String> _styles;

  @override
  void initState() {
    super.initState();
    _days = widget.initialDays;
    _mode = widget.initialMode;
    _styles = List.from(widget.initialStyles);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppTheme.spacingLg, AppTheme.spacingMd, AppTheme.spacingLg, AppTheme.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.t(context, 'filters'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppStrings.t(context, 'filter_trips_by_duration_mode'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTheme.spacingLg),
            Text(
              '${AppStrings.t(context, 'number_of_days')} (${AppStrings.t(context, 'trips')})',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FilterChip(
                  label: 'Any',
                  selected: _days == null,
                  onTap: () => setState(() => _days = null),
                ),
                ...[3, 5, 7, 10, 14].map((d) => _FilterChip(
                  label: '$d ${AppStrings.t(context, 'days')}',
                  selected: _days == d,
                  onTap: () => setState(() => _days = d),
                )),
              ],
            ),
            const SizedBox(height: AppTheme.spacingLg),
            Text(
              AppStrings.t(context, 'travel_mode'),
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FilterChip(
                  label: 'Any',
                  selected: _mode == null,
                  onTap: () => setState(() => _mode = null),
                ),
                _FilterChip(
                  label: AppStrings.t(context, 'budget'),
                  selected: _mode == 'budget',
                  onTap: () => setState(() => _mode = 'budget'),
                ),
                _FilterChip(
                  label: AppStrings.t(context, 'standard'),
                  selected: _mode == 'standard',
                  onTap: () => setState(() => _mode = 'standard'),
                ),
                _FilterChip(
                  label: AppStrings.t(context, 'luxury'),
                  selected: _mode == 'luxury',
                  onTap: () => setState(() => _mode = 'luxury'),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingXl),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () {
                    widget.onClear();
                    Navigator.pop(context);
                  },
                  child: Text(AppStrings.t(context, 'clear_filters')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      widget.onApply(_days, _mode, _styles);
                      Navigator.pop(context);
                    },
                    child: Text(AppStrings.t(context, 'apply')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: theme.colorScheme.primaryContainer,
      checkmarkColor: theme.colorScheme.onPrimaryContainer,
    );
  }
}

class _PeopleChip extends StatelessWidget {
  final ProfileSearchResult profile;

  const _PeopleChip({required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/author/${profile.id}'),
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 90,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: profile.photoUrl != null && profile.photoUrl!.isNotEmpty
                    ? NetworkImage(profile.photoUrl!)
                    : null,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                child: profile.photoUrl == null || profile.photoUrl!.isEmpty
                    ? Icon(Icons.person_rounded, color: theme.colorScheme.onSurfaceVariant, size: 28)
                    : null,
              ),
              const SizedBox(height: 8),
              Text(
                profile.name ?? AppStrings.t(context, 'unknown'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                '${profile.tripsCount} ${AppStrings.t(context, 'trips')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeopleRow extends StatelessWidget {
  final ProfileSearchResult profile;

  const _PeopleRow({required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/author/${profile.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: profile.photoUrl != null && profile.photoUrl!.isNotEmpty
                    ? NetworkImage(profile.photoUrl!)
                    : null,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                child: profile.photoUrl == null || profile.photoUrl!.isEmpty
                    ? Icon(Icons.person_rounded, color: theme.colorScheme.onSurfaceVariant)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name ?? AppStrings.t(context, 'unknown'),
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${profile.tripsCount} ${AppStrings.t(context, 'trips')}',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExploreTripCard extends StatelessWidget {
  final Itinerary itinerary;

  const _ExploreTripCard({required this.itinerary});

  static const double _cardRadius = 26.0;
  static const double _cardHeight = 140.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final it = itinerary;
    final displayTitle = _displayTitle(it);
    final styleTags = it.styleTags.take(2).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.spacingLg, 0, AppTheme.spacingLg, AppTheme.spacingMd),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(_cardRadius),
        clipBehavior: Clip.antiAlias,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        child: InkWell(
          onTap: () => context.push('/itinerary/${it.id}'),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _displayTitle(Itinerary it) => it.title.trim().isNotEmpty ? it.title : it.destination;
}
