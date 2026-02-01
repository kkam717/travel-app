import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Free place search and geocoding using Photon (OSM) and Nominatim.
/// Replaces Google Places API.
class PlacesService {
  static const _photonBase = 'https://photon.komoot.io/api';
  static const _nominatimBase = 'https://nominatim.openstreetmap.org';
  static const _userAgent = 'FootprintTravelApp/1.0';

  /// Search places (cities, venues) via Photon. Returns results with lat/lng - no separate details call.
  static Future<List<PlacePrediction>> search(
    String input, {
    List<String>? countryCodes,
    String? placeType,
    (double, double)? locationLatLng,
  }) async {
    if (input.trim().length < 2) return [];

    try {
      final params = <String, String>{
        'q': input.trim(),
        'limit': '10',
      };
      if (countryCodes != null && countryCodes.isNotEmpty) {
        params['bbox'] = _bboxForCountries(countryCodes);
      }
      if (locationLatLng != null) {
        params['lat'] = locationLatLng.$1.toString();
        params['lon'] = locationLatLng.$2.toString();
      }
      if (placeType != null && placeType.isNotEmpty) {
        params['osm_tag'] = _osmTagForPlaceType(placeType);
      }

      final uri = Uri.parse(_photonBase).replace(queryParameters: params);
      final res = await http.get(uri, headers: {'User-Agent': _userAgent});

      if (res.statusCode != 200) {
        debugPrint('PlacesService Photon error: ${res.statusCode}');
        return [];
      }

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final features = json['features'] as List<dynamic>? ?? [];
      return features.map((f) => PlacePrediction.fromPhoton(f as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('PlacesService search exception: $e');
      return [];
    }
  }

  static String _bboxForCountries(List<String> codes) {
    const bboxes = {
      'CH': '-6.0,45.8,10.5,47.8',
      'AT': '9.5,46.4,17.2,49.0',
      'FR': '-5.1,41.3,9.6,51.1',
      'IT': '6.6,36.6,18.5,47.1',
      'ES': '-9.3,35.9,4.3,43.8',
      'DE': '5.9,47.3,15.0,55.1',
      'GB': '-8.6,49.9,1.8,60.8',
      'JP': '129.5,31.4,145.8,45.5',
      'US': '-125.0,24.5,-66.9,49.4',
      'AU': '113.3,-43.6,153.6,-10.1',
    };
    for (final c in codes) {
      final bbox = bboxes[c.toUpperCase()];
      if (bbox != null) return bbox;
    }
    return '-10,35,30,70'; // Default: Europe
  }

  static String _osmTagForPlaceType(String type) {
    switch (type.toLowerCase()) {
      case 'city':
      case 'cities':
      case '(cities)':
        return 'place:city';
      case 'restaurant':
      case 'restaurants':
        return 'amenity:restaurant';
      case 'bar':
      case 'bars':
        return 'amenity:bar';
      case 'cafe':
      case 'cafes':
        return 'amenity:cafe';
      case 'hotel':
      case 'lodging':
        return 'tourism:hotel';
      case 'museum':
        return 'tourism:museum';
      case 'attraction':
        return 'tourism:attraction';
      case 'eat':
        return 'amenity:restaurant';
      case 'drink':
        return 'amenity:bar';
      case 'date':
      case 'chill':
        return 'tourism:attraction';
      default:
        return '';
    }
  }

  /// Geocode address to country code (ISO 3166-1 alpha-2). Uses Nominatim.
  static Future<String?> geocodeToCountryCode(String address) async {
    if (address.trim().isEmpty) return null;
    try {
      final url = Uri.parse('$_nominatimBase/search')
          .replace(queryParameters: {'q': address.trim(), 'format': 'json', 'limit': '1'});
      final res = await http.get(url, headers: {'User-Agent': _userAgent});
      if (res.statusCode != 200) return null;
      final list = jsonDecode(res.body) as List<dynamic>?;
      if (list == null || list.isEmpty) return null;
      final item = list.first as Map<String, dynamic>;
      final addr = item['address'] as Map<String, dynamic>?;
      if (addr == null) return null;
      final code = addr['country_code'] as String?;
      return code?.toUpperCase();
    } catch (e) {
      debugPrint('PlacesService geocodeToCountryCode: $e');
      return null;
    }
  }

  /// Geocode address to lat/lng. Uses Nominatim. Respect 1 req/sec.
  static Future<(double, double)?> geocodeAddress(String address) async {
    if (address.trim().isEmpty) return null;
    try {
      final url = Uri.parse('$_nominatimBase/search')
          .replace(queryParameters: {'q': address.trim(), 'format': 'json', 'limit': '1'});
      final res = await http.get(url, headers: {'User-Agent': _userAgent});
      if (res.statusCode != 200) return null;
      final list = jsonDecode(res.body) as List<dynamic>?;
      if (list == null || list.isEmpty) return null;
      final item = list.first as Map<String, dynamic>;
      final latVal = item['lat'];
      final lonVal = item['lon'];
      final lat = latVal is num ? latVal.toDouble() : (latVal is String ? double.tryParse(latVal) : null);
      final lon = lonVal is num ? lonVal.toDouble() : (lonVal is String ? double.tryParse(lonVal) : null);
      if (lat == null || lon == null) return null;
      return (lat, lon);
    } catch (e) {
      debugPrint('PlacesService geocodeAddress: $e');
      return null;
    }
  }
}

class PlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String? secondaryText;
  final double? lat;
  final double? lng;
  final String? osmUrl;

  PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    this.secondaryText,
    this.lat,
    this.lng,
    this.osmUrl,
  });

  factory PlacePrediction.fromPhoton(Map<String, dynamic> feature) {
    final props = feature['properties'] as Map<String, dynamic>? ?? {};
    final geom = feature['geometry'] as Map<String, dynamic>?;
    final coords = geom?['coordinates'] as List<dynamic>?;
    // GeoJSON: coordinates are [lon, lat]
    final lng = coords != null && coords.length >= 2 ? (coords[0] as num?)?.toDouble() : null;
    final lat = coords != null && coords.length >= 2 ? (coords[1] as num?)?.toDouble() : null;
    final name = props['name'] as String? ?? '';
    final city = props['city'] as String? ?? props['locality'] as String? ?? props['district'] as String?;
    final country = props['country'] as String? ?? '';
    final street = props['street'] as String?;
    final housenumber = props['housenumber'] as String?;
    final parts = <String>[];
    if (street != null && street.isNotEmpty) {
      if (housenumber != null && housenumber.isNotEmpty) {
        parts.add('$street $housenumber');
      } else {
        parts.add(street);
      }
    }
    if (city != null && city.isNotEmpty) parts.add(city);
    if (country.isNotEmpty) parts.add(country);
    final secondary = parts.isNotEmpty ? parts.join(', ') : null;

    final osmType = props['osm_type'] as String? ?? 'N';
    final osmId = props['osm_id'] as int? ?? 0;
    final osmKey = osmType == 'R' ? 'relation' : (osmType == 'W' ? 'way' : 'node');
    final osmUrl = osmId > 0 ? 'https://www.openstreetmap.org/$osmKey/$osmId' : null;

    final placeId = osmId > 0 ? 'osm:$osmType:$osmId' : 'osm:${name.hashCode}';

    return PlacePrediction(
      placeId: placeId,
      description: secondary ?? name,
      mainText: name,
      secondaryText: secondary,
      lat: lat,
      lng: lng,
      osmUrl: osmUrl,
    );
  }
}
