import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../core/theme.dart';
import '../core/web_tile_provider.dart';
import '../models/itinerary.dart';

/// Interactive itinerary map using flutter_map (Geoapify/Carto tiles).
/// Geocoding: Nominatim (free).
class ItineraryMap extends StatefulWidget {
  final List<ItineraryStop> stops;
  final String? destination;
  final double height;
  final bool fullScreen;
  final List<TransportTransition>? transportTransitions;

  const ItineraryMap({
    super.key,
    required this.stops,
    this.destination,
    this.height = 280,
    this.fullScreen = false,
    this.transportTransitions,
  });

  @override
  State<ItineraryMap> createState() => _ItineraryMapState();
}

class _ItineraryMapState extends State<ItineraryMap> {
  final _mapController = MapController();
  static const _defaultCenter = LatLng(40.0, -3.0);

  List<LatLng>? _geocodedCityPoints;
  bool _geocodingCities = false;

  List<ItineraryStop>? _venueStopsWithCoords;
  List<ItineraryStop>? _locationStopsWithCoords;
  List<ItineraryStop>? _locationStopsNoCoords;
  List<ItineraryStop>? _allStopsWithCoords;
  List<LatLng>? _polylinePoints;
  List<LatLng>? _displayPoints;
  Map<int, List<LatLng>>? _routedSegments; // Index -> route points for car segments
  bool _loadingRoutes = false;

  static String? get _geoapifyKey {
    const fromDefine = String.fromEnvironment('GEOAPIFY_API_KEY', defaultValue: '');
    if (fromDefine.trim().isNotEmpty) return fromDefine.trim();
    return dotenv.env['GEOAPIFY_API_KEY']?.trim();
  }

  void _invalidateStopsCache() {
    _venueStopsWithCoords = null;
    _locationStopsWithCoords = null;
    _locationStopsNoCoords = null;
    _allStopsWithCoords = null;
    _polylinePoints = null;
    _displayPoints = null;
    _routedSegments = null;
  }

  List<ItineraryStop> get _venueStopsWithCoordsList =>
      _venueStopsWithCoords ??= widget.stops.where((s) => s.isVenue && s.lat != null && s.lng != null).toList();

  List<ItineraryStop> get _locationStopsWithCoordsList =>
      _locationStopsWithCoords ??= widget.stops.where((s) => s.isLocation && s.lat != null && s.lng != null).toList();

  List<ItineraryStop> get _locationStopsNoCoordsList =>
      _locationStopsNoCoords ??= widget.stops.where((s) => s.isLocation && (s.lat == null || s.lng == null)).toList();

  List<ItineraryStop> get _allStopsWithCoordsList =>
      _allStopsWithCoords ??= widget.stops.where((s) => s.lat != null && s.lng != null).toList();

  List<LatLng> get _polylinePointsList {
    if (_polylinePoints != null) return _polylinePoints!;
    // Only use location stops (cities) for connecting lines, not venues
    final locationStops = _locationStopsWithCoordsList;
    final ordered = List<ItineraryStop>.from(locationStops)
      ..sort((a, b) {
        final dayCmp = a.day.compareTo(b.day);
        return dayCmp != 0 ? dayCmp : a.position.compareTo(b.position);
      });
    final fromStops = ordered.map((s) => LatLng(s.lat!, s.lng!)).toList();
    return _polylinePoints = fromStops.isNotEmpty ? fromStops : (_geocodedCityPoints ?? []);
  }

  List<LatLng> get _displayPointsList {
    if (_displayPoints != null) return _displayPoints!;
    final all = _allStopsWithCoordsList.map((s) => LatLng(s.lat!, s.lng!)).toList();
    if (all.isNotEmpty) return _displayPoints = all;
    return _displayPoints = _geocodedCityPoints ?? [];
  }

  bool get _hasMapData => _displayPointsList.isNotEmpty || _polylinePointsList.isNotEmpty;


  @override
  void didUpdateWidget(ItineraryMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stops != widget.stops ||
        oldWidget.destination != widget.destination ||
        oldWidget.transportTransitions != widget.transportTransitions ||
        oldWidget.fullScreen != widget.fullScreen) {
      _invalidateStopsCache();
      _maybeGeocodeCities();
      if (widget.fullScreen) {
        _loadRoutesForCarSegments();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _maybeGeocodeCities();
    if (widget.fullScreen) {
      _loadRoutesForCarSegments();
    }
  }

  void _maybeGeocodeCities() {
    if (_venueStopsWithCoordsList.isNotEmpty || _locationStopsWithCoordsList.isNotEmpty) return;
    final locNoCoords = _locationStopsNoCoordsList;
    if (locNoCoords.isEmpty) return;
    _geocodeCities(locNoCoords);
  }

  Future<void> _geocodeCities(List<ItineraryStop> locationStops) async {
    if (mounted) setState(() => _geocodingCities = true);
    try {
      final destination = (widget.destination ?? '').trim();
      final uniqueNames = locationStops.map((s) => s.name.trim()).where((n) => n.isNotEmpty).toSet().toList();
      final points = <LatLng>[];

      for (final name in uniqueNames) {
        final address = destination.isNotEmpty ? '$name, $destination' : name;
        final coords = await _geocodeNominatim(address);
        if (coords != null) {
          points.add(LatLng(coords.$1, coords.$2));
        }
        await Future<void>.delayed(const Duration(milliseconds: 1100));
      }

      if (mounted && points.isNotEmpty) {
        setState(() {
          _geocodedCityPoints = points;
          _geocodingCities = false;
          _invalidateStopsCache();
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
      } else if (mounted) {
        setState(() => _geocodingCities = false);
      }
    } catch (e) {
      debugPrint('ItineraryMap geocode cities error: $e');
      if (mounted) setState(() => _geocodingCities = false);
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
      final res = await http.get(url, headers: {'User-Agent': 'FootprintTravelApp/1.0'});
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
      debugPrint('ItineraryMap Nominatim error: $e');
      return null;
    }
  }

  Future<void> _loadRoutesForCarSegments() async {
    if (!widget.fullScreen || _geoapifyKey == null) return;
    
    final locationStops = _locationStopsWithCoordsList;
    if (locationStops.length < 2) return;
    
    final ordered = List<ItineraryStop>.from(locationStops)
      ..sort((a, b) {
        final dayCmp = a.day.compareTo(b.day);
        return dayCmp != 0 ? dayCmp : a.position.compareTo(b.position);
      });

    final transitions = widget.transportTransitions ?? [];
    final routes = <int, List<LatLng>>{};
    
    if (mounted) setState(() => _loadingRoutes = true);

    try {
      for (var i = 0; i < ordered.length - 1; i++) {
        final from = ordered[i];
        final to = ordered[i + 1];
        
        if (from.lat == null || from.lng == null || to.lat == null || to.lng == null) continue;
        
        // Check if transport mode is car
        final transportType = i < transitions.length ? transitions[i].type : 'unknown';
        if (transportType.toLowerCase() != 'car') continue;

        // Fetch route from Geoapify Routing API
        debugPrint('ItineraryMap: Loading route for segment $i (${from.name} -> ${to.name})');
        final route = await _fetchRoute(
          LatLng(from.lat!, from.lng!),
          LatLng(to.lat!, to.lng!),
        );
        
        if (route != null && route.isNotEmpty) {
          debugPrint('ItineraryMap: Route loaded successfully for segment $i (${route.length} points)');
          routes[i] = route;
        } else {
          debugPrint('ItineraryMap: Failed to load route for segment $i');
        }
        
        // Rate limiting: delay between requests
        await Future.delayed(const Duration(milliseconds: 200));
      }

      if (mounted) {
        setState(() {
          _routedSegments = routes.isEmpty ? null : routes;
          _loadingRoutes = false;
        });
      }
    } catch (e) {
      debugPrint('ItineraryMap route loading error: $e');
      if (mounted) setState(() => _loadingRoutes = false);
    }
  }

  Future<List<LatLng>?> _fetchRoute(LatLng from, LatLng to) async {
    try {
      final key = _geoapifyKey;
      if (key == null || key.trim().isEmpty) {
        debugPrint('ItineraryMap: No Geoapify API key');
        return null;
      }

      final url = Uri.parse(
        'https://api.geoapify.com/v1/routing'
        '?waypoints=${from.latitude},${from.longitude}|${to.latitude},${to.longitude}'
        '&mode=drive'
        '&apiKey=$key',
      );

      debugPrint('ItineraryMap: Fetching route from ${from.latitude},${from.longitude} to ${to.latitude},${to.longitude}');
      
      final res = await http.get(url);
      if (res.statusCode != 200) {
        debugPrint('Geoapify routing error: ${res.statusCode} - ${res.body}');
        return null;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint('ItineraryMap: Route response keys: ${data.keys.toList()}');
      
      final features = data['features'] as List<dynamic>?;
      if (features == null || features.isEmpty) {
        debugPrint('ItineraryMap: No features in route response');
        return null;
      }
      
      debugPrint('ItineraryMap: Found ${features.length} features');
      debugPrint('ItineraryMap: First feature keys: ${(features.first as Map<String, dynamic>).keys.toList()}');

      // Extract coordinates from the route geometry
      final geometry = features.first['geometry'] as Map<String, dynamic>?;
      if (geometry == null) {
        debugPrint('ItineraryMap: No geometry in route feature');
        return null;
      }
      
      final geometryType = geometry['type'] as String?;
      debugPrint('ItineraryMap: Geometry type: $geometryType');
      
      final coordinates = geometry['coordinates'] as dynamic;
      if (coordinates == null) {
        debugPrint('ItineraryMap: No coordinates in route geometry');
        return null;
      }
      
      // Handle different geometry types
      List<dynamic> coordList;
      if (geometryType == 'LineString' && coordinates is List) {
        // LineString: coordinates is directly a list of [lon, lat] pairs
        coordList = coordinates;
        debugPrint('ItineraryMap: LineString with ${coordList.length} coordinate points');
      } else if (geometryType == 'MultiLineString' && coordinates is List) {
        // MultiLineString: coordinates is a list of LineString arrays
        // Take the first LineString (usually the main route)
        if (coordinates.isNotEmpty && coordinates[0] is List) {
          coordList = coordinates[0] as List<dynamic>;
          debugPrint('ItineraryMap: MultiLineString with ${coordList.length} coordinate points in first segment');
        } else {
          debugPrint('ItineraryMap: Invalid MultiLineString format');
          return null;
        }
      } else {
        debugPrint('ItineraryMap: Unexpected geometry type or format: $geometryType, coordinates type: ${coordinates.runtimeType}');
        return null;
      }

      final routePoints = <LatLng>[];
      for (var i = 0; i < coordList.length; i++) {
        final coord = coordList[i];
        try {
          // Geoapify returns coordinates as [lon, lat] arrays
          dynamic lon, lat;
          if (coord is List && coord.length >= 2) {
            lon = coord[0];
            lat = coord[1];
          } else {
            debugPrint('ItineraryMap: Invalid coordinate format at index $i: $coord (type: ${coord.runtimeType})');
            continue;
          }
          
          // Convert to numbers safely
          final lonVal = lon is num ? lon.toDouble() : (lon is String ? double.tryParse(lon) : null);
          final latVal = lat is num ? lat.toDouble() : (lat is String ? double.tryParse(lat) : null);
          
          if (lonVal != null && latVal != null && 
              lonVal >= -180 && lonVal <= 180 && 
              latVal >= -90 && latVal <= 90) {
            routePoints.add(LatLng(latVal, lonVal));
          } else {
            debugPrint('ItineraryMap: Invalid coordinate values at index $i: lon=$lon (${lon.runtimeType}) -> $lonVal, lat=$lat (${lat.runtimeType}) -> $latVal');
          }
        } catch (e) {
          debugPrint('ItineraryMap route coordinate parse error at index $i: $e for coord: $coord (type: ${coord.runtimeType})');
          continue;
        }
      }
      
      if (routePoints.isEmpty) {
        debugPrint('ItineraryMap: No valid route points extracted');
        return null;
      }
      
      debugPrint('ItineraryMap: Successfully extracted ${routePoints.length} route points');
      return routePoints;
    } catch (e) {
      debugPrint('ItineraryMap route fetch error: $e');
      return null;
    }
  }

  LatLngBounds? _bounds() {
    final points = _polylinePointsList;
    if (points.isEmpty) return null;
    return LatLngBounds.fromPoints(points);
  }

  /// True if bounds would be zero-area (single point or collapsed), which causes infinite zoom.
  bool _isZeroAreaBounds(LatLngBounds bounds) {
    final sw = bounds.southWest;
    final ne = bounds.northEast;
    return sw.latitude == ne.latitude && sw.longitude == ne.longitude;
  }

  void _fitBounds() {
    final bounds = _bounds();
    if (bounds == null) return;
    try {
      if (_isZeroAreaBounds(bounds)) {
        _mapController.move(bounds.center, 12);
      } else {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(50),
          ),
        );
      }
    } catch (_) {}
  }

  TileLayer _buildTileLayer(Brightness brightness) {
    final key = _geoapifyKey;
    final isDark = brightness == Brightness.dark;
    // On web, use WebTileProvider (NetworkImage) to bypass CORS; default uses HTTP which can fail
    final tileProvider = kIsWeb ? WebTileProvider() : null;
    if (key != null && key.trim().isNotEmpty) {
      // Use different styles for full-screen maps vs card maps
      final style = widget.fullScreen
          ? 'klokantech-basic'
          : (isDark ? 'dark-matter' : 'positron');
      return TileLayer(
        urlTemplate: 'https://maps.geoapify.com/v1/tile/$style/{z}/{x}/{y}.png?apiKey=$key',
        userAgentPackageName: 'com.footprint.travel',
        maxNativeZoom: 20,
        tileProvider: tileProvider,
      );
    }
    final cartoStyle = isDark ? 'dark_nolabels' : 'light_nolabels';
    return TileLayer(
      urlTemplate: 'https://a.basemaps.cartocdn.com/rastertiles/$cartoStyle/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.footprint.travel',
      maxNativeZoom: 20,
      tileProvider: tileProvider,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCoords = _hasMapData;
    final stopCount = _displayPointsList.length;
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (widget.fullScreen) {
      // Full-screen mode: just the map, no card styling
      if (!hasCoords && !_geocodingCities) {
        return Container(
          height: widget.height,
          color: Theme.of(context).colorScheme.surface,
          child: _buildEmptyState(context),
        );
      } else if (_geocodingCities) {
        return Container(
          height: widget.height,
          color: Theme.of(context).colorScheme.surface,
          child: _buildLoadingState(context),
        );
      } else {
        return SizedBox(
          height: widget.height,
          width: double.infinity,
          child: _buildMap(context, primaryColor),
        );
      }
    }

    // Card mode: original styling
    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(16),
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd, vertical: AppTheme.spacingSm),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2))),
              ),
              child: Row(
                children: [
                  Icon(Icons.route_outlined, size: 20, color: primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'Route',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$stopCount ${stopCount == 1 ? 'stop' : 'stops'}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!hasCoords && !_geocodingCities) _buildEmptyState(context)
            else if (_geocodingCities) _buildLoadingState(context)
            else _buildMap(context, primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Container(
      height: widget.height,
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading map…',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      height: widget.height,
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.map_outlined, size: 40, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'No map data yet',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add places with locations to see your route on the map',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(BuildContext context, Color primaryColor) {
    final brightness = Theme.of(context).brightness;
    final initialPos = _polylinePointsList.isNotEmpty ? _polylinePointsList.first : _defaultCenter;
    final bounds = _bounds();
    final CameraFit? initialFit = bounds != null && !_isZeroAreaBounds(bounds)
        ? CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50))
        : null;
    return SizedBox(
      height: widget.height,
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: initialPos,
          initialZoom: 12,
          initialCameraFit: initialFit,
          onMapReady: () {
            if (bounds == null) _fitBounds();
            // Zoom wiggle forces tile redraw (flutter_map #1813 – grey until touch)
            Future.delayed(const Duration(milliseconds: 200), () async {
              if (!mounted) return;
              try {
                final c = _mapController.camera;
                _mapController.move(c.center, c.zoom + 0.02);
                await Future.delayed(const Duration(milliseconds: 80));
                if (!mounted) return;
                _mapController.move(c.center, c.zoom);
              } catch (_) {}
            });
          },
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all,
          ),
        ),
        children: [
          _buildTileLayer(brightness),
          if (widget.fullScreen && _locationStopsWithCoordsList.length >= 2)
            _buildRouteLayers(primaryColor)
          else if (_polylinePointsList.length >= 2)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _polylinePointsList,
                  color: primaryColor,
                  strokeWidth: 5,
                ),
              ],
            ),
          MarkerLayer(
            markers: [
              // City markers (locations) - larger circles
              ..._locationStopsWithCoordsList.map((stop) => Marker(
                point: LatLng(stop.lat!, stop.lng!),
                width: 16,
                height: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              )),
              // Venue markers (spots) - small dots
              ..._venueStopsWithCoordsList.map((stop) => Marker(
                point: LatLng(stop.lat!, stop.lng!),
                width: 8,
                height: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                ),
              )),
            ],
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomRight,
                    child: Text(
                    (_geoapifyKey ?? '').trim().isNotEmpty ? 'Geoapify | OSM' : '© CARTO | OSM',
                    style: TextStyle(fontSize: 8, color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade400 : Colors.grey.shade600),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<LatLng> _createCurvedLine(LatLng from, LatLng to) {
    // Validate input coordinates
    if (from.latitude < -90 || from.latitude > 90 || 
        from.longitude < -180 || from.longitude > 180 ||
        to.latitude < -90 || to.latitude > 90 || 
        to.longitude < -180 || to.longitude > 180) {
      // Return simple straight line if coordinates are invalid
      return [from, to];
    }
    
    // Create a curved line using quadratic bezier curve
    // Control point is offset perpendicular to the midpoint
    final midLat = (from.latitude + to.latitude) / 2;
    final midLng = (from.longitude + to.longitude) / 2;
    
    // Calculate perpendicular offset for curve
    final dx = to.longitude - from.longitude;
    final dy = to.latitude - from.latitude;
    final dist = math.sqrt(dx * dx + dy * dy);
    
    // Avoid division by zero
    if (dist < 0.0001) {
      return [from, to];
    }
    
    // Offset perpendicular to the line (creates arc)
    final offset = dist * 0.3; // Curve height factor
    final perpX = -dy / dist * offset;
    final perpY = dx / dist * offset;
    
    final controlLat = midLat + perpY;
    final controlLng = midLng + perpX;
    
    // Generate points along the curve
    final points = <LatLng>[];
    const segments = 20;
    for (var i = 0; i <= segments; i++) {
      final t = i / segments;
      final lat = (1 - t) * (1 - t) * from.latitude + 2 * (1 - t) * t * controlLat + t * t * to.latitude;
      final lng = (1 - t) * (1 - t) * from.longitude + 2 * (1 - t) * t * controlLng + t * t * to.longitude;
      
      // Validate generated coordinates
      if (lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
        points.add(LatLng(lat, lng));
      }
    }
    
    // Ensure we have at least start and end points
    if (points.isEmpty) {
      return [from, to];
    }
    
    // Ensure first and last points match exactly
    if (points.first != from) points.insert(0, from);
    if (points.last != to) points.add(to);
    
    return points;
  }

  Widget _buildRouteLayers(Color primaryColor) {
    final locationStops = _locationStopsWithCoordsList;
    if (locationStops.length < 2) return const SizedBox.shrink();
    
    final ordered = List<ItineraryStop>.from(locationStops)
      ..sort((a, b) {
        final dayCmp = a.day.compareTo(b.day);
        return dayCmp != 0 ? dayCmp : a.position.compareTo(b.position);
      });

    final transitions = widget.transportTransitions ?? [];
    final polylines = <Polyline>[];
    
    for (var i = 0; i < ordered.length - 1; i++) {
      final from = ordered[i];
      final to = ordered[i + 1];
      
      if (from.lat == null || from.lng == null || to.lat == null || to.lng == null) continue;
      
      final fromPoint = LatLng(from.lat!, from.lng!);
      final toPoint = LatLng(to.lat!, to.lng!);
      
      final transportType = i < transitions.length ? transitions[i].type.toLowerCase() : 'unknown';
      final isCar = transportType == 'car';
      
      if (isCar && _routedSegments != null && _routedSegments!.containsKey(i)) {
        // Use actual route for car segments
        final route = _routedSegments![i]!;
        debugPrint('ItineraryMap: Using fetched route for car segment $i (${route.length} points)');
        if (route.isNotEmpty && route.length >= 2) {
          // Validate route points
          final validRoute = route.where((p) => 
            p.latitude >= -90 && p.latitude <= 90 && 
            p.longitude >= -180 && p.longitude <= 180
          ).toList();
          
          if (validRoute.length >= 2) {
            polylines.add(Polyline(
              points: validRoute,
              color: primaryColor,
              strokeWidth: 5,
            ));
          } else {
            debugPrint('ItineraryMap: Route for segment $i has invalid points, falling back to curved line');
            // Fall back to curved line if route is invalid
            final curvedPoints = _createCurvedLine(fromPoint, toPoint);
            if (curvedPoints.length >= 2) {
              polylines.add(Polyline(
                points: curvedPoints,
                color: primaryColor,
                strokeWidth: 4,
                pattern: StrokePattern.dashed(
                  segments: [10, 8],
                ),
              ));
            }
          }
        }
      } else {
        debugPrint('ItineraryMap: Using curved line for segment $i (transport: $transportType, isCar: $isCar, hasRoutes: ${_routedSegments != null}, segmentInRoutes: ${_routedSegments?.containsKey(i)})');
        // Use curved dotted line for non-car segments
        final curvedPoints = _createCurvedLine(fromPoint, toPoint);
        if (curvedPoints.length >= 2) {
          polylines.add(Polyline(
            points: curvedPoints,
            color: primaryColor,
            strokeWidth: 4,
            pattern: StrokePattern.dashed(
              segments: [10, 8],
            ),
          ));
        }
      }
    }
    
    if (polylines.isEmpty) return const SizedBox.shrink();
    
    return PolylineLayer(polylines: polylines);
  }
}
