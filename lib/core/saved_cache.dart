import '../models/itinerary.dart';

/// In-memory cache for saved screen data. Persists across tab switches.
class SavedCache {
  static String? _userId;
  static List<Itinerary> _bookmarked = [];
  static List<Itinerary> _planning = [];

  static bool hasData(String userId) => _userId == userId;

  static void put(
    String userId, {
    required List<Itinerary> bookmarked,
    required List<Itinerary> planning,
  }) {
    _userId = userId;
    _bookmarked = bookmarked;
    _planning = planning;
  }

  static ({List<Itinerary> bookmarked, List<Itinerary> planning}) get(String userId) {
    if (_userId != userId) return (bookmarked: [], planning: []);
    return (
      bookmarked: List.from(_bookmarked),
      planning: List.from(_planning),
    );
  }

  static void clear([String? userId]) {
    if (userId == null || _userId == userId) {
      _userId = null;
      _bookmarked = [];
      _planning = [];
    }
  }
}
