import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';
import '../models/itinerary.dart';
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

  static Future<void> updateProfile(String userId, Map<String, dynamic> data) async {
    try {
      data['updated_at'] = DateTime.now().toIso8601String();
      data['id'] = userId;
      await _client.from('profiles').upsert(data, onConflict: 'id');
    } catch (e) {
      Analytics.logEvent('profile_update_error', {'error': e.toString()});
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
      // Build query - filters must come before order/limit
      PostgrestList res;
      if (daysCount != null && mode != null && styles != null && styles.isNotEmpty) {
        res = await _client
            .from('itineraries')
            .select('*, profiles!itineraries_author_id_fkey(name)')
            .eq('visibility', 'public')
            .eq('days_count', daysCount!)
            .eq('mode', mode!)
            .overlaps('style_tags', styles!.map((s) => s.toLowerCase()).toList())
            .order('created_at', ascending: false)
            .limit(query != null && query.isNotEmpty ? limit * 3 : limit);
      } else {
        var q = _client.from('itineraries').select('*, profiles!itineraries_author_id_fkey(name)').eq('visibility', 'public');
        if (daysCount != null) q = q.eq('days_count', daysCount);
        if (mode != null) q = q.eq('mode', mode.toLowerCase());
        if (styles != null && styles.isNotEmpty) {
          q = q.overlaps('style_tags', styles.map((s) => s.toLowerCase()).toList());
        }
        res = await q.order('created_at', ascending: false).limit(query != null && query.isNotEmpty ? limit * 3 : limit);
      }
      var itineraries = (res as List).map((e) => Itinerary.fromJson(e as Map<String, dynamic>)).toList();
      if (query != null && query.isNotEmpty) {
        final qLower = query.toLowerCase();
        itineraries = itineraries.where((it) =>
            it.title.toLowerCase().contains(qLower) || it.destination.toLowerCase().contains(qLower)).take(limit).toList();
      }
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
      final res = await _client.from('itineraries').select('*, profiles!itineraries_author_id_fkey(name)').eq('id', id).maybeSingle();
      if (res == null) return null;

      final it = Itinerary.fromJson(res as Map<String, dynamic>);
      if (checkAccess && it.visibility == 'private' && it.authorId != currentUserId) return null;

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
        // place_id in schema is UUID; Google returns string - omit non-UUID
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
        await _client.from('itinerary_stops').insert({
          ...stopsData[i],
          'itinerary_id': itineraryId,
          'position': i,
        });
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

  static Future<List<Itinerary>> getBookmarkedItineraries(String userId) async {
    try {
      final res = await _client
          .from('bookmarks')
          .select('itinerary_id')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      final ids = (res as List).map((e) => (e as Map)['itinerary_id'] as String).toList();
      if (ids.isEmpty) return [];

      final itRes = await _client.from('itineraries').select('*, profiles!itineraries_author_id_fkey(name)').inFilter('id', ids);
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
          .select('*, profiles!itineraries_author_id_fkey(name)')
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
      var q = _client.from('itineraries').select('*, profiles!itineraries_author_id_fkey(name)').eq('author_id', userId);
      if (publicOnly) q = q.eq('visibility', 'public');
      final res = await q.order('created_at', ascending: false);
      return (res as List).map((e) => Itinerary.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      Analytics.logEvent('user_itineraries_fetch_error', {'error': e.toString()});
      rethrow;
    }
  }

  // --- Follows & Feed ---
  static Future<void> followUser(String followerId, String followingId) async {
    if (followerId == followingId) return;
    try {
      await _client.from('follows').upsert({'follower_id': followerId, 'following_id': followingId}, onConflict: 'follower_id,following_id');
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

  static Future<int> getFollowerCount(String userId) async {
    try {
      final res = await _client.from('follows').select('follower_id').eq('following_id', userId);
      return (res as List).length;
    } catch (e) {
      return 0;
    }
  }

  static Future<int> getTripsCount(String userId) async {
    try {
      final res = await _client.from('itineraries').select('id').eq('author_id', userId);
      return (res as List).length;
    } catch (e) {
      return 0;
    }
  }

  static Future<List<Itinerary>> getFeedItineraries(String userId, {int limit = 50}) async {
    try {
      final followedIds = await getFollowedIds(userId);
      final authorIds = [...followedIds, userId];
      if (authorIds.isEmpty) return [];

      final res = await _client
          .from('itineraries')
          .select('*, profiles!itineraries_author_id_fkey(name)')
          .inFilter('author_id', authorIds)
          .order('created_at', ascending: false)
          .limit(limit);

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
      Analytics.logEvent('feed_fetch_error', {'error': e.toString()});
      rethrow;
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
