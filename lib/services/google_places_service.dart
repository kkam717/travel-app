import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Google Places API (New) service for autocomplete and place details
class GooglePlacesService {
  static String? get _apiKey => dotenv.env['GOOGLE_API_KEY'];
  static const _autocompleteUrl = 'https://places.googleapis.com/v1/places:autocomplete';
  static const _placeDetailsBase = 'https://places.googleapis.com/v1/places';

  /// Autocomplete with optional location bias from trip destination countries or a specific point
  static Future<List<PlacePrediction>> autocomplete(
    String input, {
    List<String>? countryCodes,
    String? placeType,
    (double, double)? locationLatLng, // Override: bias toward this point (e.g. day's city)
  }) async {
    final key = _apiKey;
    if (key == null || key.isEmpty) {
      debugPrint('GooglePlaces: GOOGLE_API_KEY missing or empty in .env');
      return [];
    }
    if (input.trim().length < 2) return [];

    try {
      final body = <String, dynamic>{
        'input': input.trim(),
      };

      // Location bias: specific point (e.g. day's city) or trip destination countries
      if (locationLatLng != null) {
        body['locationBias'] = {
          'circle': {
            'center': {'latitude': locationLatLng.$1, 'longitude': locationLatLng.$2},
            'radius': 15000.0, // 15km around the city - filter to places in/near the city
          },
        };
      } else if (countryCodes != null && countryCodes.isNotEmpty) {
        final codes = countryCodes.map((c) => c.toUpperCase()).toSet().toList();
        body['includedRegionCodes'] = codes.take(15).toList(); // API max 15
        final center = _centerForCountries(countryCodes);
        body['locationBias'] = {
          'circle': {
            'center': {'latitude': center.$1, 'longitude': center.$2},
            'radius': 50000.0, // API max 50km; biases results toward trip destination
          },
        };
      }

      if (placeType != null && placeType.isNotEmpty) {
        body['includedPrimaryTypes'] = [placeType];
      }

      final res = await http.post(
        Uri.parse(_autocompleteUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': key,
        },
        body: jsonEncode(body),
      );

      if (res.statusCode != 200) {
        debugPrint('GooglePlaces autocomplete error: ${res.statusCode} ${res.body}');
        return [];
      }

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final suggestions = json['suggestions'] as List<dynamic>? ?? [];
      final predictions = <PlacePrediction>[];
      for (final s in suggestions) {
        final map = s as Map<String, dynamic>;
        final placePred = map['placePrediction'] as Map<String, dynamic>?;
        if (placePred != null) {
          predictions.add(PlacePrediction.fromNewApi(placePred));
        }
      }
      return predictions;
    } catch (e) {
      debugPrint('GooglePlaces autocomplete exception: $e');
      return [];
    }
  }

  static (double, double) _centerForCountries(List<String> codes) {
    // Approximate centers for common countries (lat, lng)
    const centers = {
      'CH': (46.8, 8.2),   // Switzerland
      'AT': (47.5, 13.3),  // Austria
      'FR': (46.2, 2.2),   // France
      'IT': (41.9, 12.5),  // Italy
      'ES': (40.4, -3.7),  // Spain
      'DE': (51.2, 10.5),  // Germany
      'GB': (54.0, -2.0),  // UK
      'JP': (36.2, 138.3), // Japan
      'US': (39.8, -98.6), // USA
      'AU': (-25.3, 133.8),// Australia
    };
    for (final c in codes) {
      final center = centers[c.toUpperCase()];
      if (center != null) return center;
    }
    return (46.0, 8.0); // Default: central Europe
  }

  /// Geocode an address (e.g. city name) and return the country code (ISO 3166-1 alpha-2).
  static Future<String?> geocodeToCountryCode(String address) async {
    final key = _apiKey;
    if (key == null || key.isEmpty || address.trim().isEmpty) return null;
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?address=${Uri.encodeComponent(address.trim())}'
        '&key=$key',
      );
      final res = await http.get(url);
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final results = json['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;
      final components = (results.first as Map<String, dynamic>)['address_components'] as List<dynamic>?;
      if (components == null) return null;
      for (final c in components) {
        final comp = c as Map<String, dynamic>;
        final types = comp['types'] as List<dynamic>? ?? [];
        if (types.contains('country')) {
          final code = comp['short_name'] as String?;
          return code?.toUpperCase();
        }
      }
      return null;
    } catch (e) {
      debugPrint('GooglePlaces geocodeToCountryCode exception: $e');
      return null;
    }
  }

  /// Geocode an address (e.g. city name) to lat/lng for location bias
  static Future<(double, double)?> geocodeAddress(String address) async {
    final key = _apiKey;
    if (key == null || key.isEmpty || address.trim().isEmpty) return null;
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?address=${Uri.encodeComponent(address.trim())}'
        '&key=$key',
      );
      final res = await http.get(url);
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final results = json['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;
      final loc = (results.first as Map<String, dynamic>)['geometry']?['location'] as Map<String, dynamic>?;
      if (loc == null) return null;
      final lat = (loc['lat'] as num?)?.toDouble();
      final lng = (loc['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;
      return (lat, lng);
    } catch (e) {
      debugPrint('GooglePlaces geocode exception: $e');
      return null;
    }
  }

  static Future<PlaceDetails?> getDetails(String placeId) async {
    final key = _apiKey;
    if (key == null || key.isEmpty) return null;

    try {
      final url = '$_placeDetailsBase/${Uri.encodeComponent(placeId)}';
      final res = await http.get(
        Uri.parse(url),
        headers: {
          'X-Goog-Api-Key': key,
          'X-Goog-FieldMask': 'id,displayName,location',
        },
      );

      if (res.statusCode != 200) {
        debugPrint('GooglePlaces getDetails error: ${res.statusCode} ${res.body}');
        return null;
      }

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return PlaceDetails.fromNewApi(json);
    } catch (e) {
      debugPrint('GooglePlaces getDetails exception: $e');
      return null;
    }
  }
}

class PlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String? secondaryText;

  PlacePrediction({required this.placeId, required this.description, required this.mainText, this.secondaryText});

  factory PlacePrediction.fromNewApi(Map<String, dynamic> json) {
    final placeId = json['placeId'] as String? ?? json['place']?.toString().replaceFirst('places/', '') ?? '';
    final text = json['text'] as Map<String, dynamic>?;
    final fullText = text?['text'] as String? ?? '';
    final structured = json['structuredFormat'] as Map<String, dynamic>?;
    final mainText = structured?['mainText']?['text'] as String? ?? fullText;
    final secondaryText = structured?['secondaryText']?['text'] as String?;
    return PlacePrediction(
      placeId: placeId,
      description: fullText,
      mainText: mainText,
      secondaryText: secondaryText,
    );
  }
}

class PlaceDetails {
  final String name;
  final String? formattedAddress;
  final double? lat;
  final double? lng;
  final List<String> types;

  PlaceDetails({required this.name, this.formattedAddress, this.lat, this.lng, this.types = const []});

  factory PlaceDetails.fromNewApi(Map<String, dynamic> json) {
    final displayName = json['displayName'] as Map<String, dynamic>?;
    final name = displayName?['text'] as String? ?? '';
    final loc = json['location'] as Map<String, dynamic>?;
    final lat = (loc?['latitude'] as num?)?.toDouble();
    final lng = (loc?['longitude'] as num?)?.toDouble();
    return PlaceDetails(
      name: name,
      formattedAddress: json['formattedAddress'] as String?,
      lat: lat,
      lng: lng,
      types: [],
    );
  }
}
