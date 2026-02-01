import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/itinerary.dart';

/// Static map image for feed cards.
/// Uses Geoapify (free tier) + Nominatim (free). Requires GEOAPIFY_API_KEY.
/// Priority: venue stops → location stops → geocoded destination.
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
    this.pathColor = const Color(0xFF0D9488),
  });

  @override
  State<StaticMapImage> createState() => _StaticMapImageState();
}

class _StaticMapImageState extends State<StaticMapImage> {
  String? _geocodedUrl;
  bool _geocoding = false;

  static String? get _geoapifyKey => dotenv.env['GEOAPIFY_API_KEY'];

  bool get _useGeoapify => (_geoapifyKey ?? '').trim().isNotEmpty;

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
    final points = _allStopsWithCoords.map((s) => (s.lat!, s.lng!)).toList();
    if (points.isEmpty) return null;

    if (_useGeoapify && _geoapifyKey != null) {
      return _buildGeoapifyUrl(points, path: points.length >= 2);
    }
    return null;
  }

  String _buildGeoapifyUrl(List<(double, double)> points, {bool path = true}) {
    final w = (widget.width * 2).toInt().clamp(100, 640);
    final h = (widget.height * 2).toInt().clamp(100, 640);

    double minLat = points.first.$1, maxLat = points.first.$1;
    double minLng = points.first.$2, maxLng = points.first.$2;
    for (final p in points) {
      if (p.$1 < minLat) minLat = p.$1;
      if (p.$1 > maxLat) maxLat = p.$1;
      if (p.$2 < minLng) minLng = p.$2;
      if (p.$2 > maxLng) maxLng = p.$2;
    }
    // Use area (rect) instead of center+zoom so the map fits all points with padding
    final latSpan = (maxLat - minLat).clamp(0.01, 180.0);
    final lngSpan = (maxLng - minLng).clamp(0.01, 360.0);
    final padLat = latSpan * 0.25; // 25% padding top/bottom
    final padLng = lngSpan * 0.25; // 25% padding left/right
    final rect = 'rect:${(minLng - padLng).clamp(-180.0, 180.0)},${(maxLat + padLat).clamp(-90.0, 90.0)},${(maxLng + padLng).clamp(-180.0, 180.0)},${(minLat - padLat).clamp(-90.0, 90.0)}';

    // klokantech-basic: clean, minimal style
    final sb = StringBuffer(
      'https://maps.geoapify.com/v1/staticmap?'
      'style=positron'
      '&width=$w'
      '&height=$h'
      '&scaleFactor=2'
      '&area=${Uri.encodeComponent(rect)}'
      '&apiKey=$_geoapifyKey',
    );

    if (path && points.length >= 2) {
      final polyline = points.map((p) => '${p.$2},${p.$1}').join(',');
      final hex = (widget.pathColor.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toLowerCase();
      // Use # not %23 so Uri.encodeComponent produces %23 (single encoding); %23 would become %2523
      final geometry = 'polyline:$polyline;linewidth:6;linecolor:#$hex';
      sb.write('&geometry=${Uri.encodeComponent(geometry)}');
    }

    return sb.toString();
  }

  Future<void> _geocodeStops(List<ItineraryStop> stops) async {
    if (!_useGeoapify) return;

    if (mounted) setState(() => _geocoding = true);
    try {
      final destination = widget.itinerary.destination.trim();
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
        final coords = await _geocodeNominatim(address);
        if (coords != null) points.add(coords);
        await Future<void>.delayed(const Duration(milliseconds: 1100));
      }
      if (!mounted) return;
      if (points.isNotEmpty && _geoapifyKey != null) {
        final pts = points.length >= 2 ? points : [...points, points.first];
        final url = _buildGeoapifyUrl(pts, path: pts.length >= 2);
        setState(() {
          _geocodedUrl = url;
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

  Future<(double, double)?> _geocodeNominatim(String address) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(address)}'
        '&format=json'
        '&limit=1',
      );
      final res = await http.get(
        url,
        headers: {'User-Agent': 'FootprintTravelApp/1.0'},
      );
      if (res.statusCode != 200) return null;
      final list = jsonDecode(res.body) as List<dynamic>?;
      if (list == null || list.isEmpty) return null;
      final item = list.first as Map<String, dynamic>;
      // Nominatim returns lat/lon as strings
      final latVal = item['lat'];
      final lonVal = item['lon'];
      final lat = latVal is num ? latVal.toDouble() : (latVal is String ? double.tryParse(latVal) : null);
      final lon = lonVal is num ? lonVal.toDouble() : (lonVal is String ? double.tryParse(lonVal) : null);
      if (lat == null || lon == null) return null;
      return (lat, lon);
    } catch (e) {
      debugPrint('StaticMapImage Nominatim error: $e');
      return null;
    }
  }

  Future<void> _geocodeDestination() async {
    if (widget.itinerary.destination.trim().isEmpty) return;
    if (!_useGeoapify) {
      if (mounted) setState(() => _geocoding = false);
      return;
    }

    if (mounted) setState(() => _geocoding = true);
    try {
      final coords = await _geocodeNominatim(widget.itinerary.destination);
      if (!mounted) return;
      if (coords != null && _geoapifyKey != null) {
        final url = _buildGeoapifyUrl([coords], path: false);
        setState(() {
          _geocodedUrl = url;
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
          borderRadius: BorderRadius.circular(14),
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
          borderRadius: BorderRadius.circular(14),
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

    final cacheWidth = (widget.width * 2).toInt().clamp(100, 640);
    final cacheHeight = (widget.height * 2).toInt().clamp(100, 640);
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
        _geocodedUrl!,
        width: widget.width,
        height: widget.height,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: widget.width,
            height: widget.height,
            color: theme.colorScheme.surfaceContainerHighest,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Icon(Icons.map_outlined, size: 40, color: theme.colorScheme.outline),
            ),
          );
        },
        ),
      ),
    );
  }
}
