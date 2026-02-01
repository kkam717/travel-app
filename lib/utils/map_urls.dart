import 'package:flutter/foundation.dart';
import '../models/itinerary.dart';
import '../models/user_city.dart';

/// Builds map URLs for opening locations in Google Maps (free public URLs, no API key).
/// Used by Itinerary Detail (stops) and City Detail (top spots).
class MapUrls {
  MapUrls._();

  /// Builds the map URL for an itinerary stop (location or venue).
  static Uri buildItineraryStopMapUrl(
    ItineraryStop stop, {
    TargetPlatform? platform,
    bool isWeb = kIsWeb,
  }) {
    return _googleMapsUrl(stop.name, stop.lat, stop.lng);
  }

  static Uri _googleMapsUrl(String name, double? lat, double? lng) {
    final nameTrimmed = name.trim();
    final nameEnc = nameTrimmed.isNotEmpty ? Uri.encodeComponent(nameTrimmed) : null;
    // Prefer place name search so Google Maps shows the actual place (details, reviews), not just coords
    if (nameEnc != null && nameEnc.isNotEmpty) {
      if (lat != null && lng != null) {
        // Search by name, centered on coords - shows place with full details
        return Uri.parse('https://www.google.com/maps/search/$nameEnc/@$lat,$lng,17z');
      }
      return Uri.parse('https://www.google.com/maps/search/$nameEnc');
    }
    if (lat != null && lng != null) {
      return Uri.parse('https://www.google.com/maps?q=$lat,$lng');
    }
    return Uri.parse('https://www.google.com/maps');
  }

  /// Builds the map URL for a city top spot.
  static Uri? buildTopSpotMapUrl(
    UserTopSpot spot, {
    TargetPlatform? platform,
    bool isWeb = kIsWeb,
  }) {
    // Top spots don't store lat/lng; use name from stored URL or spot name
    return _googleMapsUrl(spot.name, null, null);
  }

  /// Builds Google Maps URL when saving a place. Used when saving top spots in City Detail.
  static String mapUrlFromPlace(String placeName, double? lat, double? lng, String? osmUrl) {
    final nameTrimmed = placeName.trim();
    if (nameTrimmed.isNotEmpty) {
      final nameEnc = Uri.encodeComponent(nameTrimmed);
      if (lat != null && lng != null) {
        return 'https://www.google.com/maps/search/$nameEnc/@$lat,$lng,17z';
      }
      return 'https://www.google.com/maps/search/$nameEnc';
    }
    if (lat != null && lng != null) {
      return 'https://www.google.com/maps?q=$lat,$lng';
    }
    return 'https://www.google.com/maps';
  }
}
