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

  /// Fetches GeoJSON (cached after first load) and returns polygons for visited country codes.
  static Future<List<Polygon>> getPolygonsForCountries(Set<String> isoCodes) async {
    if (isoCodes.isEmpty) return [];
    final codes = isoCodes.map((c) => c.toUpperCase()).toSet();

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
    final result = <Polygon>[];

    for (final f in features) {
      final props = f['properties'] as Map<String, dynamic>? ?? {};
      final iso = (props['ISO_A2'] ?? props['iso_a2'])?.toString().trim().toUpperCase();
      if (iso == null || iso == '-99' || iso.isEmpty || !codes.contains(iso)) continue;

      final geom = f['geometry'] as Map<String, dynamic>?;
      if (geom == null) continue;

      final type = (geom['type'] ?? '').toString();
      final coords = geom['coordinates'];

      if (type == 'Polygon' && coords is List) {
        final rings = _parsePolygonCoords(coords);
        if (rings.isNotEmpty) result.add(_makePolygon(rings));
      } else if (type == 'MultiPolygon' && coords is List) {
        for (final poly in coords) {
          if (poly is! List) continue;
          final rings = _parsePolygonCoords(poly);
          if (rings.isNotEmpty) result.add(_makePolygon(rings));
        }
      }
    }
    return result;
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

  /// Returns bounds encompassing all given country codes (from cached GeoJSON). Use for fitting map to selected countries.
  static Future<LatLngBounds?> getBoundsForCountryCodes(Set<String> isoCodes) async {
    if (isoCodes.isEmpty) return null;
    final codes = isoCodes.map((c) => c.toUpperCase()).toSet();

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
      final iso = (props['ISO_A2'] ?? props['iso_a2'])?.toString().trim().toUpperCase();
      if (iso == null || iso == '-99' || iso.isEmpty || !codes.contains(iso)) continue;

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
