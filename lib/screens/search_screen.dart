import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../core/analytics.dart';
import '../core/app_link.dart';
import '../core/search_focus_notifier.dart';
import '../l10n/app_strings.dart';
import '../models/itinerary.dart';
import '../models/profile.dart';
import '../services/supabase_service.dart';
import '../services/places_service.dart';
import '../data/countries.dart';

const String _recentSearchesKey = 'search_recent_searches';
const int _recentSearchesMax = 12;

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  List<ProfileSearchResult> _profileResults = [];
  List<Itinerary> _tripResults = [];
  final Map<String, bool> _placeLiked = {};
  Set<String> _followedProfileIds = {};
  bool _isLoading = false;
  String? _error;
  Timer? _searchDebounce;
  List<String> _recentSearches = [];
  bool _isLocationSearch = false;

  void _focusSearchBar() {
    if (mounted) {
      FocusScope.of(context).requestFocus(_searchFocusNode);
    }
  }

  @override
  void initState() {
    super.initState();
    SearchFocusNotifier.addListener(_focusSearchBar);
    _loadRecentSearches();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_recentSearchesKey);
    if (mounted) setState(() => _recentSearches = list ?? []);
  }

  Future<void> _addRecentSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final next = [q, ..._recentSearches.where((s) => s != q)].take(_recentSearchesMax).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentSearchesKey, next);
    if (mounted) setState(() => _recentSearches = next);
  }

  Future<void> _removeRecentSearch(String query) async {
    final next = _recentSearches.where((s) => s != query).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentSearchesKey, next);
    if (mounted) setState(() => _recentSearches = next);
  }

  Future<void> _clearAllRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentSearchesKey, []);
    if (mounted) setState(() => _recentSearches = []);
  }

  @override
  void dispose() {
    SearchFocusNotifier.removeListener(_focusSearchBar);
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _toggleFollow(String profileId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final wasFollowing = _followedProfileIds.contains(profileId);
    if (!mounted) return;
    setState(() {
      final next = {..._followedProfileIds};
      if (wasFollowing) next.remove(profileId); else next.add(profileId);
      _followedProfileIds = next;
    });
    try {
      if (wasFollowing) {
        await SupabaseService.unfollowUser(userId, profileId);
      } else {
        await SupabaseService.followUser(userId, profileId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          final next = {..._followedProfileIds};
          if (wasFollowing) next.add(profileId); else next.remove(profileId);
          _followedProfileIds = next;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.t(context, 'could_not_update_follow_status'))),
        );
      }
    }
  }

  Future<void> _search() async {
    if (!mounted) return;
    final query = _searchController.text.trim();
    setState(() {
      _isLoading = true;
      _error = null;
    });
    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        _profileResults = [];
        _tripResults = [];
        _isLocationSearch = false;
        _isLoading = false;
      });
      return;
    }
    try {
      // Try to resolve query as a location first
      final location = await PlacesService.resolvePlace(query);
      final userId = Supabase.instance.client.auth.currentUser?.id;
      
      if (location != null) {
        // Location search: search both trips and people by location
        _isLocationSearch = true;
        try {
          final results = await Future.wait([
            SupabaseService.searchTripsByLocation(location.$1, location.$2, radiusKm: 50.0, limit: 50),
            SupabaseService.searchPeopleByLocation(location.$1, location.$2, radiusKm: 50.0, limit: 30),
            userId != null ? SupabaseService.getFollowedIds(userId) : Future.value(<String>[]),
          ]);
          final trips = results[0] as List<Itinerary>;
          final profiles = results[1] as List<ProfileSearchResult>;
          final followedIds = results[2] as List<String>;
          
          if (trips.isNotEmpty && userId != null) {
            final ids = trips.map((i) => i.id).toList();
            final likeCounts = await SupabaseService.getLikeCounts(ids);
            final likedIds = await SupabaseService.getLikedItineraryIds(userId, ids);
            final tripsWithLikes = trips.map((i) => i.copyWith(likeCount: likeCounts[i.id])).toList();
            if (!mounted) return;
            setState(() {
              _tripResults = tripsWithLikes;
              _profileResults = profiles;
              _followedProfileIds = followedIds.toSet();
              _placeLiked.clear();
              _placeLiked.addAll({for (final id in ids) id: likedIds.contains(id)});
              _isLoading = false;
            });
          } else {
            if (!mounted) return;
            setState(() {
              _tripResults = trips;
              _profileResults = profiles;
              _followedProfileIds = followedIds.toSet();
              _placeLiked.clear();
              _isLoading = false;
            });
          }
          Analytics.logEvent('location_search_performed', {
            'result_trips': trips.length,
            'result_people': profiles.length,
          });
        } catch (e) {
          // If location search fails, fall back to text search
          debugPrint('Location search failed, falling back to text search: $e');
          _isLocationSearch = false;
          final results = await Future.wait([
            SupabaseService.searchProfiles(query, limit: 30),
            SupabaseService.searchItineraries(query: query, limit: 50),
            userId != null ? SupabaseService.getFollowedIds(userId) : Future.value(<String>[]),
          ]);
          final profiles = results[0] as List<ProfileSearchResult>;
          var trips = results[1] as List<Itinerary>;
          final followedIds = results[2] as List<String>;
          
          if (trips.isNotEmpty && userId != null) {
            final ids = trips.map((i) => i.id).toList();
            final likeCounts = await SupabaseService.getLikeCounts(ids);
            final likedIds = await SupabaseService.getLikedItineraryIds(userId, ids);
            trips = trips.map((i) => i.copyWith(likeCount: likeCounts[i.id])).toList();
            if (!mounted) return;
            setState(() {
              _profileResults = profiles;
              _tripResults = trips;
              _followedProfileIds = followedIds.toSet();
              _placeLiked.clear();
              _placeLiked.addAll({for (final id in ids) id: likedIds.contains(id)});
              _isLoading = false;
            });
          } else {
            if (!mounted) return;
            setState(() {
              _profileResults = profiles;
              _tripResults = trips;
              _followedProfileIds = followedIds.toSet();
              _placeLiked.clear();
              _isLoading = false;
            });
          }
          Analytics.logEvent('text_search_performed', {
            'result_trips': trips.length,
            'result_people': profiles.length,
          });
        }
      } else {
        // Text search: search both profiles and trips by text
        _isLocationSearch = false;
        final results = await Future.wait([
          SupabaseService.searchProfiles(query, limit: 30),
          SupabaseService.searchItineraries(query: query, limit: 50),
          userId != null ? SupabaseService.getFollowedIds(userId) : Future.value(<String>[]),
        ]);
        final profiles = results[0] as List<ProfileSearchResult>;
        var trips = results[1] as List<Itinerary>;
        final followedIds = results[2] as List<String>;
        
        if (trips.isNotEmpty && userId != null) {
          final ids = trips.map((i) => i.id).toList();
          final likeCounts = await SupabaseService.getLikeCounts(ids);
          final likedIds = await SupabaseService.getLikedItineraryIds(userId, ids);
          trips = trips.map((i) => i.copyWith(likeCount: likeCounts[i.id])).toList();
          if (!mounted) return;
          setState(() {
            _profileResults = profiles;
            _tripResults = trips;
            _followedProfileIds = followedIds.toSet();
            _placeLiked.clear();
            _placeLiked.addAll({for (final id in ids) id: likedIds.contains(id)});
            _isLoading = false;
          });
        } else {
          if (!mounted) return;
          setState(() {
            _profileResults = profiles;
            _tripResults = trips;
            _followedProfileIds = followedIds.toSet();
            _placeLiked.clear();
            _isLoading = false;
          });
        }
        Analytics.logEvent('text_search_performed', {
          'result_trips': trips.length,
          'result_people': profiles.length,
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _togglePlaceLike(String itineraryId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final wasLiked = _placeLiked[itineraryId] ?? false;
    if (!mounted) return;
    setState(() => _placeLiked[itineraryId] = !wasLiked);
    final idx = _tripResults.indexWhere((i) => i.id == itineraryId);
    if (idx >= 0) {
      final it = _tripResults[idx];
      _tripResults[idx] = it.copyWith(likeCount: (it.likeCount ?? 0) + (wasLiked ? -1 : 1));
    }
    try {
      if (wasLiked) {
        await SupabaseService.removeLike(userId, itineraryId);
      } else {
        await SupabaseService.addLike(userId, itineraryId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _placeLiked[itineraryId] = wasLiked;
          if (idx >= 0) {
            final it = _tripResults[idx];
            _tripResults[idx] = it.copyWith(likeCount: (it.likeCount ?? 0) + (wasLiked ? 1 : -1));
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t(context, 'could_not_refresh'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Analytics.logScreenView('search');
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.t(context, 'search')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: AppStrings.t(context, 'destination_or_keywords'),
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    _searchController.clear();
                    _search();
                  },
                ),
              ),
              onSubmitted: (_) {
                _addRecentSearch(_searchController.text.trim());
                _search();
              },
              onChanged: (_) {
                _searchDebounce?.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 400), _search);
              },
            ),
          ),
          Expanded(
            child: _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildErrorState();
    }
    final searchEmpty = _searchController.text.trim().isEmpty;
    if (searchEmpty && _recentSearches.isNotEmpty) {
      return _buildRecentSearches();
    }
    if (searchEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: AppTheme.spacingLg),
            Text(
              AppStrings.t(context, 'destination_or_keywords'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    return CustomScrollView(
      slivers: [
        // People section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppTheme.spacingMd, AppTheme.spacingMd, AppTheme.spacingMd, AppTheme.spacingSm),
            child: Text(
              AppStrings.t(context, 'profiles'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        if (_profileResults.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingXl),
              child: Center(
                child: Text(
                  AppStrings.t(context, 'no_profiles_found'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final p = _profileResults[index];
                final currentUserId = Supabase.instance.client.auth.currentUser?.id;
                return _ProfileCard(
                  profile: p,
                  isFollowing: _followedProfileIds.contains(p.id),
                  isOwnProfile: currentUserId == p.id,
                  onTap: () {
                    _addRecentSearch(p.name?.trim() ?? AppStrings.t(context, 'profile'));
                    context.push('/author/${p.id}');
                  },
                  onFollowTap: () => _toggleFollow(p.id),
                );
              },
              childCount: _profileResults.length,
            ),
          ),
        // Trips section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppTheme.spacingMd, AppTheme.spacingLg, AppTheme.spacingMd, AppTheme.spacingSm),
            child: Text(
              AppStrings.t(context, 'trips'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        if (_tripResults.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingXl),
              child: Center(
                child: Text(
                  AppStrings.t(context, 'no_trips_found'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final it = _tripResults[index];
                final userId = Supabase.instance.client.auth.currentUser?.id;
                final isOthersPost = userId != null && it.authorId != userId;
                return _ItineraryCard(
                  itinerary: it,
                  isLiked: _placeLiked[it.id] ?? false,
                  likeCount: it.likeCount ?? 0,
                  onLike: isOthersPost ? () => _togglePlaceLike(it.id) : null,
                  onTap: () {
                    _addRecentSearch(it.title.trim().isNotEmpty ? it.title.trim() : it.destination);
                    context.push('/itinerary/${it.id}');
                  },
                  onAuthorTap: () => context.push('/author/${it.authorId}'),
                );
              },
              childCount: _tripResults.length,
            ),
          ),
      ],
    );
  }

  Widget _buildRecentSearches() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
            itemCount: _recentSearches.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final query = _recentSearches[i];
              return ListTile(
                leading: Icon(Icons.history_rounded, size: 22, color: Theme.of(context).colorScheme.onSurfaceVariant),
                title: Text(query, style: Theme.of(context).textTheme.bodyLarge),
                trailing: IconButton(
                  icon: Icon(Icons.close, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  onPressed: () => _removeRecentSearch(query),
                  style: IconButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(40, 40)),
                ),
                onTap: () {
                  _searchController.text = query;
                  _search();
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppTheme.spacingMd, AppTheme.spacingSm, AppTheme.spacingMd, AppTheme.spacingLg),
          child: OutlinedButton.icon(
            onPressed: _clearAllRecentSearches,
            icon: const Icon(Icons.clear_all_rounded, size: 20),
            label: Text(AppStrings.t(context, 'clear_all_searches')),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
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
            Text(_error!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: AppTheme.spacingLg),
            FilledButton(onPressed: _search, child: Text(AppStrings.t(context, 'retry'))),
          ],
        ),
      ),
    );
  }

}

class _ProfileCard extends StatelessWidget {
  final ProfileSearchResult profile;
  final bool isFollowing;
  final bool isOwnProfile;
  final VoidCallback onTap;
  final VoidCallback? onFollowTap;

  const _ProfileCard({
    required this.profile,
    required this.isFollowing,
    required this.isOwnProfile,
    required this.onTap,
    this.onFollowTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundImage: profile.photoUrl != null ? NetworkImage(profile.photoUrl!) : null,
                child: profile.photoUrl == null ? Icon(Icons.person_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant) : null,
              ),
              const SizedBox(width: AppTheme.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      profile.name ?? AppStrings.t(context, 'unknown'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.map_rounded, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text('${profile.tripsCount} ${AppStrings.t(context, 'trips')}', style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(width: 12),
                        Icon(Icons.people_rounded, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${profile.followersCount} ${AppStrings.t(context, 'followers')}',
                            style: Theme.of(context).textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onFollowTap != null && !isOwnProfile)
                Flexible(
                  child: FilledButton.tonal(
                    onPressed: onFollowTap,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(isFollowing ? AppStrings.t(context, 'following') : AppStrings.t(context, 'follow')),
                  ),
                )
              else
                Icon(Icons.chevron_right_rounded, size: 24, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItineraryCard extends StatelessWidget {
  final Itinerary itinerary;
  final bool isLiked;
  final int likeCount;
  final VoidCallback? onLike;
  final VoidCallback onTap;
  final VoidCallback? onAuthorTap;

  const _ItineraryCard({
    required this.itinerary,
    this.isLiked = false,
    this.likeCount = 0,
    this.onLike,
    required this.onTap,
    this.onAuthorTap,
  });

  @override
  Widget build(BuildContext context) {
    final it = itinerary;
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                it.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                it.destination,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppTheme.spacingSm),
              if (likeCount > 0) ...[
                const SizedBox(height: 4),
                Text('$likeCount ${AppStrings.t(context, 'likes')}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text('${it.daysCount} ${AppStrings.t(context, 'days')}', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(width: 12),
                  if (it.mode != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(it.mode!.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
                    ),
                  const Spacer(),
                  if (onLike != null)
                    IconButton(
                      icon: Icon(
                        isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                        size: 20,
                        color: isLiked ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      onPressed: onLike,
                      style: IconButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(36, 36)),
                    ),
                  IconButton(
                    icon: Icon(Icons.share_outlined, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    onPressed: () => shareItineraryLink(it.id, title: it.title),
                    style: IconButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(36, 36)),
                  ),
                  if (it.authorName != null)
                    InkWell(
                      onTap: onAuthorTap,
                      borderRadius: BorderRadius.circular(4),
                      child: Text('${AppStrings.t(context, 'by')} ${it.authorName}', style: Theme.of(context).textTheme.bodySmall),
                    ),
                ],
              ),
              if (it.styleTags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: it.styleTags.map((s) => Chip(label: Text(s, style: const TextStyle(fontSize: 11)), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)).toList(),
                ),
              ],
              if (it.stopsCount != null && it.stopsCount! > 0) ...[
                const SizedBox(height: 4),
                Text('${it.stopsCount} ${AppStrings.t(context, 'stops')}', style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
