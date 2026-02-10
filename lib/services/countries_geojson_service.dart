import 'dart:convert';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Fetches Natural Earth 110m country polygons (lightweight, smooth rendering).
/// Uses simplified geometry for fast map performance.
class CountriesGeoJsonService {
  static const _url =
      'https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_110m_admin_0_countries.geojson';

  static String? _cachedJson;

  /// Alternate ISO codes that Natural Earth does not use; map to the code used in the GeoJSON.
  static const Map<String, String> _isoAliases = {
    'UK': 'GB', // United Kingdom
  };

  static Set<String> _normalizeCodes(Set<String> isoCodes) {
    final out = <String>{};
    for (final c in isoCodes) {
      final upper = c.trim().toUpperCase();
      if (upper.isEmpty) continue;
      out.add(_isoAliases[upper] ?? upper);
    }
    return out;
  }

  /// Extracts ISO 3166-1 alpha-2 from feature properties. Natural Earth uses -99 or compound codes (e.g. CN-TW) for some countries; we fall back to ISO_A2_EH then WB_A2 so they still appear in the list and on the map. Covered by fallback: France (FR), Norway (NO), Taiwan (TW), Kosovo (XK). Northern Cyprus and Somaliland have no standard 2-letter code in this dataset and remain excluded.
  static String? _isoFromProps(Map<String, dynamic> props) {
    final primary = (props['ISO_A2'] ?? props['iso_a2'])?.toString().trim().toUpperCase();
    if (primary != null && primary != '-99' && primary.length == 2) return primary;
    final fallback = (props['ISO_A2_EH'] ?? props['iso_a2_eh'] ?? props['WB_A2'] ?? props['wb_a2'])?.toString().trim().toUpperCase();
    if (fallback != null && fallback != '-99' && fallback.length == 2) return fallback;
    return null;
  }

  /// Fetches GeoJSON (cached after first load) and returns polygons for visited country codes.
  static Future<List<Polygon>> getPolygonsForCountries(Set<String> isoCodes) async {
    final withCodes = await getPolygonsWithCountryCodes(isoCodes);
    return withCodes.map((e) => e.$2).toList();
  }

  /// Same as [getPolygonsForCountries] but returns (countryCode, polygon) pairs for tap hit-testing.
  static Future<List<(String, Polygon)>> getPolygonsWithCountryCodes(Set<String> isoCodes) async {
    if (isoCodes.isEmpty) return [];
    final codes = _normalizeCodes(isoCodes);

    String json;
    if (_cachedJson != null) {
      json = _cachedJson!;
    } else {
      final resp = await http.get(Uri.parse(_url));
      if (resp.statusCode != 200) throw Exception('Failed to load countries GeoJSON');
      json = resp.body;
      _cachedJson = json;
    }

    final data = jsonDecode(json) as Map<String, dynamic>;
    final features = data['features'] as List<dynamic>? ?? [];
    final result = <(String, Polygon)>[];

    for (final f in features) {
      final props = f['properties'] as Map<String, dynamic>? ?? {};
      final iso = _isoFromProps(props);
      if (iso == null || !codes.contains(iso)) continue;

      final geom = f['geometry'] as Map<String, dynamic>?;
      if (geom == null) continue;

      final type = (geom['type'] ?? '').toString();
      final coords = geom['coordinates'];

      if (type == 'Polygon' && coords is List) {
        final rings = _parsePolygonCoords(coords);
        if (rings.isNotEmpty) result.add((iso, _makePolygon(rings)));
      } else if (type == 'MultiPolygon' && coords is List) {
        for (final poly in coords) {
          if (poly is! List) continue;
          final rings = _parsePolygonCoords(poly);
          if (rings.isNotEmpty) result.add((iso, _makePolygon(rings)));
        }
      }
    }
    return result;
  }

  /// Ray-casting: true if [point] is inside the polygon defined by [ring] (exterior, no holes).
  static bool pointInPolygon(LatLng point, List<LatLng> ring) {
    if (ring.length < 3) return false;
    final lat = point.latitude;
    final lng = point.longitude;
    int crossings = 0;
    final n = ring.length;
    for (int i = 0, j = n - 1; i < n; j = i++) {
      final vi = ring[i];
      final vj = ring[j];
      if ((vi.latitude > lat) == (vj.latitude > lat)) continue;
      final t = (lat - vj.latitude) / (vi.latitude - vj.latitude);
      final x = vj.longitude + t * (vi.longitude - vj.longitude);
      if (lng < x) crossings++;
    }
    return crossings.isOdd;
  }

  static Polygon _makePolygon(List<List<LatLng>> rings) {
    return Polygon(
      points: rings.first,
      holePointsList: rings.length > 1 ? rings.sublist(1) : null,
      color: Colors.orange.withValues(alpha: 0.5),
      borderColor: Colors.orange.shade400,
      borderStrokeWidth: 1,
    );
  }

  /// Returns polylines for all country borders (exterior rings only). Cached.
  static Future<List<Polyline>> getAllCountryBorderPolylines() async {
    String json;
    if (_cachedJson != null) {
      json = _cachedJson!;
    } else {
      final resp = await http.get(Uri.parse(_url));
      if (resp.statusCode != 200) throw Exception('Failed to load countries GeoJSON');
      json = resp.body;
      _cachedJson = json;
    }

    final data = jsonDecode(json) as Map<String, dynamic>;
    final features = data['features'] as List<dynamic>? ?? [];
    final result = <Polyline>[];

    for (final f in features) {
      final geom = f['geometry'] as Map<String, dynamic>?;
      if (geom == null) continue;

      final type = (geom['type'] ?? '').toString();
      final coords = geom['coordinates'];

      if (type == 'Polygon' && coords is List) {
        final rings = _parsePolygonCoords(coords);
        if (rings.isNotEmpty) {
          result.add(Polyline(
            points: rings.first,
            color: Colors.grey.shade400,
            strokeWidth: 1,
          ));
        }
      } else if (type == 'MultiPolygon' && coords is List) {
        for (final poly in coords) {
          if (poly is! List) continue;
          final rings = _parsePolygonCoords(poly);
          if (rings.isNotEmpty) {
            result.add(Polyline(
              points: rings.first,
              color: Colors.grey.shade400,
              strokeWidth: 1,
            ));
          }
        }
      }
    }
    return result;
  }

  /// GeoJSON: [lng, lat]. Returns list of rings (first = exterior, rest = holes).
  static List<List<LatLng>> _parsePolygonCoords(dynamic coords) {
    if (coords is! List || coords.isEmpty) return [];
    final first = coords.first;
    if (first is List && first.isNotEmpty) {
      final firstItem = first.first;
      if (firstItem is num) {
        return [_ringToLatLngs(coords)];
      }
      return coords.map((r) => _ringToLatLngs(r as List)).where((r) => r.length >= 3).toList();
    }
    return [];
  }

  static List<LatLng> _ringToLatLngs(List<dynamic> ring) {
    final out = <LatLng>[];
    for (final p in ring) {
      if (p is List && p.length >= 2) {
        final lng = (p[0] is num) ? (p[0] as num).toDouble() : double.tryParse(p[0].toString()) ?? 0.0;
        final lat = (p[1] is num) ? (p[1] as num).toDouble() : double.tryParse(p[1].toString()) ?? 0.0;
        out.add(LatLng(lat, lng));
      }
    }
    return out;
  }

  /// Returns a list of (ISO_A2 code, display name) from the same GeoJSON used for the map.
  /// Use this so the edit list and map share one source (no API vs local mismatch).
  static Future<List<MapEntry<String, String>>> getCountryListFromGeoJson() async {
    String json;
    if (_cachedJson != null) {
      json = _cachedJson!;
    } else {
      final resp = await http.get(Uri.parse(_url));
      if (resp.statusCode != 200) throw Exception('Failed to load countries GeoJSON');
      json = resp.body;
      _cachedJson = json;
    }

    final data = jsonDecode(json) as Map<String, dynamic>;
    final features = data['features'] as List<dynamic>? ?? [];
    final result = <MapEntry<String, String>>[];

    for (final f in features) {
      final props = f['properties'] as Map<String, dynamic>? ?? {};
      final iso = _isoFromProps(props);
      if (iso == null) continue;
      final name = (props['NAME'] ?? props['name'] ?? props['ADMIN'] ?? props['admin'] ?? iso).toString().trim();
      if (name.isEmpty) continue;
      result.add(MapEntry(iso, name));
    }
    result.sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
    return result;
  }

  /// Returns bounds encompassing all given country codes (from cached GeoJSON). Use for fitting map to selected countries.
  static Future<LatLngBounds?> getBoundsForCountryCodes(Set<String> isoCodes) async {
    if (isoCodes.isEmpty) return null;
    final codes = _normalizeCodes(isoCodes);

    String json;
    if (_cachedJson != null) {
      json = _cachedJson!;
    } else {
      final resp = await http.get(Uri.parse(_url));
      if (resp.statusCode != 200) return null;
      json = resp.body;
      _cachedJson = json;
    }

    final data = jsonDecode(json) as Map<String, dynamic>;
    final features = data['features'] as List<dynamic>? ?? [];
    final allPoints = <LatLng>[];

    for (final f in features) {
      final props = f['properties'] as Map<String, dynamic>? ?? {};
      final iso = _isoFromProps(props);
      if (iso == null || !codes.contains(iso)) continue;

      final geom = f['geometry'] as Map<String, dynamic>?;
      if (geom == null) continue;

      final type = (geom['type'] ?? '').toString();
      final coords = geom['coordinates'];

      if (type == 'Polygon' && coords is List) {
        for (final ring in _parsePolygonCoords(coords)) {
          allPoints.addAll(ring);
        }
      } else if (type == 'MultiPolygon' && coords is List) {
        for (final poly in coords) {
          if (poly is! List) continue;
          for (final ring in _parsePolygonCoords(poly)) {
            allPoints.addAll(ring);
          }
        }
      }
    }
    if (allPoints.isEmpty) return null;
    return LatLngBounds.fromPoints(allPoints);
  }
}
