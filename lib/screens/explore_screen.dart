import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../core/analytics.dart';
import '../l10n/app_strings.dart';
import '../models/itinerary.dart';
import '../models/profile.dart';
import '../services/supabase_service.dart';
import '../services/places_service.dart';
import '../widgets/static_map_image.dart';

const double _kHeroHeight = 160.0;
const double _kHeroBottomRadius = 0.0;

/// Explore page: editorial discovery with people and trending trips.
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
      final resolved = await PlacesService.resolvePlaceWithCountry(query);
      final userId = Supabase.instance.client.auth.currentUser?.id;

      if (resolved != null) {
        final lat = resolved.$1;
        final lng = resolved.$2;
        final countryCode = resolved.$3;
        // When searching a country (e.g. "Italy"), use a tighter radius so trips only include that place (not e.g. Vienna).
        final radiusKm = (countryCode != null && countryCode.isNotEmpty) ? 500.0 : 1000.0;
        debugPrint('Location resolved: $lat, $lng for query: $query (country: $countryCode, radius: ${radiusKm}km)');
        try {
          final results = await Future.wait([
            SupabaseService.searchTripsByLocation(lat, lng, radiusKm: radiusKm, limit: 50),
            SupabaseService.searchPeopleByLocation(lat, lng, radiusKm: radiusKm, limit: 30),
            userId != null ? SupabaseService.getFollowedIds(userId) : Future.value(<String>[]),
          ]);
          final trips = results[0] as List<Itinerary>;
          final people = results[1] as List<ProfileSearchResult>;
          final followedIds = results[2] as List<String>;
          debugPrint('Location search results: ${trips.length} trips, ${people.length} profiles');
          
          // Apply filters to trips if needed
          var filteredTrips = trips;
          if (_filterDaysCount != null || _filterMode != null || _filterStyles.isNotEmpty) {
            filteredTrips = trips.where((t) {
              if (_filterDaysCount != null && t.daysCount != _filterDaysCount) return false;
              if (_filterMode != null && t.mode != _filterMode) return false;
              if (_filterStyles.isNotEmpty && !t.styleTags.any((tag) => _filterStyles.contains(tag))) return false;
              return true;
            }).toList();
          }
          
          // Get like counts for trips
          if (filteredTrips.isNotEmpty) {
            final ids = filteredTrips.map((i) => i.id).toList();
            final likeCounts = await SupabaseService.getLikeCounts(ids);
            filteredTrips = filteredTrips.map((i) => i.copyWith(likeCount: likeCounts[i.id])).toList();
          }
          
          if (!mounted) return;
          setState(() {
            _searchPeople = people;
            _searchTrips = filteredTrips;
            _isSearching = false;
          });
        } catch (e) {
          debugPrint('Location search failed, falling back to text search: $e');
          // Fall through to text search
        }
      }
      
      // Text search: search both profiles and trips by text
      if (_isSearching) {
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
      }
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
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.viewInsetsOf(context).bottom),
          ),
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
            height: 136,
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
    final cs = theme.colorScheme;
    final cardColor = theme.brightness == Brightness.light
        ? Colors.white
        : cs.surfaceContainerHighest;

    return Container(
      width: double.infinity,
      color: cs.surface,
      child: SizedBox(
        height: _kHeroHeight + topPadding,
        width: double.infinity,
        child: Stack(
          children: [
            // Title
            Positioned(
              top: topPadding + 24,
              left: AppTheme.spacingLg,
              right: AppTheme.spacingLg,
              child: Text(
                AppStrings.t(context, 'explore'),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: cs.onSurface,
                ),
              ),
            ),
            // Modern search bar
            Positioned(
              left: AppTheme.spacingLg,
              right: AppTheme.spacingLg,
              bottom: 24,
              child: Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: cs.shadow.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: searchController,
                  focusNode: searchFocusNode,
                  decoration: InputDecoration(
                    hintText: AppStrings.t(context, 'explore_search_placeholder'),
                    prefixIcon: Icon(Icons.search_rounded, size: 22, color: cs.onSurfaceVariant),
                    suffixIcon: IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.tune_rounded, size: 18, color: cs.onSurfaceVariant),
                      ),
                      onPressed: onFilterTap,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    fillColor: Colors.transparent,
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
              ),
            ),
          ],
        ),
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
    final cs = theme.colorScheme;
    final cardColor = theme.brightness == Brightness.light
        ? Colors.white
        : cs.surfaceContainerHighest;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/author/${profile.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 90,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: cs.shadow.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundImage: profile.photoUrl != null && profile.photoUrl!.isNotEmpty
                      ? NetworkImage(profile.photoUrl!)
                      : null,
                  backgroundColor: cardColor,
                  child: profile.photoUrl == null || profile.photoUrl!.isEmpty
                      ? Icon(Icons.person_rounded, color: cs.onSurfaceVariant, size: 28)
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                profile.name ?? AppStrings.t(context, 'unknown'),
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                '${profile.tripsCount} ${AppStrings.t(context, 'trips')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                  fontSize: 11,
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
                      (profile.placesSummary != null && profile.placesSummary!.trim().isNotEmpty)
                          ? profile.placesSummary!
                          : '${profile.tripsCount} ${AppStrings.t(context, 'trips')}',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
    final cs = theme.colorScheme;
    final it = itinerary;
    final displayTitle = _displayTitle(it);
    final styleTags = it.styleTags.take(2).toList();
    final cardColor = theme.brightness == Brightness.light
        ? Colors.white
        : cs.surfaceContainerHighest;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.spacingLg, 0, AppTheme.spacingLg, AppTheme.spacingMd),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(_cardRadius),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
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
                        pathColor: cs.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            displayTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: cs.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 12, color: cs.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(
                                '${it.daysCount} ${AppStrings.t(context, 'days')}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: cs.shadow.withValues(alpha: 0.08),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: it.authorPhotoUrl != null && it.authorPhotoUrl!.isNotEmpty
                                    ? CircleAvatar(
                                        radius: 8,
                                        backgroundImage: NetworkImage(it.authorPhotoUrl!),
                                      )
                                    : CircleAvatar(
                                        radius: 8,
                                        backgroundColor: cs.surfaceContainerHighest,
                                        child: Icon(Icons.person_rounded, size: 10, color: cs.onSurfaceVariant),
                                      ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  it.authorName ?? AppStrings.t(context, 'unknown'),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (styleTags.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: styleTags.map((tag) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: cs.primary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    tag,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontSize: 10,
                                      color: cs.primary,
                                      fontWeight: FontWeight.w600,
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
      ),
    );
  }

  String _displayTitle(Itinerary it) => it.title.trim().isNotEmpty ? it.title : it.destination;
}
