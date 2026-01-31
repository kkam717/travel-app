import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/itinerary.dart';

/// Static map image for feed cards. Uses Google Maps Static API.
/// Priority: venue stops (restaurants/bars) → location stops (cities/towns) → geocoded destination.
class StaticMapImage extends StatefulWidget {
  final Itinerary itinerary;
  final double width;
  final double height;
  final Color pathColor;

  const StaticMapImage({
    super.key,
    required this.itinerary,
    this.width = 400,
    this.height = 200,
    this.pathColor = const Color(0xFFEA4335),
  });

  @override
  State<StaticMapImage> createState() => _StaticMapImageState();
}

class _StaticMapImageState extends State<StaticMapImage> {
  String? _geocodedUrl;
  bool _geocoding = false;

  static String? get _apiKey => dotenv.env['GOOGLE_API_KEY'];

  /// All stops with coordinates (locations + venues)
  List<ItineraryStop> get _allStopsWithCoords =>
      widget.itinerary.stops.where((s) => s.lat != null && s.lng != null).toList();

  @override
  void initState() {
    super.initState();
    _buildUrl();
  }

  @override
  void didUpdateWidget(StaticMapImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itinerary.id != widget.itinerary.id ||
        oldWidget.itinerary.stops != widget.itinerary.stops ||
        oldWidget.itinerary.destination != widget.itinerary.destination) {
      _buildUrl();
    }
  }

  void _buildUrl() {
    final url = _buildStaticMapUrl();
    if (url != null) {
      if (mounted) setState(() => _geocodedUrl = url);
      return;
    }
    // No coords - geocode both locations and venues (restaurant/bar/guide) for route line
    final stopsNoCoords = widget.itinerary.stops
        .where((s) => s.lat == null || s.lng == null)
        .toList();
    if (stopsNoCoords.isNotEmpty) {
      _geocodeStops(stopsNoCoords);
    } else {
      _geocodeDestination();
    }
  }

  String? _buildStaticMapUrl() {
    final key = _apiKey;
    if (key == null || key.isEmpty) return null;

    // Use all stops with coords in day/position order (no dedupe - same place on multiple days
    // still contributes to path so route line draws, matching old version behavior)
    final points = _allStopsWithCoords.map((s) => (s.lat!, s.lng!)).toList();

    if (points.isNotEmpty) {
      return _urlForPoints(key, points, path: points.length >= 2);
    }

    return null;
  }

  String _urlForPoints(String key, List<(double, double)> points, {bool path = true}) {
    final w = (widget.width * 2).toInt().clamp(100, 640);
    final h = (widget.height * 2).toInt().clamp(100, 640);
    final r = (widget.pathColor.r * 255).round().clamp(0, 255);
    final g = (widget.pathColor.g * 255).round().clamp(0, 255);
    final b = (widget.pathColor.b * 255).round().clamp(0, 255);
    final rgb = (r << 16) | (g << 8) | b;
    final hex = '0x${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';

    final sb = StringBuffer(
      'https://maps.googleapis.com/maps/api/staticmap?'
      'size=${w}x$h'
      '&scale=2'
      '&maptype=roadmap'
      '&key=$key',
    );

    // Minimalist: just enough to orient (water, roads, city names)
    sb.write('&style=feature:poi|visibility:off');
    sb.write('&style=feature:transit|visibility:off');
    sb.write('&style=feature:landscape|element:geometry.fill|color:0xf8f8f8');
    sb.write('&style=feature:water|element:geometry.fill|color:0xdce8ec');
    sb.write('&style=feature:road|element:geometry|color:0xeeeeee');
    sb.write('&style=feature:road|element:geometry.stroke|color:0xe2e2e2');
    sb.write('&style=feature:road|element:labels|visibility:off');
    sb.write('&style=feature:administrative.locality|element:labels.text.fill|color:0x6b7280');
    sb.write('&style=feature:administrative.locality|element:labels.text.stroke|color:0xffffff');
    sb.write('&style=feature:administrative.neighborhood|visibility:off');

    // Route line only (no pins on static map)
    if (path && points.length >= 2) {
      final pathStr = points.map((p) => '${p.$1},${p.$2}').join('|');
      sb.write('&path=color:$hex|weight:6|geodesic:true|$pathStr');
    }

    // Center and zoom from points
    double minLat = points.first.$1, maxLat = points.first.$1;
    double minLng = points.first.$2, maxLng = points.first.$2;
    for (final p in points) {
      if (p.$1 < minLat) minLat = p.$1;
      if (p.$1 > maxLat) maxLat = p.$1;
      if (p.$2 < minLng) minLng = p.$2;
      if (p.$2 > maxLng) maxLng = p.$2;
    }
    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;
    sb.write('&center=$centerLat,$centerLng');

    // Zoom to show whole route with padding
    final latSpan = (maxLat - minLat).abs();
    final lngSpan = (maxLng - minLng).abs();
    final aspectRatio = w / h;
    final spanRatio = lngSpan / (latSpan > 0 ? latSpan : 0.01);
    // Zoom so entire route just about fits (1.1 = minimal padding)
    final effectiveSpan = aspectRatio > spanRatio
        ? latSpan * 1.1
        : lngSpan * 1.1;
    final span = effectiveSpan.clamp(0.01, 180.0);
    int zoom;
    if (points.length == 1) {
      zoom = 13;
    } else if (span < 0.02) {
      zoom = 14;
    } else if (span < 0.05) {
      zoom = 13;
    } else if (span < 0.1) {
      zoom = 12;
    } else if (span < 0.2) {
      zoom = 11;
    } else if (span < 0.4) {
      zoom = 10;
    } else if (span < 0.8) {
      zoom = 9;
    } else if (span < 2) {
      zoom = 8;
    } else if (span < 5) {
      zoom = 6;
    } else {
      zoom = 5;
    }
    sb.write('&zoom=$zoom');

    return sb.toString();
  }

  Future<void> _geocodeStops(List<ItineraryStop> stops) async {
    final key = _apiKey;
    if (key == null || key.isEmpty) return;

    if (mounted) setState(() => _geocoding = true);
    try {
      final destination = widget.itinerary.destination.trim();
      // Preserve order: locations first (trip flow), then venues (restaurant/bar/guide)
      final locStops = stops.where((s) => s.isLocation).toList();
      final venueStops = stops.where((s) => s.isVenue).toList();
      final orderedStops = [...locStops, ...venueStops];
      final uniqueNames = <String>[];
      final seen = <String>{};
      for (final s in orderedStops) {
        final n = s.name.trim();
        if (n.isNotEmpty && !seen.contains(n)) {
          seen.add(n);
          uniqueNames.add(n);
        }
      }
      final points = <(double, double)>[];
      for (final name in uniqueNames) {
        final address = destination.isNotEmpty ? '$name, $destination' : name;
        final coords = await _geocodeAddress(key, address);
        if (coords != null) {
          points.add(coords);
        }
      }
      if (!mounted) return;
      if (points.isNotEmpty) {
        // For single-location trips, duplicate point so path draws (old version behavior)
        final pts = points.length >= 2 ? points : [...points, points.first];
        setState(() {
          _geocodedUrl = _urlForPoints(key, pts, path: pts.length >= 2);
          _geocoding = false;
        });
      } else {
        _geocodeDestination();
      }
    } catch (e) {
      debugPrint('StaticMapImage geocode error: $e');
      if (mounted) _geocodeDestination();
    }
  }

  Future<(double, double)?> _geocodeAddress(String key, String address) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json'
      '?address=${Uri.encodeComponent(address)}'
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
  }

  Future<void> _geocodeDestination() async {
    final key = _apiKey;
    if (key == null || key.isEmpty) return;
    if (widget.itinerary.destination.trim().isEmpty) return;

    if (mounted) setState(() => _geocoding = true);
    try {
      final coords = await _geocodeAddress(key, widget.itinerary.destination);
      if (!mounted) return;
      if (coords != null) {
        setState(() {
          _geocodedUrl = _urlForPoints(key, [coords], path: false);
          _geocoding = false;
        });
      } else {
        setState(() => _geocoding = false);
      }
    } catch (e) {
      debugPrint('StaticMapImage geocode error: $e');
      if (mounted) setState(() => _geocoding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_geocoding) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary),
          ),
        ),
      );
    }

    if (_geocodedUrl == null) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, size: 40, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 8),
              Text(
                'No map data',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        _geocodedUrl!,
        width: widget.width,
        height: widget.height,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: widget.width,
            height: widget.height,
            color: Colors.grey.shade200,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                  strokeWidth: 2,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Icon(Icons.map_outlined, size: 40, color: Colors.grey.shade500),
          ),
        ),
      ),
    );
  }
}
