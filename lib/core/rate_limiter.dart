// Rate limiting for sensitive operations (OWASP: prevent abuse / DoS).
// Client-side limits reduce blast to Supabase; enable server-side (Supabase Pro / Edge Functions) for IP-based limits.

import 'dart:collection';

/// Thrown when rate limit is exceeded. UI should show a friendly "Too many requests" message.
class RateLimitExceededException implements Exception {
  final String action;
  final Duration retryAfter;

  RateLimitExceededException(this.action, this.retryAfter);

  @override
  String toString() => 'RateLimitExceeded: $action (retry after ${retryAfter.inSeconds}s)';
}

/// Per-action, in-memory rate limiter. Uses sliding window of timestamps.
/// Sensible defaults: avoid hammering Supabase and give users clear 429-style feedback.
class RateLimiter {
  RateLimiter._();
  static final RateLimiter instance = RateLimiter._();

  final Map<String, Queue<DateTime>> _windows = {};
  static const int _maxEntries = 100;
  static const Duration _windowDuration = Duration(minutes: 1);

  /// [action] e.g. 'auth_sign_in', 'follow', 'create_itinerary'. [maxPerMinute] default varies by action.
  /// Returns normally if under limit; throws [RateLimitExceededException] if over.
  void checkLimit(String action, {required int maxPerMinute}) {
    final now = DateTime.now();
    final key = action;
    _prune(key, now);

    var queue = _windows[key];
    if (queue == null) {
      queue = Queue<DateTime>();
      _windows[key] = queue;
    }

    if (queue.length >= maxPerMinute) {
      final oldest = queue.first;
      final retryAfter = _windowDuration - now.difference(oldest);
      throw RateLimitExceededException(action, retryAfter.isNegative ? Duration.zero : retryAfter);
    }

    queue.add(now);
    _evictOldKeys();
  }

  void _prune(String key, DateTime now) {
    final queue = _windows[key];
    if (queue == null) return;
    final cutoff = now.subtract(_windowDuration);
    while (queue.isNotEmpty && queue.first.isBefore(cutoff)) {
      queue.removeFirst();
    }
    if (queue.isEmpty) _windows.remove(key);
  }

  void _evictOldKeys() {
    if (_windows.length <= _maxEntries) return;
    final keys = _windows.keys.toList()..sort();
    for (var i = 0; i < keys.length - _maxEntries; i++) {
      _windows.remove(keys[i]);
    }
  }
}

/// Action names and default limits (per minute). Align with Supabase RLS; server-side rate limiting recommended.
class RateLimitActions {
  RateLimitActions._();

  static const authSignIn = 'auth_sign_in';
  static const authSignUp = 'auth_sign_up';
  static const follow = 'follow';
  static const createItinerary = 'create_itinerary';
  static const updateItinerary = 'update_itinerary';
  static const bookmark = 'bookmark';
  static const like = 'like';
  static const updateProfile = 'update_profile';
  static const searchProfiles = 'search_profiles';
  static const searchItineraries = 'search_itineraries';
  static const addPastCity = 'add_past_city';
  static const addTopSpot = 'add_top_spot';

  static const int defaultAuthPerMinute = 10;
  static const int defaultMutationPerMinute = 30;
  static const int defaultSearchPerMinute = 60;
}
