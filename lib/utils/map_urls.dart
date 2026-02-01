import 'package:flutter/foundation.dart';
import '../models/itinerary.dart';
import '../models/user_city.dart';

/// Builds map URLs for opening locations in Google Maps or Apple Maps.
/// Used by Itinerary Detail (stops) and City Detail (top spots).
class MapUrls {
  MapUrls._();

  /// Builds the map URL for an itinerary stop (location or venue). Uses Google Maps
  /// on all platforms (opens Google Maps app on iOS if installed, otherwise browser).
  /// Apple Maps doesn't support place_id, so Google Maps ensures correct location.
  static Uri buildItineraryStopMapUrl(
    ItineraryStop stop, {
    TargetPlatform? platform,
    bool isWeb = kIsWeb,
  }) {
    final googlePlaceId = stop.googlePlaceId ??
        (stop.placeId != null && stop.placeId!.startsWith('ChIJ') ? stop.placeId : null) ??
        _parsePlaceIdFromUrl(stop.externalUrl);

    return _googleMapsSearchUrl(stop.name, googlePlaceId);
  }

  static Uri _googleMapsSearchUrl(String name, String? googlePlaceId) {
    final nameEnc = Uri.encodeComponent(name);
    if (googlePlaceId != null && googlePlaceId.isNotEmpty) {
      return Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$nameEnc&query_place_id=${Uri.encodeComponent(googlePlaceId)}',
      );
    }
    return Uri.parse('https://www.google.com/maps/search/?api=1&query=$nameEnc');
  }

  /// Builds the map URL for a city top spot. Uses Google Maps search format
  /// with api=1 and query_place_id on all platforms (opens Google Maps app on iOS
  /// if installed, otherwise browser). Apple Maps doesn't support place_id, so
  /// Google Maps ensures correct location on all platforms.
  static Uri? buildTopSpotMapUrl(
    UserTopSpot spot, {
    TargetPlatform? platform,
    bool isWeb = kIsWeb,
  }) {
    // Parse place_id from locationUrl (handles legacy and new formats)
    final placeId = _parsePlaceIdFromUrl(spot.locationUrl);

    if (placeId != null && placeId.isNotEmpty) {
      return _googleMapsSearchUrl(spot.name, placeId);
    }
    // Stored URL already in correct format (api=1, query_place_id) - use as-is
    if (spot.locationUrl != null && spot.locationUrl!.trim().isNotEmpty) {
      final uri = Uri.tryParse(spot.locationUrl!);
      if (uri != null &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.contains('google.com') &&
          uri.path.contains('/maps/') &&
          uri.queryParameters['api'] == '1') {
        return uri;
      }
    }
    return _googleMapsSearchUrl(spot.name, null);
  }

  /// Extracts place_id from URL. Handles:
  /// - Legacy: /place/?q=place_id:ChIJ...
  /// - New format: /maps/search/?api=1&query=...&query_place_id=ChIJ...
  static String? _parsePlaceIdFromUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;

    // New format: query_place_id=ChIJ... (or other Place ID formats)
    final uri = Uri.tryParse(url);
    if (uri != null) {
      final queryPlaceId = uri.queryParameters['query_place_id'];
      if (queryPlaceId != null && queryPlaceId.trim().length > 5) {
        return queryPlaceId.trim();
      }
    }

    // Legacy format: place_id:ChIJ... (in /place/?q=place_id:...)
    const prefix = 'place_id:';
    final idx = url.indexOf(prefix);
    if (idx >= 0) {
      final start = idx + prefix.length;
      final rest = url.substring(start);
      final end = rest.contains('&') ? rest.indexOf('&') : rest.length;
      final id = rest.substring(0, end).trim();
      if (id.length > 5) return id;
    }
    return null;
  }

  /// Builds Google Maps search URL when saving a top spot (with api=1).
  /// Used when saving top spots in City Detail.
  static String mapUrlFromPlaceId(String placeId, String placeName) {
    final nameEnc = Uri.encodeComponent(placeName);
    return 'https://www.google.com/maps/search/?api=1&query=$nameEnc&query_place_id=${Uri.encodeComponent(placeId)}';
  }
}
