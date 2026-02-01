import '../models/itinerary.dart';
import '../models/profile.dart';
import '../models/user_city.dart';

/// In-memory cache for profile screen data. Persists across tab switches.
class ProfileCache {
  static String? _userId;
  static Profile? _profile;
  static List<Itinerary> _myItineraries = [];
  static List<UserPastCity> _pastCities = [];
  static int _followersCount = 0;
  static int _followingCount = 0;

  static bool hasData(String userId) => _userId == userId;

  static void put(
    String userId, {
    required Profile? profile,
    required List<Itinerary> myItineraries,
    required List<UserPastCity> pastCities,
    required int followersCount,
    required int followingCount,
  }) {
    _userId = userId;
    _profile = profile;
    _myItineraries = myItineraries;
    _pastCities = pastCities;
    _followersCount = followersCount;
    _followingCount = followingCount;
  }

  /// Partial update for profile and past cities (e.g. from ProfileStatsScreen).
  static void updateProfileAndPastCities(String userId, Profile? profile, List<UserPastCity> pastCities) {
    if (_userId != userId) return;
    if (profile != null) _profile = profile;
    _pastCities = pastCities;
  }

  /// Partial update for profile only (e.g. visited countries from map screen).
  static void updateProfile(String userId, Profile? profile) {
    if (_userId != userId) return;
    if (profile != null) _profile = profile;
  }

  /// Partial update for visited countries (e.g. from map screen).
  static void updateVisitedCountries(String userId, List<String> visitedCountries) {
    if (_userId != userId || _profile == null) return;
    _profile = _profile!.copyWith(visitedCountries: visitedCountries);
  }

  static ({
    Profile? profile,
    List<Itinerary> myItineraries,
    List<UserPastCity> pastCities,
    int followersCount,
    int followingCount,
  }) get(String userId) {
    if (_userId != userId) {
      return (
        profile: null,
        myItineraries: [],
        pastCities: [],
        followersCount: 0,
        followingCount: 0,
      );
    }
    return (
      profile: _profile,
      myItineraries: List.from(_myItineraries),
      pastCities: List.from(_pastCities),
      followersCount: _followersCount,
      followingCount: _followingCount,
    );
  }

  static void clear([String? userId]) {
    if (userId == null || _userId == userId) {
      _userId = null;
      _profile = null;
      _myItineraries = [];
      _pastCities = [];
      _followersCount = 0;
      _followingCount = 0;
    }
  }
}
