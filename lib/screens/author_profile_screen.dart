import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../data/countries.dart';
import '../models/itinerary.dart';
import '../models/profile.dart';
import '../models/recommendation.dart';
import '../models/user_city.dart';
import '../core/rate_limiter.dart';
import '../services/supabase_service.dart';
import '../l10n/app_strings.dart';
import '../widgets/profile_hero_map.dart';
import '../widgets/profile_hero_card.dart';
import '../widgets/country_filter_chips.dart';
import '../widgets/profile_trip_grid_tile.dart';
import '../widgets/recommendations_tab.dart';
import 'expand_map_route.dart';

List<String> _mergedVisitedCountries(Profile? profile, List<Itinerary> itineraries) {
  final fromProfile = (profile?.visitedCountries ?? []).toSet();
  for (final it in itineraries) {
    for (final code in destinationToCountryCodes(it.destination)) {
      fromProfile.add(code);
    }
  }
  return fromProfile.toList()..sort();
}

/// Extract the "city" part from a destination like "Paris, France" → "Paris".
String? _cityFromDestination(String destination) {
  final parts =
      destination.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  return parts.isNotEmpty ? parts.first : null;
}

/// Build recommendations from itinerary stops rated 5 stars.
List<Recommendation> _extractRecommendations(List<Itinerary> itineraries) {
  final recs = <Recommendation>[];
  for (final it in itineraries) {
    final countryCodes = destinationToCountryCodes(it.destination);
    final countryCode = countryCodes.isNotEmpty ? countryCodes.first : null;
    final city = _cityFromDestination(it.destination);
    for (final stop in it.stops) {
      if (stop.rating != null && stop.rating! >= 5 && stop.isVenue) {
        recs.add(Recommendation(
          stopId: stop.id,
          name: stop.name,
          category: stop.category,
          city: city,
          countryCode: countryCode,
          lat: stop.lat,
          lng: stop.lng,
          rating: 5.0,
          inspiredCount: 0,
          imageUrl: null,
          itineraryId: it.id,
        ));
      }
    }
  }
  return recs;
}

class AuthorProfileScreen extends StatefulWidget {
  final String authorId;

  const AuthorProfileScreen({super.key, required this.authorId});

  @override
  State<AuthorProfileScreen> createState() => _AuthorProfileScreenState();
}

class _AuthorProfileScreenState extends State<AuthorProfileScreen>
    with SingleTickerProviderStateMixin {
  Profile? _profile;
  List<Itinerary> _itineraries = [];
  List<UserPastCity> _pastCities = [];
  int _followersCount = 0;
  int _followingCount = 0;
  bool _isLoading = true;
  String? _error;
  bool _isFollowing = false;
  bool _isMutualFriend = false;
  final Map<String, bool> _liked = {};
  String? _selectedCountryCode;
  final ScrollController _scrollController = ScrollController();

  late TabController _tabController;

  bool get _isOwnProfile => Supabase.instance.client.auth.currentUser?.id == widget.authorId;

  List<String> _tripCountryCodes() {
    final codes = <String>{};
    for (final it in _itineraries) {
      codes.addAll(destinationToCountryCodes(it.destination));
    }
    return codes.toList()..sort();
  }

  List<Itinerary> _filteredTrips() {
    if (_selectedCountryCode == null) return _itineraries;
    final name = countries[_selectedCountryCode];
    if (name == null) return _itineraries;
    return _itineraries.where((it) {
      final dest = it.destination.toLowerCase();
      return dest.contains(name.toLowerCase());
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final isMutual = userId != null && !_isOwnProfile ? SupabaseService.isMutualFriend(userId, widget.authorId) : Future.value(false);
      final results = await Future.wait([
        SupabaseService.getProfile(widget.authorId),
        SupabaseService.getPastCities(widget.authorId),
        SupabaseService.getFollowerCount(widget.authorId),
        SupabaseService.getFollowingCount(widget.authorId),
        userId != null && !_isOwnProfile ? SupabaseService.isFollowing(userId, widget.authorId) : Future.value(false),
        isMutual,
      ]);
      final profile = results[0] as Profile?;
      final pastCities = results[1] as List<UserPastCity>;
      final followersCount = results[2] as int;
      final followingCount = results[3] as int;
      final isFollowing = results[4] as bool;
      final mutualFriend = results[5] as bool;
      var itineraries = await SupabaseService.getUserItineraries(widget.authorId, publicOnly: !_isOwnProfile && !mutualFriend);
      Map<String, bool> likedMap = {};
      if (itineraries.isNotEmpty && userId != null) {
        final ids = itineraries.map((i) => i.id).toList();
        final likeCounts = await SupabaseService.getLikeCounts(ids);
        itineraries = itineraries.map((i) => i.copyWith(likeCount: likeCounts[i.id])).toList();
        if (!_isOwnProfile) {
          final likedIds = await SupabaseService.getLikedItineraryIds(userId, ids);
          likedMap = {for (final id in ids) id: likedIds.contains(id)};
        }
      }
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _pastCities = pastCities;
        _itineraries = itineraries;
        _followersCount = followersCount;
        _followingCount = followingCount;
        _isFollowing = isFollowing;
        _isMutualFriend = mutualFriend;
        _liked.clear();
        _liked.addAll(likedMap);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || _isOwnProfile) return;
    if (!mounted) return;
    setState(() => _isFollowing = !_isFollowing);
    try {
      if (_isFollowing) {
        await SupabaseService.followUser(userId, widget.authorId);
      } else {
        await SupabaseService.unfollowUser(userId, widget.authorId);
      }
    } on RateLimitExceededException catch (_) {
      if (mounted) {
        setState(() => _isFollowing = !_isFollowing);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t(context, 'rate_limit_try_again'))));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFollowing = !_isFollowing);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t(context, 'could_not_update_follow_status'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _profile == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary)),
              const SizedBox(height: AppTheme.spacingLg),
              Text(AppStrings.t(context, 'loading_profile'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_off_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: AppTheme.spacingLg),
                Text(_error!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: AppTheme.spacingLg),
                FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh, size: 20), label: Text(AppStrings.t(context, 'retry'))),
              ],
            ),
          ),
        ),
      );
    }

    final p = _profile!;
    final currentCity = p.currentCity?.trim();
    final hasCity = currentCity != null && currentCity.isNotEmpty;
    final visitedCountries = _mergedVisitedCountries(p, _itineraries);
    final recommendations = _extractRecommendations(_itineraries);

    const double heroCardOverlap = 40.0;
    final double avatarRadius = ProfileHeroCard.avatarRadius;

    // Follow pill for the hero card
    final followPill = _isOwnProfile
        ? null
        : _FollowPill(
            isFollowing: _isFollowing,
            isMutual: _isMutualFriend,
            onTap: _toggleFollow,
          );

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: NestedScrollView(
          controller: _scrollController,
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            // ── A) Hero: Map + Hero Card ──────────────────────────────
            SliverToBoxAdapter(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Map background
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: kProfileHeroMapHeight,
                    child: ProfileHeroMap(
                      visitedCountryCodes: visitedCountries,
                      photoUrl: p.photoUrl,
                      isUploadingPhoto: false,
                      showAvatar: false,
                      onMapControlTap: () {},
                      onMapTap: (Rect? sourceRect) async {
                        await Navigator.of(context, rootNavigator: true)
                            .push(ExpandMapRoute(
                          codes: visitedCountries,
                          canEdit: false,
                          sourceRect: sourceRect,
                        ));
                        if (mounted) _load();
                      },
                      onQrTap: () => context.push('/author/${widget.authorId}/qr', extra: {'userName': p.name}),
                      leadingWidget: Material(
                        color: Colors.white.withValues(alpha: 0.28),
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, size: 24, color: Colors.white),
                          onPressed: () {
                            if (context.canPop()) context.pop();
                            else context.go('/home');
                          },
                          style: IconButton.styleFrom(minimumSize: const Size(44, 44), padding: EdgeInsets.zero),
                        ),
                      ),
                    ),
                  ),
                  // Column: spacer + hero card (establishes Stack height)
                  Column(
                    children: [
                      const SizedBox(height: kProfileHeroMapHeight - heroCardOverlap),
                      Padding(
                        padding: EdgeInsets.fromLTRB(16, avatarRadius, 16, 0),
                        child: ProfileHeroCard(
                          photoUrl: p.photoUrl,
                          isUploadingPhoto: false,
                          displayName: p.name?.trim().isNotEmpty == true
                              ? p.name!
                              : null,
                          currentCity: hasCity ? currentCity : null,
                          onCityTap: hasCity
                              ? () => context.push(
                                  '/city/${Uri.encodeComponent(currentCity)}?userId=${widget.authorId}')
                              : null,
                          visitedCount: visitedCountries.length,
                          inspiredCount: _followersCount,
                          followingCount: _followingCount,
                          onVisitedTap: () => context.push(
                              '/map/countries?codes=${visitedCountries.join(',')}'),
                          onInspiredTap: () =>
                              context.push('/profile/followers?userId=${widget.authorId}'),
                          onFollowingTap: () =>
                              context.push('/profile/following?userId=${widget.authorId}'),
                          trailingAction: followPill,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── B) Pinned TabBar ──────────────────────────────────────
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor:
                      Theme.of(context).colorScheme.onSurfaceVariant,
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  indicatorWeight: 2.5,
                  labelStyle: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                  unselectedLabelStyle:
                      Theme.of(context).textTheme.titleSmall,
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(text: AppStrings.t(context, 'trips')),
                    Tab(text: AppStrings.t(context, 'recommendations')),
                  ],
                ),
                backgroundColor:
                    Theme.of(context).scaffoldBackgroundColor,
              ),
            ),
          ],

          // ── C) Tab content ──────────────────────────────────────────
          body: TabBarView(
            controller: _tabController,
            children: [
              // ── Tab 1: Trips ────────────────────────────────────────
              _buildTripsTab(visitedCountries),

              // ── Tab 2: Recommendations ──────────────────────────────
              RecommendationsTab(recommendations: recommendations),
            ],
          ),
        ),
      ),
    );
  }

  // ── Trips tab ────────────────────────────────────────────────────────────

  Widget _buildTripsTab(List<String> visitedCountries) {
    final filteredTrips = _filteredTrips();
    final tripCountryCodes = _tripCountryCodes();

    return CustomScrollView(
      key: const PageStorageKey('author_trips'),
      slivers: [
        // Country filter chips
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppTheme.spacingLg, AppTheme.spacingLg, AppTheme.spacingLg, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CountryFilterChips(
                  countryCodes: tripCountryCodes,
                  selectedCode: _selectedCountryCode,
                  onSelected: (code) =>
                      setState(() => _selectedCountryCode = code),
                  showAllChip: true,
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        // Trip grid (2 columns) or empty state
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppTheme.spacingLg,
              AppTheme.spacingMd, AppTheme.spacingLg, AppTheme.spacingXl + 80),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 0,
              crossAxisSpacing: 0,
              childAspectRatio: 0.82,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                if (filteredTrips.isEmpty) {
                  return i == 0
                      ? ProfileTripEmptyTile(
                          showCreateButton: _isOwnProfile,
                          onCreateTap: _isOwnProfile ? () => context.push('/create').then((_) => _load()) : null,
                        )
                      : const SizedBox.shrink();
                }
                return ProfileTripGridTile(
                  itinerary: filteredTrips[i],
                  onRefresh: _load,
                  canEdit: _isOwnProfile,
                );
              },
              childCount: filteredTrips.isEmpty ? 1 : filteredTrips.length,
              addRepaintBoundaries: true,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Follow pill button (styled to match hero card)
// ─────────────────────────────────────────────────────────────────────────────

class _FollowPill extends StatelessWidget {
  final bool isFollowing;
  final bool isMutual;
  final VoidCallback onTap;

  const _FollowPill({
    required this.isFollowing,
    required this.isMutual,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: isFollowing
          ? cs.surfaceContainerHighest
          : cs.primary,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isFollowing ? Icons.person_rounded : Icons.person_add_rounded,
                size: 16,
                color: isFollowing ? cs.onSurface : cs.onPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                isFollowing
                    ? AppStrings.t(context, 'following')
                    : AppStrings.t(context, 'follow'),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: isFollowing ? cs.onSurface : cs.onPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pinned tab-bar delegate (same as profile_screen_2026)
// ─────────────────────────────────────────────────────────────────────────────

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  _SliverTabBarDelegate(this.tabBar, {required this.backgroundColor});

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: backgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar ||
      backgroundColor != oldDelegate.backgroundColor;
}
