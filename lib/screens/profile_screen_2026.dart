import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../core/analytics.dart';
import '../core/profile_cache.dart';
import '../core/profile_refresh_notifier.dart';
import '../models/profile.dart';
import '../models/itinerary.dart';
import '../models/user_city.dart';
import '../models/recommendation.dart';
import '../data/countries.dart';
import '../widgets/profile_hero_map.dart';
import '../widgets/profile_hero_card.dart';
import '../widgets/country_filter_chips.dart';
import '../widgets/profile_trip_grid_tile.dart';
import '../widgets/recommendations_tab.dart';
import '../widgets/saved_tab.dart';
import '../widgets/drafts_tab.dart';
import '../core/saved_cache.dart';
import '../core/app_link.dart';
import '../services/supabase_service.dart';
import '../l10n/app_strings.dart';
import 'expand_map_route.dart';

/// When true, use the 2026 profile layout (sliver hero, pill stats, modern trip cards).
const bool useProfile2026 = true;

List<String> _mergedVisitedCountries(Profile profile, List<Itinerary> itineraries) {
  final fromProfile = profile.visitedCountries.toSet();
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
///
/// TODO(DB): Replace with a dedicated server-side query / `is_recommended`
/// column once available.
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
          // TODO(tracking): replace with real interaction count
          inspiredCount: 0,
          imageUrl: null,
          itineraryId: it.id,
        ));
      }
    }
  }
  return recs;
}

// ─────────────────────────────────────────────────────────────────────────────
// ProfileScreen2026 – tabbed layout (Trips / Recommendations / Saved / Drafts)
// ─────────────────────────────────────────────────────────────────────────────

class ProfileScreen2026 extends StatefulWidget {
  const ProfileScreen2026({super.key});

  @override
  State<ProfileScreen2026> createState() => _ProfileScreen2026State();
}

class _ProfileScreen2026State extends State<ProfileScreen2026>
    with SingleTickerProviderStateMixin {
  // ── Profile data (unchanged) ────────────────────────────────────────────
  Profile? _profile;
  List<Itinerary> _myItineraries = [];
  List<UserPastCity> _pastCities = [];
  int _followersCount = 0;
  int _followingCount = 0;
  bool _isLoading = true;
  String? _error;
  final ScrollController _scrollController = ScrollController();
  String? _selectedCountryCode;

  // ── Saved / Drafts data ─────────────────────────────────────────────────
  List<Itinerary> _bookmarked = [];
  List<Itinerary> _planning = [];

  // ── Tabs ────────────────────────────────────────────────────────────────
  late TabController _tabController;

  // ── Friend markers placeholder ──────────────────────────────────────────
  // TODO(friends): Populate with real friend location data once available.
  // ignore: unused_field
  final List<_FriendMarker> _friendMarkers = const [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initOrLoad();
    ProfileRefreshNotifier.addListener(_onRefreshRequested);
  }

  @override
  void dispose() {
    ProfileRefreshNotifier.removeListener(_onRefreshRequested);
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onRefreshRequested() {
    if (mounted) _load(silent: true);
  }

  // ── Trip helpers (unchanged) ────────────────────────────────────────────

  List<String> _tripCountryCodes() {
    final codes = <String>{};
    for (final it in _myItineraries) {
      codes.addAll(destinationToCountryCodes(it.destination));
    }
    return codes.toList()..sort();
  }

  List<Itinerary> _filteredTrips() {
    if (_selectedCountryCode == null) return _myItineraries;
    final name = countries[_selectedCountryCode];
    if (name == null) return _myItineraries;
    return _myItineraries.where((it) {
      final dest = it.destination.toLowerCase();
      return dest.contains(name.toLowerCase());
    }).toList();
  }

  // ── Data loading (unchanged) ────────────────────────────────────────────

  void _initOrLoad() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    if (ProfileCache.hasData(userId)) {
      final cached = ProfileCache.get(userId);
      if (mounted) {
        setState(() {
          _profile = cached.profile;
          _myItineraries = cached.myItineraries;
          _pastCities = cached.pastCities;
          _followersCount = cached.followersCount;
          _followingCount = cached.followingCount;
          _isLoading = false;
          _error = null;
        });
      }
      // Restore saved/drafts from SavedCache
      if (SavedCache.hasData(userId)) {
        final savedCached = SavedCache.get(userId);
        if (mounted) {
          setState(() {
            _bookmarked = savedCached.bookmarked;
            _planning = savedCached.planning;
          });
        }
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
    if (!silent) setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        SupabaseService.getProfile(userId),
        SupabaseService.getUserItineraries(userId, publicOnly: false),
        SupabaseService.getPastCities(userId),
        SupabaseService.getFollowerCount(userId),
        SupabaseService.getFollowingCount(userId),
        SupabaseService.getBookmarkedItinerariesWithStops(userId),
        SupabaseService.getPlanningItinerariesWithStops(userId),
      ]);
      var myItineraries = results[1] as List<Itinerary>;
      if (myItineraries.isNotEmpty) {
        final ids = myItineraries.map((i) => i.id).toList();
        final likeCounts = await SupabaseService.getLikeCounts(ids);
        myItineraries = myItineraries.map((i) => i.copyWith(likeCount: likeCounts[i.id])).toList();
      }
      final profile = results[0] as Profile?;
      final pastCities = results[2] as List<UserPastCity>;
      final followersCount = results[3] as int;
      final followingCount = results[4] as int;
      final bookmarked = results[5] as List<Itinerary>;
      final planning = results[6] as List<Itinerary>;
      if (!mounted) return;
      ProfileCache.put(
        userId,
        profile: profile,
        myItineraries: myItineraries,
        pastCities: pastCities,
        followersCount: followersCount,
        followingCount: followingCount,
      );
      SavedCache.put(userId, bookmarked: bookmarked, planning: planning);
      setState(() {
        _profile = profile;
        _myItineraries = myItineraries;
        _pastCities = pastCities;
        _followersCount = followersCount;
        _followingCount = followingCount;
        _bookmarked = bookmarked;
        _planning = planning;
        _error = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (silent) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.t(context, 'could_not_refresh'))),
          );
        }
        return;
      }
      setState(() {
        _error = 'Something went wrong. Pull down to retry.';
        _isLoading = false;
      });
    }
  }

  // ── Photo upload (unchanged) ────────────────────────────────────────────

  bool _isUploadingPhoto = false;

  Future<void> _uploadPhoto() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 85);
    if (xfile == null) return;
    setState(() => _isUploadingPhoto = true);
    try {
      final bytes = await xfile.readAsBytes();
      final path = xfile.path;
      final ext = (path.contains('.') && !path.startsWith('blob:'))
          ? path.split('.').last.toLowerCase()
          : 'jpg';
      final url = await SupabaseService.uploadAvatar(userId, bytes, ext);
      await SupabaseService.updateProfile(userId, {'photo_url': url});
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.t(context, 'could_not_upload_photo'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    Analytics.logScreenView('profile');

    // Loading state
    if (_isLoading && _profile == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppTheme.spacingLg),
              Text(
                AppStrings.t(context, 'loading_profile'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Error state
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_off_outlined,
                    size: 64, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: AppTheme.spacingLg),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
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
        ),
      );
    }

    // ── Main profile layout ─────────────────────────────────────────────
    final p = _profile!;
    final userId = Supabase.instance.client.auth.currentUser?.id ?? p.id;
    final visitedCountries = _mergedVisitedCountries(p, _myItineraries);
    final currentCity = p.currentCity?.trim();
    final hasCity = currentCity != null && currentCity.isNotEmpty;
    final recommendations = _extractRecommendations(_myItineraries);

    const double heroCardOverlap = 40.0;
    final double avatarRadius = ProfileHeroCard.avatarRadius;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _load(silent: true),
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
                      isUploadingPhoto: _isUploadingPhoto,
                      showAvatar: false,
                      onMapControlTap: () {},
                      onMapTap: (Rect? sourceRect) async {
                        await Navigator.of(context, rootNavigator: true)
                            .push(ExpandMapRoute(
                          codes: visitedCountries,
                          canEdit: true,
                          sourceRect: sourceRect,
                        ));
                        if (mounted) _load();
                      },
                      onQrTap: () => context.push('/profile/qr',
                          extra: {'userId': userId, 'userName': p.name}),
                      onSettingsTap: () => context.push('/profile/settings'),
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
                          isUploadingPhoto: _isUploadingPhoto,
                          onAvatarTap: _uploadPhoto,
                          displayName: p.name?.trim().isNotEmpty == true
                              ? p.name!
                              : null,
                          currentCity: hasCity ? currentCity : null,
                          onCityTap: hasCity
                              ? () => context.push(
                                  '/city/${Uri.encodeComponent(currentCity)}?userId=$userId')
                              : () {
                                  context
                                      .push('/profile/stats?open=current_city')
                                      .then((_) {
                                    if (mounted) _load();
                                  });
                                },
                          visitedCount: visitedCountries.length,
                          inspiredCount: _followersCount,
                          followingCount: _followingCount,
                          onVisitedTap: () async {
                            await context.push(
                                '/map/countries?codes=${visitedCountries.join(',')}&editable=1');
                            if (mounted) _load();
                          },
                          onInspiredTap: () =>
                              context.push('/profile/followers'),
                          onFollowingTap: () =>
                              context.push('/profile/following'),
                          editProfileMenuItems: [
                            PopupMenuItem<String>(
                              value: 'name',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.person_outline, size: 20),
                                  const SizedBox(width: 12),
                                  Text(AppStrings.t(context, 'name')),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'travel_stats',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.location_city_outlined,
                                      size: 20),
                                  const SizedBox(width: 12),
                                  Text(AppStrings.t(context, 'travel_stats')),
                                ],
                              ),
                            ),
                          ],
                          onEditProfileSelected: (value) async {
                            if (value == 'name') {
                              await _showNameEditor(
                                  p.name ?? '',
                                  (name) => _updateProfile(name: name));
                            } else if (value == 'travel_stats') {
                              final hCity =
                                  p.currentCity?.trim().isNotEmpty == true;
                              final hasPast = _pastCities.isNotEmpty;
                              final hasStyles = p.travelStyles.isNotEmpty;
                              String? open;
                              if (!hCity) {
                                open = 'current_city';
                              } else if (!hasPast) {
                                open = 'past_cities';
                              } else if (!hasStyles) {
                                open = 'travel_styles';
                              }
                              await context.push(open != null
                                  ? '/profile/stats?open=$open'
                                  : '/profile/stats');
                            }
                            if (mounted) _load();
                          },
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
                    Tab(text: AppStrings.t(context, 'saved')),
                    Tab(text: AppStrings.t(context, 'drafts')),
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

              // ── Tab 3: Saved (bookmarks) ────────────────────────────
              SavedTab(
                bookmarked: _bookmarked,
                onRefresh: () => _load(silent: true),
                onRemove: _onRemoveBookmark,
                onMoveToPlanning: _onMoveToPlanning,
              ),

              // ── Tab 4: Drafts (planning) ────────────────────────────
              DraftsTab(
                planning: _planning,
                onRefresh: () => _load(silent: true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Trips tab (extracted from old sliver layout) ────────────────────────

  Widget _buildTripsTab(List<String> visitedCountries) {
    final filteredTrips = _filteredTrips();
    final tripCountryCodes = _tripCountryCodes();

    return CustomScrollView(
      key: const PageStorageKey('trips'),
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
                          showCreateButton: true,
                          onCreateTap: () =>
                              context.push('/create').then((_) => _load()),
                        )
                      : const SizedBox.shrink();
                }
                return ProfileTripGridTile(
                  itinerary: filteredTrips[i],
                  onRefresh: _load,
                  canEdit: true,
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

  // ── Bookmark / planning actions ──────────────────────────────────────────

  Future<void> _onRemoveBookmark(Itinerary it) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await SupabaseService.removeBookmark(userId, it.id);
      if (mounted) _load(silent: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.t(context, 'remove'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.t(context, 'move_to_planning'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.t(context, 'could_not_fork_itinerary'))),
        );
      }
    }
  }

  // ── Helpers (unchanged) ─────────────────────────────────────────────────

  Future<void> _showNameEditor(
      String initial, void Function(String) onSave) async {
    final controller = TextEditingController(text: initial);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppStrings.t(context, 'edit_name'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppTheme.spacingLg),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: AppStrings.t(context, 'name'),
                  hintText: AppStrings.t(context, 'enter_your_name'),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(AppStrings.t(context, 'cancel')),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      final name = controller.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                              content: Text(AppStrings.t(
                                  context, 'please_enter_name'))),
                        );
                      } else {
                        onSave(name);
                        Navigator.pop(ctx);
                        _load();
                      }
                    },
                    child: Text(AppStrings.t(context, 'save')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateProfile(
      {String? name, List<String>? visitedCountries}) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (visitedCountries != null) data['visited_countries'] = visitedCountries;
    await SupabaseService.updateProfile(userId, data);
    await _load();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pinned tab-bar delegate
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

// ─────────────────────────────────────────────────────────────────────────────
// Friend marker placeholder
// ─────────────────────────────────────────────────────────────────────────────

/// TODO(friends): Replace with real data model once friend location sharing
/// is implemented. These would appear as small circular avatars on the map.
class _FriendMarker {
  final String userId;
  final String? name;
  final String? photoUrl;
  final double lat;
  final double lng;

  const _FriendMarker({
    required this.userId,
    this.name,
    this.photoUrl,
    required this.lat,
    required this.lng,
  });
}
