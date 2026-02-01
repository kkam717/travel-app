import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../core/map_style.dart';
import '../core/theme.dart';
import '../models/itinerary.dart';

class ItineraryMap extends StatefulWidget {
  final List<ItineraryStop> stops;
  final String? destination;
  final double height;

  const ItineraryMap({super.key, required this.stops, this.destination, this.height = 280});

  @override
  State<ItineraryMap> createState() => _ItineraryMapState();
}

class _ItineraryMapState extends State<ItineraryMap> {
  final Completer<GoogleMapController> _controller = Completer();
  static const _defaultCenter = LatLng(40.0, -3.0);

  List<LatLng>? _geocodedCityPoints;
  List<String>? _geocodedCityNames;
  bool _geocodingCities = false;

  List<ItineraryStop>? _venueStopsWithCoords;
  List<ItineraryStop>? _locationStopsWithCoords;
  List<ItineraryStop>? _locationStopsNoCoords;
  List<ItineraryStop>? _allStopsWithCoords;
  List<LatLng>? _polylinePoints;
  List<LatLng>? _displayPoints;

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
    final fromStops = _allStopsWithCoordsList.map((s) => LatLng(s.lat!, s.lng!)).toList();
    return _polylinePoints = fromStops.isNotEmpty ? fromStops : (_geocodedCityPoints ?? []);
  }

  List<LatLng> get _displayPointsList {
    if (_displayPoints != null) return _displayPoints!;
    final venue = _venueStopsWithCoordsList.map((s) => LatLng(s.lat!, s.lng!)).toList();
    if (venue.isNotEmpty) return _displayPoints = venue;
    final loc = _locationStopsWithCoordsList.map((s) => LatLng(s.lat!, s.lng!)).toList();
    if (loc.isNotEmpty) return _displayPoints = loc;
    return _displayPoints = _geocodedCityPoints ?? [];
  }

  bool get _hasMapData => _displayPointsList.isNotEmpty || _polylinePointsList.isNotEmpty;

  /// Pins: venue stops (restaurant/bar/guide) when available, else location stops.
  /// Uses theme color (teal) for consistent pin styling.
  Set<Marker> _markersWithIcon(BitmapDescriptor icon) {
    final venueStops = _venueStopsWithCoordsList;
    final locStops = _locationStopsWithCoordsList;
    final useVenue = venueStops.isNotEmpty;
    final useLoc = !useVenue && locStops.isNotEmpty;
    final useGeocoded = !useVenue && !useLoc && (_geocodedCityPoints?.isNotEmpty ?? false);

    if (useVenue) {
      return venueStops.asMap().entries.map((e) {
        final i = e.key + 1;
        final s = e.value;
        final snippet = s.category != null && s.category != 'location'
            ? '${s.category} • Stop $i'
            : 'Stop $i';
        return Marker(
          markerId: MarkerId(s.id),
          position: LatLng(s.lat!, s.lng!),
          icon: icon,
          infoWindow: InfoWindow(title: s.name, snippet: snippet),
        );
      }).toSet();
    }
    if (useLoc) {
      return locStops.asMap().entries.map((e) {
        final s = e.value;
        return Marker(
          markerId: MarkerId(s.id),
          position: LatLng(s.lat!, s.lng!),
          icon: icon,
          infoWindow: InfoWindow(title: s.name, snippet: 'City'),
        );
      }).toSet();
    }
    if (useGeocoded && _geocodedCityPoints != null) {
      final names = _geocodedCityNames ?? List.filled(_geocodedCityPoints!.length, '');
      return _geocodedCityPoints!.asMap().entries.map((e) {
        final p = e.value;
        final name = e.key < names.length ? names[e.key] : '';
        return Marker(
          markerId: MarkerId('geocoded_${e.key}'),
          position: p,
          icon: icon,
          infoWindow: InfoWindow(title: name, snippet: 'City'),
        );
      }).toSet();
    }
    return {};
  }

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
    final key = dotenv.env['GOOGLE_API_KEY'];
    if (key == null || key.isEmpty) return;

    if (mounted) setState(() => _geocodingCities = true);
    try {
      final destination = (widget.destination ?? '').trim();
      final uniqueNames = locationStops.map((s) => s.name.trim()).where((n) => n.isNotEmpty).toSet().toList();
      final points = <LatLng>[];
      final names = <String>[];
      for (final name in uniqueNames) {
        final address = destination.isNotEmpty ? '$name, $destination' : name;
        final coords = await _geocodeAddress(key, address);
        if (coords != null) {
          points.add(LatLng(coords.$1, coords.$2));
          names.add(name);
        }
      }
      if (mounted && points.isNotEmpty) {
        setState(() {
          _geocodedCityPoints = points;
          _geocodedCityNames = names;
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

  LatLngBounds? _bounds() {
    final points = _polylinePointsList;
    if (points.isEmpty) return null;
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  Future<void> _fitBounds() async {
    final bounds = _bounds();
    if (bounds == null) return;
    try {
      final ctrl = await _controller.future;
      if (!mounted) return;
      await ctrl.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    } catch (_) {
      // Map may have been disposed before controller completed
    }
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
            // Header
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
            // Map or empty state
            if (!hasCoords && !_geocodingCities) _buildEmptyState(context)
            else if (_geocodingCities) _buildLoadingState(context)
            else _buildMap(context, primaryColor),
            if (hasCoords)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd, vertical: AppTheme.spacingXs),
                child: Row(
                  children: [
                    Icon(Icons.touch_app, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      'Tap markers for place details',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
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
    final hue = HSVColor.fromColor(primaryColor).hue;
    final markerIcon = BitmapDescriptor.defaultMarkerWithHue(hue);
    final initialPos = _polylinePointsList.isNotEmpty ? _polylinePointsList.first : _defaultCenter;
    return SizedBox(
      height: widget.height,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(target: initialPos, zoom: 12),
        mapType: MapType.normal,
        style: googleMapsStyleJson,
        markers: _markersWithIcon(markerIcon),
        polylines: {
          if (_polylinePointsList.length >= 2)
            Polyline(
              polylineId: const PolylineId('route'),
              points: _polylinePointsList,
              color: primaryColor,
              width: 5,
            ),
        },
        onMapCreated: (ctrl) {
          _controller.complete(ctrl);
          if (mounted) _fitBounds();
        },
        gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
          Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
        },
        myLocationButtonEnabled: false,
        myLocationEnabled: false,
        compassEnabled: false,
        mapToolbarEnabled: false,
        buildingsEnabled: false,
        zoomControlsEnabled: true,
      ),
    );
  }
}
