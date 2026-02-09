import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../core/theme.dart';
import '../core/analytics.dart';
import '../core/app_link.dart';
import '../core/home_cache.dart';
import '../models/itinerary.dart';
import '../models/profile.dart';
import '../models/user_city.dart';
import '../services/supabase_service.dart';
import '../core/locale_notifier.dart';
import '../l10n/app_strings.dart';
import '../services/translation_service.dart' show translate, isContentInDifferentLanguage;
import '../widgets/static_map_image.dart';
import '../widgets/itinerary_feed_card_2026.dart';
import '../widgets/itinerary_feed_item_modern.dart';

/// When true, use the editorial modern feed item (no card, edge-to-edge hero, no visible actions).
const bool useFeedItemModern = true;

/// When false and useFeedItemModern is false, use the 2026-style feed card.
const bool useFeedCard2026 = !useFeedItemModern;

const int _pageSize = 20;
const int _discoverLimit = 5;

/// Scroll distance over which header animates from expanded to collapsed (pixels).
const double _kHeaderScrollRange = 100;
const double _kHeaderExpandedHeight = 104;
const double _kHeaderCollapsedHeight = 56;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  List<Itinerary> _feed = [];
  List<Itinerary> _discover = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  final Map<String, bool> _bookmarked = {};
  final Map<String, bool> _liked = {};
  /// Author ID -> list of city names from profile (current city + past cities). Used for "From someone who lived here".
  final Map<String, List<String>> _authorLivedInCities = {};
  /// Author ID -> all top spots (bars/restaurants etc) for that user, by city. Used for lived-here recommendations.
  final Map<String, List<UserTopSpot>> _authorTopSpots = {};
  /// Current user's following IDs (friends). Used to prioritise friend recommendations.
  Set<String> _followingAuthorIds = {};
  /// FYP: itinerary id -> number of times the user has seen this post (persisted). Updated when viewing.
  Map<String, int> _fypViewCounts = {};
  /// FYP: snapshot used only for sorting; updated only on pull-to-refresh so order doesn't change while scrolling.
  Map<String, int> _fypViewCountsForSorting = {};
  /// FYP: ids we've already counted as "viewed" in this visibility session (reset when off-screen).
  final Set<String> _fypViewedThisSession = {};
  late TabController _tabController;
  int _newTripsCount = 0;

  static const String _fypViewCountsKeyPrefix = 'fyp_views_';
  /// Each view makes a post count as 1 day "older" for sorting, so less-seen posts rise on refresh.
  static const int _fypViewPenaltyMs = 24 * 60 * 60 * 1000;

  /// 0 = expanded, 1 = collapsed. Driven by scroll offset.
  double _headerCollapseT = 0;
  final ScrollController _scrollForYou = ScrollController();
  final ScrollController _scrollFollowing = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);
    _tabController.addListener(_onTabChange);
    _scrollForYou.addListener(_onScroll);
    _scrollFollowing.addListener(_onScroll);
    _initOrLoad();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChange);
    _scrollForYou.removeListener(_onScroll);
    _scrollFollowing.removeListener(_onScroll);
    _scrollForYou.dispose();
    _scrollFollowing.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChange() {
    _syncHeaderFromActiveScroll();
  }

  void _syncHeaderFromActiveScroll() {
    if (!mounted) return;
    final offset = _tabController.index == 0
        ? _scrollForYou.hasClients ? _scrollForYou.offset : 0
        : _scrollFollowing.hasClients ? _scrollFollowing.offset : 0;
    final t = (offset / _kHeaderScrollRange).clamp(0.0, 1.0);
    if ((t - _headerCollapseT).abs() > 0.001) {
      setState(() => _headerCollapseT = t);
    }
  }

  void _onScroll() {
    if (_isLoadingMore || !_hasMore || _feed.isEmpty) {} else {
      final c = _tabController.index == 0 ? _scrollForYou : _scrollFollowing;
      if (c.hasClients && c.position.pixels >= c.position.maxScrollExtent - 400) {
        _loadMore();
      }
    }
    final offset = _tabController.index == 0 ? _scrollForYou.offset : _scrollFollowing.offset;
    final t = (offset / _kHeaderScrollRange).clamp(0.0, 1.0);
    if ((t - _headerCollapseT).abs() > 0.001 && mounted) {
      setState(() => _headerCollapseT = t);
    }
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (_isLoadingMore || !_hasMore || _feed.isEmpty) return false;
    if (notification is! ScrollUpdateNotification && notification is! ScrollEndNotification) return false;
    final m = notification.metrics;
    if (m.pixels >= m.maxScrollExtent - 400) _loadMore();
    return false;
  }

  void _initOrLoad() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final cached = HomeCache.get(userId);
    if (HomeCache.hasData(userId)) {
      if (mounted) {
        setState(() {
          _feed = cached.feed;
          _bookmarked.clear();
          _bookmarked.addAll(cached.bookmarked);
          _liked.clear();
          _liked.addAll(cached.liked);
          _isLoading = false;
          _error = null;
        });
      }
      _loadFypViewCounts();
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
      final profile = SupabaseService.getProfile(userId);
      final feed = SupabaseService.getFeedItineraries(userId, limit: _pageSize);
      final myItineraries = SupabaseService.getUserItineraries(userId, publicOnly: false);
      final discover = SupabaseService.getDiscoverItineraries(userId, limit: _discoverLimit);
      final results = await Future.wait([profile, feed, myItineraries, discover]);
      if (!mounted) return;
      final profileResult = results[0] as Profile?;
      final feedList = results[1] as List<Itinerary>;
      final myItinerariesList = results[2] as List<Itinerary>;
      final discoverList = results[3] as List<Itinerary>;
      final allIds = [...feedList.map((i) => i.id), ...discoverList.map((i) => i.id)];
      final bookmarkedIds = allIds.isEmpty ? <String>{} : await SupabaseService.getBookmarkedItineraryIds(userId, allIds);
      final likedIds = allIds.isEmpty ? <String>{} : await SupabaseService.getLikedItineraryIds(userId, allIds);
      if (!mounted) return;
      final bookmarkedMap = {for (final it in [...feedList, ...discoverList]) it.id: bookmarkedIds.contains(it.id)};
      final likedMap = {for (final it in [...feedList, ...discoverList]) it.id: likedIds.contains(it.id)};
      HomeCache.put(
        userId,
        profile: profileResult,
        myItineraries: myItinerariesList,
        feed: feedList,
        bookmarked: bookmarkedMap,
        liked: likedMap,
      );
      setState(() {
        _feed = feedList;
        _discover = discoverList;
        _bookmarked.clear();
        _bookmarked.addAll(bookmarkedMap);
        _liked.clear();
        _liked.addAll(likedMap);
        _isLoading = false;
        _hasMore = feedList.length >= _pageSize;
        // Update FYP sort snapshot only on refresh so order doesn't change while scrolling.
        _fypViewCountsForSorting = Map.from(_fypViewCounts);
      });
      _ensureAuthorLivedInCities();
      _ensureFollowingIds();
      _loadFypViewCounts();
      Analytics.logScreenView('home');
    } catch (e) {
      if (!mounted) return;
      if (silent) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t(context, 'could_not_refresh'))));
        return;
      }
      setState(() {
        _error = 'Something went wrong. Pull down to retry.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _feed.isEmpty) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final last = _feed.last;
    final cursor = last.createdAt?.toIso8601String();
    if (cursor == null) return;
    _isLoadingMore = true;
    if (mounted) setState(() {});
    try {
      final more = await SupabaseService.getFeedItineraries(userId, limit: _pageSize, afterCreatedAt: cursor);
      if (!mounted) return;
      final bookmarkedIds = more.isEmpty ? <String>{} : await SupabaseService.getBookmarkedItineraryIds(userId, more.map((i) => i.id).toList());
      if (!mounted) return;
      final bookmarkedMap = {for (final it in more) it.id: bookmarkedIds.contains(it.id)};
      if (mounted) {
        setState(() {
          _feed = [..._feed, ...more];
          _bookmarked.addAll(bookmarkedMap);
          _isLoadingMore = false;
          _hasMore = more.length >= _pageSize;
        });
        _ensureAuthorLivedInCities();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  /// Fetches profile + past cities + top spots for feed authors not yet loaded; updates state.
  Future<void> _ensureAuthorLivedInCities() async {
    final ids = _feed.map((i) => i.authorId).toSet().where((id) => !_authorLivedInCities.containsKey(id)).toList();
    if (ids.isEmpty) return;
    final cityUpdates = <String, List<String>>{};
    final spotUpdates = <String, List<UserTopSpot>>{};
    for (final authorId in ids) {
      try {
        final profile = await SupabaseService.getProfile(authorId);
        final pastCities = await SupabaseService.getPastCities(authorId);
        final cities = <String>[];
        final current = profile?.currentCity?.trim();
        if (current != null && current.isNotEmpty) cities.add(current);
        for (final c in pastCities) {
          final name = c.cityName.trim();
          if (name.isNotEmpty && !cities.contains(name)) cities.add(name);
        }
        cityUpdates[authorId] = cities;
        final spots = await SupabaseService.getTopSpotsForUser(authorId);
        spotUpdates[authorId] = spots;
      } catch (_) {
        cityUpdates[authorId] = [];
        spotUpdates[authorId] = [];
      }
    }
    if (!mounted || (cityUpdates.isEmpty && spotUpdates.isEmpty)) return;
    setState(() {
      for (final e in cityUpdates.entries) {
        _authorLivedInCities[e.key] = e.value;
      }
      for (final e in spotUpdates.entries) {
        _authorTopSpots[e.key] = e.value;
      }
    });
  }

  /// Load current user's following IDs so we can show friend badge and prioritise friend recommendations.
  Future<void> _ensureFollowingIds() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final ids = await SupabaseService.getFollowedIds(userId);
      if (!mounted) return;
      setState(() => _followingAuthorIds = ids.toSet());
    } catch (_) {}
  }

  /// Destination string (e.g. "Rome, Italy") -> first part normalized for matching.
  static String _destinationCityNormalized(String destination) {
    final t = destination.trim();
    if (t.isEmpty) return '';
    final comma = t.indexOf(',');
    final city = comma >= 0 ? t.substring(0, comma).trim() : t;
    return city.toLowerCase();
  }

  /// Returns lived city name from author's list that matches this itinerary's destination, or null.
  String? _matchLivedCityToDestination(String destination, List<String> livedCities) {
    final destNorm = _HomeScreenState._destinationCityNormalized(destination);
    if (destNorm.isEmpty) return null;
    for (final city in livedCities) {
      final c = city.trim();
      if (c.isEmpty) continue;
      if (c.toLowerCase() == destNorm) return city;
      if (destNorm.contains(c.toLowerCase())) return city;
      if (c.toLowerCase().contains(destNorm)) return city;
    }
    return null;
  }

  /// Spot-level recommendations from this itinerary's author for the itinerary's destination (lived/current city that matches). Empty if no match or no spots.
  List<UserTopSpot>? _authorLivedHereSpotsFor(Itinerary it) {
    final cities = _authorLivedInCities[it.authorId];
    if (cities == null || cities.isEmpty) return null;
    final matchedCity = _matchLivedCityToDestination(it.destination, cities);
    if (matchedCity == null) return null;
    final spots = _authorTopSpots[it.authorId];
    if (spots == null || spots.isEmpty) return null;
    final forCity = spots.where((s) => s.cityName.trim().toLowerCase() == matchedCity.trim().toLowerCase()).toList();
    return forCity.isEmpty ? null : forCity;
  }

  Future<void> _onRefresh() async {
    final beforeCount = _feed.length;
    await _load(silent: true);
    if (!mounted) return;
    final newCount = _feed.length;
    _newTripsCount = newCount > beforeCount ? newCount - beforeCount : 0;
    if (_newTripsCount > 0 && mounted) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_newTripsCount == 1 ? AppStrings.t(context, 'one_new_trip') : '$_newTripsCount ${AppStrings.t(context, 'new_trips')}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _toggleBookmark(String itineraryId) async {
    HapticFeedback.lightImpact();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final wasBookmarked = _bookmarked[itineraryId] ?? false;
    if (!mounted) return;
    setState(() => _bookmarked[itineraryId] = !wasBookmarked);
    try {
      if (wasBookmarked) {
        await SupabaseService.removeBookmark(userId, itineraryId);
      } else {
        await SupabaseService.addBookmark(userId, itineraryId);
      }
    } catch (e) {
      if (mounted) setState(() => _bookmarked[itineraryId] = wasBookmarked);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t(context, 'could_not_update_bookmark'))));
    }
  }

  Future<void> _toggleLike(String itineraryId) async {
    HapticFeedback.lightImpact();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final wasLiked = _liked[itineraryId] ?? false;
    if (!mounted) return;
    setState(() {
      _liked[itineraryId] = !wasLiked;
      final delta = wasLiked ? -1 : 1;
      void updateCount(List<Itinerary> list) {
        final idx = list.indexWhere((i) => i.id == itineraryId);
        if (idx >= 0) {
          final it = list[idx];
          list[idx] = it.copyWith(likeCount: (it.likeCount ?? 0) + delta);
        }
      }
      updateCount(_feed);
      updateCount(_discover);
    });
    try {
      if (wasLiked) {
        await SupabaseService.removeLike(userId, itineraryId);
      } else {
        await SupabaseService.addLike(userId, itineraryId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _liked[itineraryId] = wasLiked;
          final delta = wasLiked ? 1 : -1;
          void updateCount(List<Itinerary> list) {
            final idx = list.indexWhere((i) => i.id == itineraryId);
            if (idx >= 0) {
              final it = list[idx];
              list[idx] = it.copyWith(likeCount: (it.likeCount ?? 0) + delta);
            }
          }
          updateCount(_feed);
          updateCount(_discover);
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t(context, 'could_not_refresh'))));
      }
    }
  }

  void _onReturnFromItinerary(String itineraryId, dynamic result) {
    if (!mounted) return;
    if (result is! Map) return;
    final liked = result['liked'] as bool?;
    final likeCount = result['likeCount'] as int?;
    final bookmarked = result['bookmarked'] as bool?;
    if (liked == null && likeCount == null && bookmarked == null) return;
    setState(() {
      if (liked != null) _liked[itineraryId] = liked;
      if (likeCount != null) {
        void updateIn(List<Itinerary> list) {
          final idx = list.indexWhere((i) => i.id == itineraryId);
          if (idx >= 0) list[idx] = list[idx].copyWith(likeCount: likeCount);
        }
        updateIn(_feed);
        updateIn(_discover);
      }
      if (bookmarked != null) _bookmarked[itineraryId] = bookmarked;
    });
  }

  String _descriptionFor(Itinerary it) {
    if (it.styleTags.isNotEmpty) {
      return '${it.destination} • ${it.styleTags.take(2).join(', ').toLowerCase()}';
    }
    return it.destination;
  }

  String _locationsFor(Itinerary it) {
    if (it.stops.isEmpty) return it.destination;
    final venues = it.stops.where((s) => s.isVenue).toList();
    final toShow = venues.isNotEmpty ? venues : it.stops.where((s) => s.isLocation).toList();
    if (toShow.isEmpty) return it.destination;
    return toShow.take(2).map((s) => s.name).join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? _buildSkeletonLoading()
            : _error != null
                ? _buildErrorState()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DiscoverHeader(collapseT: _headerCollapseT),
                      Material(
                        color: Theme.of(context).colorScheme.surface,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TabBar(
                              controller: _tabController,
                              labelStyle: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                              unselectedLabelStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              indicatorSize: TabBarIndicatorSize.label,
                              indicator: UnderlineTabIndicator(
                                borderSide: BorderSide(
                                  width: 2,
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.85),
                                ),
                              ),
                              labelPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              tabs: [
                                Tab(text: AppStrings.t(context, 'for_you')),
                                Tab(text: AppStrings.t(context, 'following')),
                              ],
                            ),
                            Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.25)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildForYouTab(context),
                            _buildFollowingTab(context),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildFollowingTab(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: CustomScrollView(
          controller: _scrollFollowing,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(height: useFeedItemModern ? AppTheme.spacingLg : AppTheme.spacingMd),
            ),
          if (_feed.isEmpty)
            SliverFillRemaining(child: _buildEmptyState())
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  if (i == _feed.length) {
                    return _buildLoadMoreOrEnd();
                  }
                  final it = _feed[i];
                  final userId = Supabase.instance.client.auth.currentUser?.id;
                  final isOthersPost = userId != null && it.authorId != userId;
                  return RepaintBoundary(
                    child: _SwipeableFeedCard(
                    itinerary: it,
                    description: _descriptionFor(it),
                    locations: _locationsFor(it),
                    isBookmarked: _bookmarked[it.id] ?? false,
                    onBookmark: () => _toggleBookmark(it.id),
                    isLiked: _liked[it.id] ?? false,
                    likeCount: it.likeCount ?? 0,
                    onLike: isOthersPost ? () => _toggleLike(it.id) : null,
                    onTap: () => context.push('/itinerary/${it.id}').then((result) => _onReturnFromItinerary(it.id, result)),
                    onAuthorTap: () => context.push('/author/${it.authorId}'),
                    variant: _CardVariant.standard,
                    index: i,
                    authorLivedHereSpots: _authorLivedHereSpotsFor(it),
                    isAuthorFriend: _followingAuthorIds.contains(it.authorId),
                  ),
                  );
                },
                childCount: _feed.length + 1,
                addRepaintBoundaries: true,
              ),
            ),
          SliverToBoxAdapter(child: _buildPeekPadding()),
          ],
        ),
      ),
    );
  }

  List<Itinerary> get _forYouItems {
    final seen = <String>{};
    final merged = <Itinerary>[..._feed, ..._discover];
    final list = merged.where((i) => seen.add(i.id)).toList();
    list.sort((a, b) {
      final aMs = (a.createdAt ?? DateTime(0)).millisecondsSinceEpoch;
      final bMs = (b.createdAt ?? DateTime(0)).millisecondsSinceEpoch;
      final aViews = _fypViewCountsForSorting[a.id] ?? 0;
      final bViews = _fypViewCountsForSorting[b.id] ?? 0;
      final aScore = aMs - aViews * _fypViewPenaltyMs;
      final bScore = bMs - bViews * _fypViewPenaltyMs;
      return bScore.compareTo(aScore);
    });
    return list;
  }

  Future<void> _loadFypViewCounts() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_fypViewCountsKeyPrefix$userId');
      if (raw == null && !mounted) return;
      final Map<String, dynamic> decoded = raw != null
          ? (jsonDecode(raw) as Map<String, dynamic>? ?? {})
          : {};
      final counts = decoded.map((k, v) => MapEntry(k as String, (v as num).toInt()));
      if (!mounted) return;
      setState(() {
        _fypViewCounts = counts;
        _fypViewCountsForSorting = Map.from(counts);
      });
    } catch (_) {}
  }

  /// Records a view for FYP sorting. Updates in memory and persists; does not rebuild so order only changes on user refresh.
  Future<void> _recordFypView(String itineraryId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    _fypViewCounts[itineraryId] = (_fypViewCounts[itineraryId] ?? 0) + 1;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_fypViewCountsKeyPrefix$userId', jsonEncode(_fypViewCounts));
    } catch (_) {}
  }

  Widget _buildForYouTab(BuildContext context) {
    final items = _forYouItems;
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: items.isEmpty
          ? CustomScrollView(
              controller: _scrollForYou,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacingMd)),
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingXl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.explore_rounded, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                          const SizedBox(height: AppTheme.spacingLg),
                          Text(
                            AppStrings.t(context, 'no_recommendations_yet'),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppTheme.spacingSm),
                          Text(
                            AppStrings.t(context, 'check_back_later_trips'),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          : NotificationListener<ScrollNotification>(
              onNotification: _onScrollNotification,
              child: CustomScrollView(
                controller: _scrollForYou,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(height: useFeedItemModern ? AppTheme.spacingLg : AppTheme.spacingMd),
                  ),
                  SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      if (i == items.length) {
                        return _buildLoadMoreOrEnd(displayCount: items.length);
                      }
                      final it = items[i];
                      final userId = Supabase.instance.client.auth.currentUser?.id;
                      final isOthersPost = userId != null && it.authorId != userId;
                      final card = RepaintBoundary(
                        child: _SwipeableFeedCard(
                          itinerary: it,
                          description: _descriptionFor(it),
                          locations: _locationsFor(it),
                          isBookmarked: _bookmarked[it.id] ?? false,
                          onBookmark: () => _toggleBookmark(it.id),
                          isLiked: _liked[it.id] ?? false,
                          likeCount: it.likeCount ?? 0,
                          onLike: isOthersPost ? () => _toggleLike(it.id) : null,
                          onTap: () => context.push('/itinerary/${it.id}').then((result) => _onReturnFromItinerary(it.id, result)),
                          onAuthorTap: () => context.push('/author/${it.authorId}'),
                          variant: _CardVariant.standard,
                          index: i,
                          authorLivedHereSpots: _authorLivedHereSpotsFor(it),
                          isAuthorFriend: _followingAuthorIds.contains(it.authorId),
                        ),
                      );
                      return VisibilityDetector(
                        key: Key('fyp_vis_${it.id}'),
                        onVisibilityChanged: (info) {
                          if (info.visibleFraction >= 0.5) {
                            if (!_fypViewedThisSession.contains(it.id)) {
                              _fypViewedThisSession.add(it.id);
                              _recordFypView(it.id);
                            }
                          } else if (info.visibleFraction < 0.2) {
                            _fypViewedThisSession.remove(it.id);
                          }
                        },
                        child: card,
                      );
                    },
                    childCount: items.length + 1,
                    addRepaintBoundaries: true,
                  ),
                ),
              ],
            ),
            ),
    );
  }

  Widget _buildSkeletonLoading() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader()),
        SliverToBoxAdapter(child: _buildModernTabs(context)),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => _SkeletonCard(variant: _CardVariant.values[i % 3]),
            childCount: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadMoreOrEnd({int? displayCount}) {
    final count = displayCount ?? _feed.length;
    if (_isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(AppTheme.spacingLg),
        child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (_hasMore && _feed.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Center(
          child: Text(
            '$count ${AppStrings.t(context, 'trips_so_far_keep_scrolling')}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }
    return const SizedBox(height: AppTheme.spacingMd);
  }

  Widget _buildPeekPadding() {
    return Container(
      height: 24,
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      alignment: Alignment.center,
      child: _feed.isNotEmpty && _hasMore
          ? Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5))
          : null,
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.spacingLg, AppTheme.spacingXl, AppTheme.spacingLg, AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.t(context, 'discover'),
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppStrings.t(context, 'trips_from_people_with_taste'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTabs(BuildContext context) {
    final theme = Theme.of(context);
    return TabBar(
      controller: _tabController,
      labelStyle: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      unselectedLabelStyle: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w500,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      indicatorSize: TabBarIndicatorSize.label,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(
          width: 2,
          color: theme.colorScheme.primary.withValues(alpha: 0.85),
        ),
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      tabs: [
        Tab(text: AppStrings.t(context, 'for_you')),
        Tab(text: AppStrings.t(context, 'following')),
      ],
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.explore_rounded, size: 56, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: AppTheme.spacingLg),
              Text(
                AppStrings.t(context, 'no_trips_in_feed'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacingSm),
              Text(
                AppStrings.t(context, 'follow_or_create_first_trip'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacingXl),
              FilledButton.icon(
                onPressed: () => context.go('/explore'),
                icon: const Icon(Icons.search_rounded, size: 20),
                label: Text(AppStrings.t(context, 'discover_trips')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: AppTheme.spacingLg),
            Text(_error!, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
            const SizedBox(height: AppTheme.spacingLg),
            FilledButton(onPressed: () => _load(silent: false), child: Text(AppStrings.t(context, 'retry'))),
          ],
        ),
      ),
    );
  }
}

/// Scroll-driven header: animates with scroll via collapseT in [0, 1].
class _DiscoverHeader extends StatelessWidget {
  final double collapseT;

  const _DiscoverHeader({required this.collapseT});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;
    final t = collapseT.clamp(0.0, 1.0);

    final height = _kHeaderExpandedHeight + t * (_kHeaderCollapsedHeight - _kHeaderExpandedHeight);
    final titleSize = 32.0 - t * 12.0;
    final subtitleOpacity = (1.0 - t).clamp(0.0, 1.0);

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(color: surface),
      clipBehavior: Clip.hardEdge,
      alignment: Alignment.bottomLeft,
      padding: EdgeInsets.only(
        left: AppTheme.spacingLg,
        right: AppTheme.spacingLg,
        bottom: 8 + t * 4,
        top: 12 * (1 - t),
      ),
      child: FittedBox(
        alignment: Alignment.bottomLeft,
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.t(context, 'discover'),
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                fontSize: titleSize,
                color: onSurface,
              ),
            ),
            if (subtitleOpacity > 0.01) ...[
              SizedBox(height: 6 * (1 - t)),
              Opacity(
                opacity: subtitleOpacity,
                child: Text(
                  AppStrings.t(context, 'trips_from_people_with_taste'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: onSurfaceVariant,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _CardVariant { standard, tall, compact }

class _SwipeableFeedCard extends StatelessWidget {
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
  final _CardVariant variant;
  final int index;
  /// Spot-level recommendations (bars/restaurants etc) from author's lived city matching this itinerary's destination. Section hidden when null or empty.
  final List<UserTopSpot>? authorLivedHereSpots;
  final bool isAuthorFriend;

  const _SwipeableFeedCard({
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
    required this.variant,
    required this.index,
    this.authorLivedHereSpots,
    this.isAuthorFriend = false,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 80).clamp(0, 400)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: useFeedItemModern
          ? Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spacingXl),
              child: ItineraryFeedItemModern(
                itinerary: itinerary,
                description: description,
                locations: locations,
                isBookmarked: isBookmarked,
                onBookmark: onBookmark,
                isLiked: isLiked,
                likeCount: likeCount,
                onLike: onLike,
                onTap: onTap,
                onAuthorTap: onAuthorTap,
                authorLivedHereSpots: authorLivedHereSpots,
                isAuthorFriend: isAuthorFriend,
              ),
            )
          : _EdgeAwareSwipeCard(
              edgeZonePx: 24,
              child: Dismissible(
                key: Key('swipe-${itinerary.id}'),
                direction: DismissDirection.horizontal,
                background: Container(
                  margin: const EdgeInsets.fromLTRB(AppTheme.spacingLg, 0, AppTheme.spacingLg, AppTheme.spacingMd),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: AppTheme.spacingLg),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    isBookmarked ? Icons.bookmark_remove_rounded : Icons.bookmark_add_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 32,
                  ),
                ),
                confirmDismiss: (direction) async {
                  HapticFeedback.mediumImpact();
                  onBookmark();
                  return false;
                },
                child:                     useFeedCard2026
                    ? ItineraryFeedCard2026(
                        itinerary: itinerary,
                        description: description,
                        locations: locations,
                        isBookmarked: isBookmarked,
                        onBookmark: onBookmark,
                        isLiked: isLiked,
                        likeCount: likeCount,
                        onLike: onLike,
                        onTap: onTap,
                        onAuthorTap: onAuthorTap,
                        authorLivedHereSpots: authorLivedHereSpots,
                        isAuthorFriend: isAuthorFriend,
                      )
                    : _FeedCard(
                        itinerary: itinerary,
                        description: description,
                        locations: locations,
                        isBookmarked: isBookmarked,
                        onBookmark: onBookmark,
                        isLiked: isLiked,
                        likeCount: likeCount,
                        onLike: onLike,
                        onTap: onTap,
                        onAuthorTap: onAuthorTap,
                        variant: variant,
                        index: index,
                      ),
              ),
            ),
    );
  }
}

/// Wraps a card so horizontal swipes within [edgeZonePx] of any edge pass through
/// to the TabBarView for tab switching, while swipes in the center trigger bookmark.
class _EdgeAwareSwipeCard extends StatelessWidget {
  final int edgeZonePx;
  final Widget child;

  const _EdgeAwareSwipeCard({required this.edgeZonePx, required this.child});

  @override
  Widget build(BuildContext context) {
    final edge = edgeZonePx.toDouble();
    return Stack(
      children: [
        child,
        Positioned(left: 0, top: 0, bottom: 0, width: edge, child: const _EdgeZone()),
        Positioned(right: 0, top: 0, bottom: 0, width: edge, child: const _EdgeZone()),
        Positioned(left: edge, right: edge, top: 0, height: edge, child: const _EdgeZone()),
        Positioned(left: edge, right: edge, bottom: 0, height: edge, child: const _EdgeZone()),
      ],
    );
  }
}

/// Transparent hit-testable zone that blocks Dismissible so TabBarView gets the swipe.
class _EdgeZone extends StatelessWidget {
  const _EdgeZone();

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {},
    );
  }
}

class _FeedCard extends StatefulWidget {
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
  final _CardVariant variant;
  final int index;

  const _FeedCard({
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
    required this.variant,
    required this.index,
  });

  @override
  State<_FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<_FeedCard> {
  String? _translatedText;
  bool _isTranslating = false;
  bool? _showTranslate;

  @override
  void initState() {
    super.initState();
    _checkShowTranslate();
  }

  Future<void> _checkShowTranslate() async {
    // Use all visible user-generated text on the card so phrases like "(7 days)" and venue names are included
    final parts = <String>[widget.itinerary.title];
    if (widget.description.isNotEmpty) parts.add(widget.description);
    if (widget.locations.isNotEmpty) parts.add(widget.locations);
    final text = parts.join('\n\n');
    final different = await isContentInDifferentLanguage(text, LocaleNotifier.instance.localeCode);
    if (mounted) setState(() => _showTranslate = different);
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.itinerary;
    final description = widget.description;
    final locations = widget.locations;
    final isCompact = widget.variant == _CardVariant.compact;
    final mapHeight = widget.variant == _CardVariant.tall ? 240.0 : (isCompact ? 88.0 : 200.0);

    return Card(
      margin: const EdgeInsets.fromLTRB(AppTheme.spacingLg, 0, AppTheme.spacingLg, AppTheme.spacingMd),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isCompact ? AppTheme.spacingSm : AppTheme.spacingMd,
            isCompact ? AppTheme.spacingSm : AppTheme.spacingSm,
            isCompact ? AppTheme.spacingSm : AppTheme.spacingMd,
            isCompact ? AppTheme.spacingSm : AppTheme.spacingMd,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth = constraints.maxWidth;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: widget.onAuthorTap,
                              borderRadius: BorderRadius.circular(8),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundImage: it.authorPhotoUrl != null && it.authorPhotoUrl!.isNotEmpty
                                        ? NetworkImage(it.authorPhotoUrl!)
                                        : null,
                                    child: it.authorPhotoUrl == null || it.authorPhotoUrl!.isEmpty
                                        ? Icon(Icons.person_outline_rounded, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant)
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      it.authorName ?? AppStrings.t(context, 'unknown'),
                                      style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_showTranslate == true)
                            IconButton(
                              icon: _isTranslating
                                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onSurfaceVariant))
                                  : Icon(Icons.translate_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant),
                              onPressed: _isTranslating
                                  ? null
                                  : _translatedText != null
                                      ? () => setState(() => _translatedText = null)
                                      : () async {
                                          final textParts = [it.title];
                                          if (description.isNotEmpty) textParts.add(description);
                                          if (locations.isNotEmpty) textParts.add(locations);
                                          final text = textParts.join('\n\n');
                                          setState(() => _isTranslating = true);
                                          final result = await translate(text: text, targetLanguageCode: LocaleNotifier.instance.localeCode);
                                          if (mounted) {
                                            setState(() {
                                              _translatedText = result;
                                              _isTranslating = false;
                                            });
                                          }
                                        },
                              style: IconButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(40, 40)),
                            ),
                          if (widget.onLike != null)
                            IconButton(
                              icon: Icon(
                                widget.isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                                color: widget.isLiked ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              onPressed: widget.onLike,
                              style: IconButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(40, 40)),
                            ),
                          IconButton(
                            icon: Icon(Icons.share_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            onPressed: () => shareItineraryLink(it.id, title: it.title),
                            style: IconButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(40, 40)),
                          ),
                          IconButton(
                            icon: Icon(widget.isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: widget.isBookmarked ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant),
                            onPressed: widget.onBookmark,
                            style: IconButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(40, 40)),
                          ),
                        ],
                      ),
                      if (widget.onLike != null && widget.likeCount > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${widget.likeCount} ${AppStrings.t(context, 'likes')}',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                        ),
                      ],
                      if (it.bookmarkCount != null && it.bookmarkCount! > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${it.bookmarkCount} ${AppStrings.t(context, 'saved_count')}',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500),
                        ),
                      ],
                      if (it.updatedAt != null) ...[
                        const SizedBox(height: 2),
                        Text(_formatDate(it.updatedAt!), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                      SizedBox(height: isCompact ? 4 : AppTheme.spacingSm),
              if (_translatedText != null) ...[
                Text(
                  _translatedText!,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: isCompact ? 16 : null),
                  maxLines: isCompact ? 1 : 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ] else ...[
                Text(
                  it.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: isCompact ? 16 : null),
                  maxLines: isCompact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (description.isNotEmpty) ...[
                  SizedBox(height: isCompact ? 2 : 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, height: isCompact ? 1.2 : 1.4, fontSize: isCompact ? 12 : null),
                    maxLines: isCompact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
              SizedBox(height: isCompact ? 6 : AppTheme.spacingMd),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  Icon(Icons.calendar_today_rounded, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text('${it.daysCount} ${AppStrings.t(context, 'days')}', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                  if (it.mode != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: it.mode == 'luxury' ? Colors.purple.shade50 : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        it.mode!.toUpperCase(),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: it.mode == 'luxury' ? Colors.purple.shade700 : Theme.of(context).colorScheme.primary),
                      ),
                    ),
                  if (locations.isNotEmpty)
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: contentWidth - 100),
                      child: Text(locations, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                ],
              ),
              SizedBox(height: isCompact ? 6 : AppTheme.spacingMd),
              StaticMapImage(
                itinerary: it,
                width: contentWidth,
                height: mapHeight,
                pathColor: Theme.of(context).colorScheme.primary,
              ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

class _SkeletonCard extends StatelessWidget {
  final _CardVariant variant;

  const _SkeletonCard({required this.variant});

  @override
  Widget build(BuildContext context) {
    final mapHeight = variant == _CardVariant.tall ? 240.0 : 200.0;
    return Card(
      margin: const EdgeInsets.fromLTRB(AppTheme.spacingLg, 0, AppTheme.spacingLg, AppTheme.spacingMd),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 80, height: 14, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4))),
                const Spacer(),
                Container(width: 24, height: 24, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12))),
              ],
            ),
            const SizedBox(height: 12),
            Container(width: 180, height: 20, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 8),
            Container(width: double.infinity, height: 14, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(width: 60, height: 12, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4))),
                const SizedBox(width: 16),
                Container(width: 50, height: 12, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4))),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: mapHeight,
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
            ),
          ],
        ),
      ),
    );
  }
}
