import '../models/itinerary.dart';
import '../models/profile.dart';

/// In-memory cache for home screen data. Persists across tab switches.
class HomeCache {
  static String? _userId;
  static Profile? _profile;
  static List<Itinerary> _myItineraries = [];
  static int _tripsCount = 0;
  static int _followersCount = 0;
  static List<Itinerary> _feed = [];
  static Map<String, bool> _bookmarked = {};
  static Map<String, bool> _liked = {};

  static bool hasData(String userId) => _userId == userId && (_profile != null || _feed.isNotEmpty || _myItineraries.isNotEmpty);

  static void put(
    String userId, {
    Profile? profile,
    List<Itinerary>? myItineraries,
    int? tripsCount,
    int? followersCount,
    List<Itinerary>? feed,
    Map<String, bool>? bookmarked,
    Map<String, bool>? liked,
  }) {
    _userId = userId;
    if (profile != null) _profile = profile;
    if (myItineraries != null) _myItineraries = myItineraries;
    if (tripsCount != null) _tripsCount = tripsCount;
    if (followersCount != null) _followersCount = followersCount;
    if (feed != null) _feed = feed;
    if (bookmarked != null) _bookmarked = Map.from(bookmarked);
    if (liked != null) _liked = Map.from(liked);
  }

  static ({Profile? profile, List<Itinerary> myItineraries, int tripsCount, int followersCount, List<Itinerary> feed, Map<String, bool> bookmarked, Map<String, bool> liked}) get(String userId) {
    if (_userId != userId) return (profile: null, myItineraries: [], tripsCount: 0, followersCount: 0, feed: [], bookmarked: {}, liked: {});
    return (
      profile: _profile,
      myItineraries: List.from(_myItineraries),
      tripsCount: _tripsCount,
      followersCount: _followersCount,
      feed: List.from(_feed),
      bookmarked: Map.from(_bookmarked),
      liked: Map.from(_liked),
    );
  }

  static void clear([String? userId]) {
    if (userId == null || _userId == userId) {
      _userId = null;
      _profile = null;
      _myItineraries = [];
      _tripsCount = 0;
      _followersCount = 0;
      _feed = [];
      _bookmarked = {};
      _liked = {};
    }
  }
}
