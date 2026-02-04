import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../data/countries.dart' show countries;

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
    String? lang,
  }) async {
    if (input.trim().length < 2) return [];

    try {
      final params = <String, String>{
        'q': input.trim(),
        'limit': '15',
      };
      if (lang != null && lang.isNotEmpty) {
        params['lang'] = lang;
      }
      String? bboxStr;
      if (countryCodes != null && countryCodes.isNotEmpty) {
        bboxStr = _bboxForCountries(countryCodes);
        params['bbox'] = bboxStr;
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
      var results = features.map((f) => PlacePrediction.fromPhoton(f as Map<String, dynamic>)).toList();
      if (countryCodes != null && countryCodes.isNotEmpty) {
        final allowed = countryCodes.map((c) => c.toUpperCase()).toSet();
        results = results.where((p) {
          final code = p.countryCode;
          if (code == null || code.isEmpty) return false;
          return allowed.contains(code.toUpperCase());
        }).toList();
      }
      return results;
    } catch (e) {
      debugPrint('PlacesService search exception: $e');
      return [];
    }
  }

  static const Map<String, String> _countryBboxes = {
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
    'GT': '-92.2,13.7,-88.2,17.8',
    'BO': '-69.6,-22.9,-57.5,-9.7',
    'CL': '-75.6,-55.9,-66.5,-17.5',
    'MA': '-13.2,27.6,-0.9,35.9',
    'ZA': '16.3,-34.8,32.9,-22.1',
    'TZ': '29.3,-11.7,40.4,-0.9',
    'GR': '19.4,34.8,29.6,41.7',
    'MX': '-118.4,14.5,-86.7,32.7',
    'PE': '-81.3,-18.3,-68.7,-0.0',
    'EC': '-81.0,-5.0,-75.2,1.4',
    'CO': '-79.0,-4.2,-66.9,12.5',
    'AR': '-73.6,-55.1,-53.6,-21.8',
    'BR': '-73.9,-33.8,-34.8,5.3',
    'IN': '68.2,8.0,97.4,35.5',
    'TH': '97.4,5.6,105.6,20.5',
    'ID': '95.0,-11.0,141.0,6.0',
    'NZ': '166.0,-47.3,179.0,-34.4',
    'EG': '24.7,22.0,36.9,31.7',
    'PT': '-9.5,37.0,-6.0,42.2',
    'NL': '3.4,50.8,7.2,53.5',
    'BE': '2.5,49.5,6.4,51.5',
    'PL': '14.1,49.0,24.2,54.8',
    'CZ': '12.1,48.6,18.9,51.0',
    'CA': '-141.0,41.7,-52.6,83.1',
  };

  /// Returns a single bbox that encompasses all selected countries so results are within those countries.
  static String _bboxForCountries(List<String> codes) {
    if (codes.isEmpty) return '-180,-90,180,90';
    final parsed = <List<double>>[];
    for (final c in codes) {
      final bboxStr = _countryBboxes[c.toUpperCase()];
      if (bboxStr == null) continue;
      final parts = bboxStr.split(',');
      if (parts.length != 4) continue;
      final left = double.tryParse(parts[0]);
      final bottom = double.tryParse(parts[1]);
      final right = double.tryParse(parts[2]);
      final top = double.tryParse(parts[3]);
      if (left != null && bottom != null && right != null && top != null) {
        parsed.add([left, bottom, right, top]);
      }
    }
    if (parsed.isEmpty) return '-180,-90,180,90';
    double left = parsed.first[0], bottom = parsed.first[1], right = parsed.first[2], top = parsed.first[3];
    for (final p in parsed.skip(1)) {
      if (p[0] < left) left = p[0];
      if (p[1] < bottom) bottom = p[1];
      if (p[2] > right) right = p[2];
      if (p[3] > top) top = p[3];
    }
    return '$left,$bottom,$right,$top';
  }

  /// True if (lat, lng) is inside bbox string "left,bottom,right,top" (lon,lat,lon,lat).
  static bool _pointInBbox(double lat, double lng, String bboxStr) {
    final parts = bboxStr.split(',');
    if (parts.length != 4) return false;
    final left = double.tryParse(parts[0]);
    final bottom = double.tryParse(parts[1]);
    final right = double.tryParse(parts[2]);
    final top = double.tryParse(parts[3]);
    if (left == null || bottom == null || right == null || top == null) return false;
    return lng >= left && lng <= right && lat >= bottom && lat <= top;
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
      case 'volcano':
      case 'volcanoes':
        return 'natural:volcano';
      case 'mountain':
      case 'mountains':
      case 'peak':
        return 'natural:peak';
      case 'desert':
      case 'deserts':
        return 'natural:sand';
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
  /// ISO 3166-1 alpha-2 country code (e.g. GT, BO) for filtering by selected countries.
  final String? countryCode;

  PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    this.secondaryText,
    this.lat,
    this.lng,
    this.osmUrl,
    this.countryCode,
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
    final countryCodeRaw = props['countrycode'] as String?;
    final countryCode = countryCodeRaw != null && countryCodeRaw.isNotEmpty
        ? countryCodeRaw.toUpperCase()
        : _countryNameToCode(country);
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
      countryCode: countryCode,
    );
  }

  static String? _countryNameToCode(String name) {
    if (name.isEmpty) return null;
    final lower = name.trim().toLowerCase();
    for (final e in countries.entries) {
      if (e.value.toLowerCase() == lower) return e.key;
    }
    return null;
  }
}
