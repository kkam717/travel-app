import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';
import '../models/itinerary.dart';
import '../models/user_city.dart';
import '../core/analytics.dart';

class SupabaseService {
  static SupabaseClient get _client => Supabase.instance.client;

  static String? get currentUserId => _client.auth.currentUser?.id;

  // --- Profile ---
  static Future<Profile?> getProfile(String userId) async {
    try {
      final res = await _client.from('profiles').select().eq('id', userId).maybeSingle();
      if (res == null) return null;
      return Profile.fromJson(res as Map<String, dynamic>);
    } catch (e) {
      Analytics.logEvent('profile_fetch_error', {'error': e.toString()});
      rethrow;
    }
  }

  static Future<List<ProfileSearchResult>> searchProfiles(String? query, {int limit = 30}) async {
    try {
      final res = await _client.rpc(
        'search_profiles_with_stats',
        params: {'search_query': query ?? '', 'result_limit': limit},
      );
      return (res as List)
          .map((e) => ProfileSearchResult.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Analytics.logEvent('profile_search_error', {'error': e.toString()});
      rethrow;
    }
  }

  static Future<void> updateProfile(String userId, Map<String, dynamic> data) async {
    try {
      data['updated_at'] = DateTime.now().toIso8601String();
      data['id'] = userId;
      await _client.from('profiles').upsert(data, onConflict: 'id');

      // Sync name to Supabase Auth user metadata (display name in dashboard)
      final name = data['name'] as String?;
      if (name != null &&
          name.isNotEmpty &&
          _client.auth.currentUser?.id == userId) {
        await _client.auth.updateUser(
          UserAttributes(data: {'name': name}),
        );
      }
    } catch (e) {
      Analytics.logEvent('profile_update_error', {'error': e.toString()});
      rethrow;
    }
  }

  // --- Current City & Past Cities ---
  static Future<List<UserPastCity>> getPastCities(String userId) async {
    try {
      final res = await _client.from('user_past_cities').select().eq('user_id', userId).order('position');
      return (res as List).map((e) => UserPastCity.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      Analytics.logEvent('past_cities_fetch_error', {'error': e.toString()});
      return [];
    }
  }

  static Future<UserPastCity?> addPastCity(String userId, String cityName) async {
    try {
      final existing = await _client.from('user_past_cities').select().eq('user_id', userId);
      final position = (existing as List).length;
      final res = await _client.from('user_past_cities').insert({
        'user_id': userId,
        'city_name': cityName.trim(),
        'position': position,
      }).select().single();
      return UserPastCity.fromJson(res as Map<String, dynamic>);
    } catch (e) {
      Analytics.logEvent('past_city_add_error', {'error': e.toString()});
      rethrow;
    }
  }

  static Future<void> removePastCity(String id) async {
    try {
      await _client.from('user_past_cities').delete().eq('id', id);
    } catch (e) {
      Analytics.logEvent('past_city_remove_error', {'error': e.toString()});
      rethrow;
    }
  }

  // --- Top Spots ---
  static Future<List<UserTopSpot>> getTopSpots(String userId, String cityName) async {
    try {
      final res = await _client.from('user_top_spots').select().eq('user_id', userId).eq('city_name', cityName).order('category').order('position');
      return (res as List).map((e) => UserTopSpot.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      Analytics.logEvent('top_spots_fetch_error', {'error': e.toString()});
      return [];
    }
  }

  static Future<UserTopSpot?> addTopSpot(UserTopSpot spot) async {
    try {
      final existing = await _client.from('user_top_spots').select().eq('user_id', spot.userId).eq('city_name', spot.cityName).eq('category', spot.category);
      if ((existing as List).length >= 5) {
        throw StateError('Maximum 5 spots per category');
      }
      final position = existing.length;
      final res = await _client.from('user_top_spots').insert({
        'user_id': spot.userId,
        'city_name': spot.cityName,
        'category': spot.category,
        'name': spot.name.trim(),
        'description': spot.description,
        'location_url': spot.locationUrl,
        'position': position,
      }).select().single();
      return UserTopSpot.fromJson(res as Map<String, dynamic>);
    } catch (e) {
      Analytics.logEvent('top_spot_add_error', {'error': e.toString()});
      rethrow;
    }
  }

  static Future<void> updateTopSpot(String id, Map<String, dynamic> data) async {
    try {
      data['updated_at'] = DateTime.now().toIso8601String();
      await _client.from('user_top_spots').update(data).eq('id', id);
    } catch (e) {
      Analytics.logEvent('top_spot_update_error', {'error': e.toString()});
      rethrow;
    }
  }

  static Future<void> removeTopSpot(String id) async {
    try {
      await _client.from('user_top_spots').delete().eq('id', id);
    } catch (e) {
      Analytics.logEvent('top_spot_remove_error', {'error': e.toString()});
      rethrow;
    }
  }

  // --- Itineraries ---
  static Future<List<Itinerary>> searchItineraries({
    String? query,
    int? daysCount,
    List<String>? styles,
    String? mode,
    int limit = 50,
  }) async {
    try {
      // Try RPC first (requires migration 007)
      try {
        final res = await _client.rpc(
          'search_itineraries',
          params: {
            'p_search_query': query?.trim().isEmpty ?? true ? null : query?.trim(),
            'p_days_count': daysCount,
            'p_style_tags': styles?.isEmpty ?? true ? null : styles?.map((s) => s.toLowerCase()).toList(),
            'p_mode_filter': mode?.toLowerCase(),
            'p_result_limit': limit,
          },
        );
        final rows = (res as List).map((e) {
          final m = Map<String, dynamic>.from(e as Map<String, dynamic>);
          m['profiles'] = {'name': m.remove('author_name')};
          return m;
        }).toList();
        var itineraries = rows.map((e) => Itinerary.fromJson(e)).toList();
        if (itineraries.isNotEmpty) {
          final ids = itineraries.map((i) => i.id).toList();
          final stopsRes = await _client.from('itinerary_stops').select('itinerary_id').inFilter('itinerary_id', ids);
          final counts = <String, int>{};
          for (final row in stopsRes as List) {
            final itId = (row as Map)['itinerary_id'] as String;
            counts[itId] = (counts[itId] ?? 0) + 1;
          }
          itineraries = itineraries.map((i) => i.copyWith(stopsCount: counts[i.id] ?? 0)).toList();
        }
        return itineraries;
      } on PostgrestException catch (e) {
        // RPC may not exist (migration 007 not run) - fall back to table query
        debugPrint('[search_itineraries] RPC failed: ${e.message}');
      }
      // Fallback: PostgREST table query (title + destination only)
      // Only public itineraries in search - private/friends never appear
      final searchQuery = query?.trim();
      final hasQuery = searchQuery != null && searchQuery.isNotEmpty;
      var q = _client.from('itineraries').select('*, profiles!itineraries_author_id_fkey(name,photo_url)').isFilter('forked_from_itinerary_id', null).eq('visibility', 'public');
      if (daysCount != null) q = q.eq('days_count', daysCount);
      if (mode != null) q = q.eq('mode', mode.toLowerCase());
      if (styles != null && styles.isNotEmpty) {
        q = q.overlaps('style_tags', styles.map((s) => s.toLowerCase()).toList());
      }
      if (hasQuery) {
        final pattern = '%${searchQuery!.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_')}%';
        q = q.or('title.ilike.$pattern,destination.ilike.$pattern');
      }
      final res = await q.order('created_at', ascending: false).limit(limit);
      var itineraries = (res as List).map((e) => Itinerary.fromJson(e as Map<String, dynamic>)).toList();
      if (itineraries.isNotEmpty) {
        final ids = itineraries.map((i) => i.id).toList();
        final stopsRes = await _client.from('itinerary_stops').select('itinerary_id').inFilter('itinerary_id', ids);
        final counts = <String, int>{};
        for (final row in stopsRes as List) {
          final itId = (row as Map)['itinerary_id'] as String;
          counts[itId] = (counts[itId] ?? 0) + 1;
        }
        itineraries = itineraries.map((i) => i.copyWith(stopsCount: counts[i.id] ?? 0)).toList();
      }
      return itineraries;
    } catch (e) {
      Analytics.logEvent('itinerary_search_error', {'error': e.toString()});
      rethrow;
    }
  }

  static Future<Itinerary?> getItinerary(String id, {bool checkAccess = true}) async {
    try {
      final res = await _client.from('itineraries').select('*, profiles!itineraries_author_id_fkey(name,photo_url)').eq('id', id).maybeSingle();
      if (res == null) return null;

      final it = Itinerary.fromJson(res as Map<String, dynamic>);
      // RLS handles access: public for all, private for owner + followers

      final stopsRes = await _client.from('itinerary_stops').select().eq('itinerary_id', id).order('day').order('position');
      final stops = (stopsRes as List).map((e) => ItineraryStop.fromJson(e as Map<String, dynamic>)).toList();

      return it.copyWith(stops: stops);
    } catch (e) {
      Analytics.logEvent('itinerary_fetch_error', {'error': e.toString()});
      rethrow;
    }
  }

  static Future<Itinerary> createItinerary({
    required String authorId,
    required String title,
    required String destination,
    required int daysCount,
    required List<String> styleTags,
    required String mode,
    required String visibility,
    String? forkedFromId,
    required List<Map<String, dynamic>> stopsData,
  }) async {
    try {
      final res = await _client.from('itineraries').insert({
        'author_id': authorId,
        'title': title,
        'destination': destination,
        'days_count': daysCount,
        'style_tags': styleTags.map((s) => s.toLowerCase()).toList(),
        'mode': mode.toLowerCase(),
        'visibility': visibility,
        'forked_from_itinerary_id': forkedFromId,
      }).select().single();

      final it = Itinerary.fromJson(res as Map<String, dynamic>);
      for (var i = 0; i < stopsData.length; i++) {
        final stop = Map<String, dynamic>.from(stopsData[i]);
        stop['itinerary_id'] = it.id;
        stop['position'] = stop['position'] ?? i;
        // place_id in schema is UUID (internal places); google_place_id stores Google Place IDs
        final pid = stop['place_id'];
        if (pid == null || pid is! String || !RegExp(r'^[0-9a-f-]{36}$', caseSensitive: false).hasMatch(pid)) {
          stop.remove('place_id');
        }
        await _client.from('itinerary_stops').insert(stop);
      }
      return (await getItinerary(it.id, checkAccess: false)) ?? it;
    } catch (e) {
      Analytics.logEvent('itinerary_create_error', {'error': e.toString()});
      rethrow;
    }
  }

  static Future<void> updateItinerary(String id, Map<String, dynamic> data) async {
    try {
      data['updated_at'] = DateTime.now().toIso8601String();
      await _client.from('itineraries').update(data).eq('id', id);
    } catch (e) {
      Analytics.logEvent('itinerary_update_error', {'error': e.toString()});
      rethrow;
    }
  }

  static Future<void> updateItineraryStops(String itineraryId, List<Map<String, dynamic>> stopsData) async {
    try {
      await _client.from('itinerary_stops').delete().eq('itinerary_id', itineraryId);
      for (var i = 0; i < stopsData.length; i++) {
        final stop = Map<String, dynamic>.from(stopsData[i]);
        stop['itinerary_id'] = itineraryId;
        stop['position'] = i;
        // place_id in schema is UUID (internal places); google_place_id stores Google Place IDs
        final pid = stop['place_id'];
        if (pid == null || pid is! String || !RegExp(r'^[0-9a-f-]{36}$', caseSensitive: false).hasMatch(pid)) {
          stop.remove('place_id');
        }
        await _client.from('itinerary_stops').insert(stop);
      }
    } catch (e) {
      Analytics.logEvent('itinerary_stops_update_error', {'error': e.toString()});
      rethrow;
    }
  }

  // --- Bookmarks ---
  static Future<void> addBookmark(String userId, String itineraryId) async {
    try {
      await _client.from('bookmarks').insert({'user_id': userId, 'itinerary_id': itineraryId});
    } catch (e) {
      Analytics.logEvent('bookmark_add_error', {'error': e.toString()});
      rethrow;
    }
  }

  static Future<void> removeBookmark(String userId, String itineraryId) async {
    try {
      await _client.from('bookmarks').delete().eq('user_id', userId).eq('itinerary_id', itineraryId);
    } catch (e) {
      Analytics.logEvent('bookmark_remove_error', {'error': e.toString()});
      rethrow;
    }
  }

  static Future<bool> isBookmarked(String userId, String itineraryId) async {
    try {
      final res = await _client.from('bookmarks').select().eq('user_id', userId).eq('itinerary_id', itineraryId).maybeSingle();
      return res != null;
    } catch (e) {
      return false;
    }
  }

  /// Get bookmark counts per itinerary for social proof (uses RPC)
  static Future<Map<String, int>> getBookmarkCounts(List<String> itineraryIds) async {
    if (itineraryIds.isEmpty) return {};
    try {
      final res = await _client.rpc('get_bookmark_counts', params: {'p_itinerary_ids': itineraryIds});
      final map = <String, int>{};
      for (final row in res as List) {
        final m = row as Map<String, dynamic>;
        final id = m['itinerary_id'] as String?;
        final count = (m['bookmark_count'] as num?)?.toInt() ?? 0;
        if (id != null) map[id] = count;
      }
      return map;
    } catch (e) {
      return {};
    }
  }

  /// Batch check which itinerary IDs are bookmarked (single query instead of N)
  static Future<Set<String>> getBookmarkedItineraryIds(String userId, List<String> itineraryIds) async {
    if (itineraryIds.isEmpty) return {};
    try {
      final res = await _client
          .from('bookmarks')
          .select('itinerary_id')
          .eq('user_id', userId)
          .inFilter('itinerary_id', itineraryIds);
      return (res as List).map((e) => (e as Map)['itinerary_id'] as String).toSet();
    } catch (e) {
      return {};
    }
  }

  static Future<List<Itinerary>> getBookmarkedItineraries(String userId) async {
    try {
      final res = await _client
          .from('bookmarks')
          .select('itinerary_id')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      final ids = (res as List).map((e) => (e as Map)['itinerary_id'] as String).toList();
      if (ids.isEmpty) return [];

      final itRes = await _client.from('itineraries').select('*, profiles!itineraries_author_id_fkey(name,photo_url)').inFilter('id', ids).isFilter('forked_from_itinerary_id', null);
      final itList = (itRes as List).map((e) => Itinerary.fromJson(e as Map<String, dynamic>)).toList();
      final byId = {for (final i in itList) i.id: i};
      return ids.map((id) => byId[id]).whereType<Itinerary>().toList();
    } catch (e) {
      Analytics.logEvent('bookmarks_fetch_error', {'error': e.toString()});
      rethrow;
    }
  }

  static Future<List<Itinerary>> getPlanningItineraries(String userId) async {
    try {
      final res = await _client
          .from('itineraries')
          .select('*, profiles!itineraries_author_id_fkey(name,photo_url)')
          .eq('author_id', userId)
          .not('forked_from_itinerary_id', 'is', null)
          .order('updated_at', ascending: false);
      return (res as List).map((e) => Itinerary.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      Analytics.logEvent('planning_fetch_error', {'error': e.toString()});
      rethrow;
    }
  }

  static Future<List<Itinerary>> getUserItineraries(String userId, {bool publicOnly = false}) async {
    try {
      var q = _client.from('itineraries').select('*, profiles!itineraries_author_id_fkey(name,photo_url)').eq('author_id', userId).isFilter('forked_from_itinerary_id', null);
      if (publicOnly) q = q.eq('visibility', 'public');
      final res = await q.order('created_at', ascending: false);
      final itineraries = (res as List).map((e) => Itinerary.fromJson(e as Map<String, dynamic>)).toList();
      if (itineraries.isEmpty) return itineraries;

      // Batch load stops for map preview in feed cards
      final ids = itineraries.map((i) => i.id).toList();
      final stopsListRaw = await _client.from('itinerary_stops').select().inFilter('itinerary_id', ids).order('day').order('position');
      final stopsList = (stopsListRaw as List).map((e) => ItineraryStop.fromJson(e as Map<String, dynamic>)).toList();
      final stopsByItinerary = <String, List<ItineraryStop>>{};
      for (final s in stopsList) {
        stopsByItinerary.putIfAbsent(s.itineraryId, () => []).add(s);
      }
      return itineraries.map((i) => i.copyWith(stops: stopsByItinerary[i.id] ?? [])).toList();
    } catch (e) {
      Analytics.logEvent('user_itineraries_fetch_error', {'error': e.toString()});
      rethrow;
    }
  }

  // --- Follows & Feed ---
  static Future<void> followUser(String followerId, String followingId) async {
    if (followerId == followingId) return;
    try {
      await _client.from('follows').insert({'follower_id': followerId, 'following_id': followingId});
    } on PostgrestException catch (e) {
      // 23505 = unique_violation - already following, treat as success
      if (e.code == '23505') return;
      Analytics.logEvent('follow_error', {'error': e.toString()});
      rethrow;
    } catch (e) {
      Analytics.logEvent('follow_error', {'error': e.toString()});
      rethrow;
    }
  }

  static Future<void> unfollowUser(String followerId, String followingId) async {
    try {
      await _client.from('follows').delete().eq('follower_id', followerId).eq('following_id', followingId);
    } catch (e) {
      Analytics.logEvent('unfollow_error', {'error': e.toString()});
      rethrow;
    }
  }

  static Future<bool> isFollowing(String followerId, String followingId) async {
    try {
      final res = await _client.from('follows').select().eq('follower_id', followerId).eq('following_id', followingId).maybeSingle();
      return res != null;
    } catch (e) {
      return false;
    }
  }

  static Future<List<String>> getFollowedIds(String userId) async {
    try {
      final res = await _client.from('follows').select('following_id').eq('follower_id', userId);
      return (res as List).map((e) => (e as Map)['following_id'] as String).toList();
    } catch (e) {
      Analytics.logEvent('follows_fetch_error', {'error': e.toString()});
      return [];
    }
  }

  /// Returns user IDs who follow the given userId
  static Future<List<String>> getFollowerIds(String userId) async {
    try {
      final res = await _client.from('follows').select('follower_id').eq('following_id', userId);
      return (res as List).map((e) => (e as Map)['follower_id'] as String).toList();
    } catch (e) {
      return [];
    }
  }

  /// Returns user IDs where both users follow each other (mutual friends)
  static Future<List<String>> getMutualFriendIds(String userId) async {
    try {
      final followed = await getFollowedIds(userId);
      final followers = await getFollowerIds(userId);
      final followerSet = followers.toSet();
      return followed.where((id) => followerSet.contains(id)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Returns true if both users follow each other (mutual friends)
  static Future<bool> isMutualFriend(String userId, String otherUserId) async {
    if (userId == otherUserId) return false;
    final mutual = await getMutualFriendIds(userId);
    return mutual.contains(otherUserId);
  }

  static Future<int> getFollowerCount(String userId) async {
    try {
      final res = await _client.from('follows').select('follower_id').eq('following_id', userId);
      return (res as List).length;
    } catch (e) {
      return 0;
    }
  }

  /// Returns profiles of users who follow the given userId (people they are followed by)
  static Future<List<Profile>> getFollowers(String userId) async {
    try {
      final res = await _client.from('follows').select('follower_id').eq('following_id', userId);
      final followerIds = (res as List).map((e) => (e as Map)['follower_id'] as String).toList();
      if (followerIds.isEmpty) return [];
      final profilesRes = await _client.from('profiles').select().inFilter('id', followerIds);
      return (profilesRes as List).map((e) => Profile.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      Analytics.logEvent('followers_fetch_error', {'error': e.toString()});
      return [];
    }
  }

  /// Returns profiles of users the given userId follows (people they follow)
  static Future<List<Profile>> getFollowing(String userId) async {
    try {
      final res = await _client.from('follows').select('following_id').eq('follower_id', userId);
      final followingIds = (res as List).map((e) => (e as Map)['following_id'] as String).toList();
      if (followingIds.isEmpty) return [];
      final profilesRes = await _client.from('profiles').select().inFilter('id', followingIds);
      return (profilesRes as List).map((e) => Profile.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      Analytics.logEvent('following_fetch_error', {'error': e.toString()});
      return [];
    }
  }

  static Future<int> getFollowingCount(String userId) async {
    try {
      final res = await _client.from('follows').select('following_id').eq('follower_id', userId);
      return (res as List).length;
    } catch (e) {
      return 0;
    }
  }

  static Future<int> getTripsCount(String userId) async {
    try {
      final res = await _client.from('itineraries').select('id').eq('author_id', userId).isFilter('forked_from_itinerary_id', null);
      return (res as List).length;
    } catch (e) {
      return 0;
    }
  }

  static Future<List<Itinerary>> getFeedItineraries(String userId, {int limit = 20, String? afterCreatedAt}) async {
    try {
      final followedIds = await getFollowedIds(userId);
      final mutualIds = await getMutualFriendIds(userId);

      // 1. Own posts: all visibility
      // 2. Others: public from followed, OR all from mutual friends
      // Apply lt() before order/limit (lt is on FilterBuilder, not TransformBuilder)
      var q1 = _client.from('itineraries').select('*, profiles!itineraries_author_id_fkey(name,photo_url)').eq('author_id', userId).isFilter('forked_from_itinerary_id', null);
      if (afterCreatedAt != null) q1 = q1.lt('created_at', afterCreatedAt);
      final exec1 = q1.order('created_at', ascending: false).limit(limit * 2);

      final futures = <Future<List<dynamic>>>[exec1];
      if (followedIds.isNotEmpty) {
        var q2 = _client.from('itineraries').select('*, profiles!itineraries_author_id_fkey(name,photo_url)').inFilter('author_id', followedIds).isFilter('forked_from_itinerary_id', null).eq('visibility', 'public');
        if (afterCreatedAt != null) q2 = q2.lt('created_at', afterCreatedAt);
        final exec2 = q2.order('created_at', ascending: false).limit(limit * 2);
        futures.add(exec2);
      }
      if (mutualIds.isNotEmpty) {
        var q3 = _client.from('itineraries').select('*, profiles!itineraries_author_id_fkey(name,photo_url)').inFilter('author_id', mutualIds).isFilter('forked_from_itinerary_id', null);
        if (afterCreatedAt != null) q3 = q3.lt('created_at', afterCreatedAt);
        final exec3 = q3.order('created_at', ascending: false).limit(limit * 2);
        futures.add(exec3);
      }

      final results = await Future.wait(futures);
      final allRows = <Map<String, dynamic>>[];
      final seenIds = <String>{};
      for (final r in results) {
        for (final row in r as List) {
          final m = Map<String, dynamic>.from(row as Map<String, dynamic>);
          final id = m['id'] as String;
          if (!seenIds.add(id)) continue;
          allRows.add(m);
        }
      }
      allRows.sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
      final limited = allRows.take(limit).toList();

      final itineraries = limited.map((e) => Itinerary.fromJson(e)).toList();
      if (itineraries.isEmpty) return itineraries;

      // Batch load stops and bookmark counts
      final ids = itineraries.map((i) => i.id).toList();
      final stopsListRaw = await _client.from('itinerary_stops').select().inFilter('itinerary_id', ids).order('day').order('position');
      final counts = await getBookmarkCounts(ids);
      final stopsList = (stopsListRaw as List).map((e) => ItineraryStop.fromJson(e as Map<String, dynamic>)).toList();
      final stopsByItinerary = <String, List<ItineraryStop>>{};
      for (final s in stopsList) {
        stopsByItinerary.putIfAbsent(s.itineraryId, () => []).add(s);
      }
      return itineraries.map((i) => i.copyWith(stops: stopsByItinerary[i.id] ?? [], bookmarkCount: counts[i.id])).toList();
    } catch (e) {
      Analytics.logEvent('feed_fetch_error', {'error': e.toString()});
      rethrow;
    }
  }

  /// Discover trips for "For you" - public itineraries matching user interests, excluding feed authors
  static Future<List<Itinerary>> getDiscoverItineraries(String userId, {int limit = 5, List<String>? excludeAuthorIds}) async {
    try {
      final profile = await getProfile(userId);
      final followedIds = await getFollowedIds(userId);
      final mutualIds = await getMutualFriendIds(userId);
      final excludeIds = {...followedIds, ...mutualIds, userId};
      if (excludeAuthorIds != null) excludeIds.addAll(excludeAuthorIds);

      var q = _client.from('itineraries').select('*, profiles!itineraries_author_id_fkey(name,photo_url)').isFilter('forked_from_itinerary_id', null).eq('visibility', 'public').order('created_at', ascending: false).limit(limit * 6);

      final res = await q;
      var rows = (res as List).cast<Map<String, dynamic>>().where((r) => !excludeIds.contains(r['author_id'])).toList();
      if (profile != null && (profile.visitedCountries.isNotEmpty || profile.travelStyles.isNotEmpty)) {
        rows.sort((a, b) {
          final destA = (a['destination'] as String? ?? '').toLowerCase();
          final destB = (b['destination'] as String? ?? '').toLowerCase();
          final stylesA = List<String>.from(a['style_tags'] ?? []).map((s) => s.toString().toLowerCase()).toList();
          final stylesB = List<String>.from(b['style_tags'] ?? []).map((s) => s.toString().toLowerCase()).toList();
          final scoreA = (profile.visitedCountries.any((c) => destA.contains(c.toLowerCase())) ? 2 : 0) + (profile.travelStyles.any((s) => stylesA.contains(s.toLowerCase())) ? 2 : 0);
          final scoreB = (profile.visitedCountries.any((c) => destB.contains(c.toLowerCase())) ? 2 : 0) + (profile.travelStyles.any((s) => stylesB.contains(s.toLowerCase())) ? 2 : 0);
          return scoreB.compareTo(scoreA);
        });
      }
      rows = rows.take(limit).toList();

      final itineraries = rows.map((e) => Itinerary.fromJson(e)).toList();
      if (itineraries.isEmpty) return itineraries;

      final ids = itineraries.map((i) => i.id).toList();
      final stopsListRaw = await _client.from('itinerary_stops').select().inFilter('itinerary_id', ids).order('day').order('position');
      final counts = await getBookmarkCounts(ids);
      final stopsList = (stopsListRaw as List).map((e) => ItineraryStop.fromJson(e as Map<String, dynamic>)).toList();
      final stopsByItinerary = <String, List<ItineraryStop>>{};
      for (final s in stopsList) {
        stopsByItinerary.putIfAbsent(s.itineraryId, () => []).add(s);
      }
      return itineraries.map((i) => i.copyWith(stops: stopsByItinerary[i.id] ?? [], bookmarkCount: counts[i.id])).toList();
    } catch (e) {
      return [];
    }
  }

  // --- Storage ---
  static Future<String> uploadAvatar(String userId, Uint8List bytes, String extension) async {
    try {
      final path = '$userId/avatar.$extension';
      await _client.storage.from('avatars').uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));
      return _client.storage.from('avatars').getPublicUrl(path);
    } catch (e) {
      Analytics.logEvent('avatar_upload_error', {'error': e.toString()});
      rethrow;
    }
  }
}
