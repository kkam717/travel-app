import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:share_plus/share_plus.dart';

/// Base URL for shareable app links (e.g. https://travel-app-rpp7.vercel.app).
/// Set APP_URL in .env to override; otherwise uses SUPABASE_AUTH_REDIRECT_URL.
String get shareBaseUrl {
  final url = dotenv.env['APP_URL']?.trim() ??
      dotenv.env['SUPABASE_AUTH_REDIRECT_URL']?.trim();
  if (url != null && url.isNotEmpty) return url.replaceFirst(RegExp(r'/$'), '');
  return 'https://travel-app-rpp7.vercel.app';
}

/// Builds a shareable link for an itinerary (e.g. /itinerary/abc-123).
String itineraryShareLink(String itineraryId) {
  return '$shareBaseUrl/itinerary/$itineraryId';
}

/// Opens the native share sheet with the itinerary link.
Future<void> shareItineraryLink(String itineraryId, {String? title}) async {
  final link = itineraryShareLink(itineraryId);
  await Share.share(
    link,
    subject: title != null && title.isNotEmpty ? title : null,
  );
}

/// Builds a shareable link for a user profile (e.g. /author/abc-123).
String profileShareLink(String userId) {
  return '$shareBaseUrl/author/$userId';
}

/// Opens the native share sheet with the profile link.
Future<void> shareProfileLink(String userId, {String? name}) async {
  final link = profileShareLink(userId);
  await Share.share(
    link,
    subject: name != null && name.isNotEmpty ? name : null,
  );
}
