import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
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
  Brightness? _lastBrightness;

  static String? get _geoapifyKey {
    const fromDefine = String.fromEnvironment('GEOAPIFY_API_KEY', defaultValue: '');
    if (fromDefine.trim().isNotEmpty) return fromDefine.trim();
    return dotenv.env['GEOAPIFY_API_KEY']?.trim();
  }

  bool get _useGeoapify => (_geoapifyKey ?? '').trim().isNotEmpty;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    if (_lastBrightness != brightness || _geocodedUrl == null) {
      _lastBrightness = brightness;
      _buildUrl();
    }
  }

  @override
  void initState() {
    super.initState();
    // _buildUrl called from didChangeDependencies when we have context for brightness
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
    if (!_useGeoapify) {
      debugPrint('StaticMapImage: GEOAPIFY_API_KEY not found, cannot build map URL');
      if (mounted) setState(() => _geocodedUrl = null);
      return;
    }
    
    final url = _buildStaticMapUrl();
    if (url != null && url.isNotEmpty) {
      debugPrint('StaticMapImage: Built URL successfully (length: ${url.length})');
      if (mounted) setState(() => _geocodedUrl = url);
      return;
    }
    
    debugPrint('StaticMapImage: No stops with coordinates, attempting geocoding');
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
    // Separate cities (locations) from venues (spots)
    final cityStops = widget.itinerary.stops.where((s) => s.isLocation && s.lat != null && s.lng != null).toList();
    final venueStops = widget.itinerary.stops.where((s) => s.isVenue && s.lat != null && s.lng != null).toList();
    
    // Sort cities by day/position for polyline
    final orderedCities = List<ItineraryStop>.from(cityStops)
      ..sort((a, b) {
        final dayCmp = a.day.compareTo(b.day);
        return dayCmp != 0 ? dayCmp : a.position.compareTo(b.position);
      });
    
    final cityPoints = orderedCities.map((s) => (s.lat!, s.lng!)).toList();
    final venuePoints = venueStops.map((s) => (s.lat!, s.lng!)).toList();
    
    // Use cities for bounds calculation
    final allPoints = [...cityPoints, ...venuePoints];
    if (allPoints.isEmpty) return null;

    if (_useGeoapify && _geoapifyKey != null) {
      return _buildGeoapifyUrl(cityPoints, venuePoints: venuePoints, path: cityPoints.length >= 2);
    }
    return null;
  }

  /// Builds a list of points forming a curved path through [cityPoints] using quadratic Bezier segments.
  List<(double, double)> _createCurvedPolylinePoints(List<(double, double)> cityPoints) {
    if (cityPoints.length < 2) return cityPoints;
    final result = <(double, double)>[];
    for (var i = 0; i < cityPoints.length - 1; i++) {
      final from = cityPoints[i];
      final to = cityPoints[i + 1];
      final midLat = (from.$1 + to.$1) / 2;
      final midLng = (from.$2 + to.$2) / 2;
      final dx = to.$2 - from.$2;
      final dy = to.$1 - from.$1;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist < 1e-7) {
        if (i == 0) result.add(from);
        result.add(to);
        continue;
      }
      final offset = dist * 0.3;
      final perpX = -dy / dist * offset;
      final perpY = dx / dist * offset;
      final ctrlLat = midLat + perpY;
      final ctrlLng = midLng + perpX;
      const segments = 20;
      final start = i == 0 ? 0 : 1;
      for (var j = start; j <= segments; j++) {
        final t = j / segments;
        final lat = (1 - t) * (1 - t) * from.$1 + 2 * (1 - t) * t * ctrlLat + t * t * to.$1;
        final lng = (1 - t) * (1 - t) * from.$2 + 2 * (1 - t) * t * ctrlLng + t * t * to.$2;
        if (lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
          result.add((lat, lng));
        }
      }
    }
    return result.isEmpty ? cityPoints : result;
  }

  double get _finiteWidth {
    final w = widget.width;
    if (w.isFinite && w > 0) return w;
    return 400;
  }

  double get _finiteHeight {
    final h = widget.height;
    if (h.isFinite && h > 0) return h;
    return 200;
  }

  String _buildGeoapifyUrl(List<(double, double)> cityPoints, {List<(double, double)>? venuePoints, bool path = true}) {
    final w = (_finiteWidth * 2).toInt().clamp(100, 640);
    final h = (_finiteHeight * 2).toInt().clamp(100, 640);

    // Calculate bounds from all points (cities + venues)
    final allPoints = [...cityPoints, ...(venuePoints ?? [])];
    if (allPoints.isEmpty) return '';
    
    double minLat = allPoints.first.$1, maxLat = allPoints.first.$1;
    double minLng = allPoints.first.$2, maxLng = allPoints.first.$2;
    for (final p in allPoints) {
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

    // Same theme as interactive map (klokantech-basic)
    const style = 'klokantech-basic';
    final hex = (widget.pathColor.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toLowerCase();
    
    // Build geometry list - Geoapify requires multiple geometries in ONE parameter separated by |
    final geometries = <String>[];
    
    // Add curved dotted polyline connecting cities only
    if (path && cityPoints.length >= 2) {
      final curvedPoints = _createCurvedPolylinePoints(cityPoints);
      final polyline = curvedPoints.map((p) => '${p.$2},${p.$1}').join(',');
      geometries.add('polyline:$polyline;linewidth:6;linecolor:#$hex;linestyle:dotted');
    }
    
    // Add markers for cities (larger circles)
    // Format: circle:lon,lat,radius;properties
    for (final p in cityPoints) {
      geometries.add('circle:${p.$2},${p.$1},8;fillcolor:#$hex;linecolor:#ffffff;linewidth:2');
    }
    
    // Add markers for venues (small dots)
    if (venuePoints != null && venuePoints.isNotEmpty) {
      for (final p in venuePoints) {
        geometries.add('circle:${p.$2},${p.$1},4;fillcolor:#$hex;linecolor:#ffffff;linewidth:1');
      }
    }
    
    // If no geometries, at least add a marker for the single point
    if (geometries.isEmpty && allPoints.isNotEmpty) {
      final p = allPoints.first;
      geometries.add('circle:${p.$2},${p.$1},8;fillcolor:#$hex;linecolor:#ffffff;linewidth:2');
    }

    // Build URL - combine all geometries with pipe separator in single geometry parameter
    final sb = StringBuffer(
      'https://maps.geoapify.com/v1/staticmap?'
      'style=$style'
      '&width=$w'
      '&height=$h'
      '&scaleFactor=2'
      '&area=${Uri.encodeComponent(rect)}',
    );
    
    // Add single geometry parameter with all geometries separated by |
    if (geometries.isNotEmpty) {
      final combinedGeometry = geometries.join('|');
      sb.write('&geometry=${Uri.encodeComponent(combinedGeometry)}');
    }
    
    sb.write('&apiKey=$_geoapifyKey');

    final url = sb.toString();
    // Debug: log if URL is very long (might hit limits)
    if (url.length > 2000) {
      debugPrint('StaticMapImage: URL length is ${url.length} characters (may exceed limits)');
    }
    return url;
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
        // Separate cities from venues
        final cityPoints = <(double, double)>[];
        final venuePoints = <(double, double)>[];
        // Note: geocoded points are from location stops (cities), so they're all cities
        cityPoints.addAll(points);
        final url = _buildGeoapifyUrl(cityPoints, venuePoints: venuePoints, path: cityPoints.length >= 2);
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
        final url = _buildGeoapifyUrl([coords], venuePoints: [], path: false);
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
        width: _finiteWidth,
        height: _finiteHeight,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
        width: _finiteWidth,
        height: _finiteHeight,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
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

    final cacheWidth = (_finiteWidth * 2).toInt().clamp(100, 640);
    final cacheHeight = (_finiteHeight * 2).toInt().clamp(100, 640);
    final theme = Theme.of(context);
    return Container(
      width: widget.width.isFinite ? widget.width : null,
      height: widget.height.isFinite ? widget.height : null,
      constraints: (!widget.width.isFinite || !widget.height.isFinite)
          ? BoxConstraints(maxWidth: _finiteWidth, maxHeight: _finiteHeight)
          : null,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Image.network(
        _geocodedUrl!,
        width: _finiteWidth,
        height: _finiteHeight,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: _finiteWidth,
            height: _finiteHeight,
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
          debugPrint('StaticMapImage: Image load error: $error');
          debugPrint('StaticMapImage: URL was: ${_geocodedUrl?.substring(0, _geocodedUrl!.length.clamp(0, 200))}...');
          return Container(
            width: _finiteWidth,
            height: _finiteHeight,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_outlined, size: 40, color: theme.colorScheme.outline),
                  const SizedBox(height: 8),
                  if (kDebugMode)
                    Text(
                      'Map failed to load',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
