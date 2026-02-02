import 'dart:convert';
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

  const ItineraryMap({super.key, required this.stops, this.destination, this.height = 280});

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
    // Use all stops with coords (location + venue) in day/position order for full route
    final allWithCoords = _allStopsWithCoordsList;
    final ordered = List<ItineraryStop>.from(allWithCoords)
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
  void initState() {
    super.initState();
    _maybeGeocodeCities();
  }

  @override
  void didUpdateWidget(ItineraryMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stops != widget.stops || oldWidget.destination != widget.destination) {
      _invalidateStopsCache();
      _maybeGeocodeCities();
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
      final style = isDark ? 'dark-matter' : 'positron';
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
          if (_polylinePointsList.length >= 2)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _polylinePointsList,
                  color: primaryColor,
                  strokeWidth: 5,
                ),
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
}
