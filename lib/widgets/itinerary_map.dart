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
  Map<int, List<LatLng>>? _routedSegments; // Index -> route points for car/plane/train segments
  bool _loadingRoutes = false;
  ItineraryStop? _selectedVenue;

  static String? get _geoapifyKey {
    const fromDefine = String.fromEnvironment('GEOAPIFY_API_KEY', defaultValue: '');
    if (fromDefine.trim().isNotEmpty) return fromDefine.trim();
    return dotenv.env['GEOAPIFY_API_KEY']?.trim();
  }

  void _invalidateStopsCache() {
    _selectedVenue = null;
    _venueStopsWithCoords = null;
    _locationStopsWithCoords = null;
    _locationStopsNoCoords = null;
    _allStopsWithCoords = null;
    _polylinePoints = null;
    _displayPoints = null;
    _routedSegments = null;
  }

  /// Same criteria as original dots: any stop that is not a location (venue/other) with coords gets a marker.
  List<ItineraryStop> get _venueStopsWithCoordsList =>
      _venueStopsWithCoords ??= widget.stops.where((s) => s.isVenue && s.lat != null && s.lng != null).toList();

  List<ItineraryStop> get _locationStopsWithCoordsList =>
      _locationStopsWithCoords ??= widget.stops.where((s) => s.isLocation && s.lat != null && s.lng != null).toList();

  /// Location stops to show as waypoint dots. In full-screen with route, show only the end of the route (one dot at the last stop).
  List<ItineraryStop> get _orderedLocationStopsForMarkers {
    final list = _locationStopsWithCoordsList;
    if (list.isEmpty) return list;
    final ordered = List<ItineraryStop>.from(list)
      ..sort((a, b) {
        final dayCmp = a.day.compareTo(b.day);
        return dayCmp != 0 ? dayCmp : a.position.compareTo(b.position);
      });
    if (widget.fullScreen && ordered.length >= 2) {
      return [ordered.last];
    }
    return ordered;
  }

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
    
    if (mounted) setState(() => _loadingRoutes = true);

    try {
      // Build one future per segment and run them in parallel for faster loading
      final segmentCount = ordered.length - 1;
      final futures = <Future<({int i, List<LatLng>? route})>>[];
      
      for (var i = 0; i < segmentCount; i++) {
        final from = ordered[i];
        final to = ordered[i + 1];
        if (from.lat == null || from.lng == null || to.lat == null || to.lng == null) continue;
        
        final transition = i < transitions.length ? transitions[i] : null;
        final transportType = (transition?.type ?? 'car').toString().toLowerCase();
        final description = transition?.description?.trim();
        final fromPt = LatLng(from.lat!, from.lng!);
        final toPt = LatLng(to.lat!, to.lng!);
        
        Future<({int i, List<LatLng>? route})> future;
        if (transportType == 'car') {
          future = _fetchRoute(fromPt, toPt).then((r) => (i: i, route: r));
        } else if (transportType == 'plane' && description != null && description.isNotEmpty) {
          future = _fetchFlightRoute(fromPt, toPt, description, from.name, to.name).then((r) => (i: i, route: r));
        } else if (transportType == 'train') {
          future = _fetchTrainRoute(fromPt, toPt, description ?? '', from.name, to.name).then((r) => (i: i, route: r));
        } else {
          future = Future.value((i: i, route: null));
        }
        futures.add(future);
      }
      
      final results = await Future.wait(futures);
      final routes = <int, List<LatLng>>{};
      for (final r in results) {
        if (r.route != null && r.route!.isNotEmpty) routes[r.i] = r.route!;
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

  static const _routeTimeout = Duration(seconds: 15);

  /// Parse GeoJSON feature geometry (LineString or MultiLineString) to list of LatLng.
  /// Geoapify returns [lon, lat]. MultiLineString legs are merged in order.
  List<LatLng>? _parseGeoJsonRouteGeometry(Map<String, dynamic>? geometry) {
    if (geometry == null) return null;
    final geometryType = geometry['type'] as String?;
    final coordinates = geometry['coordinates'] as dynamic;
    if (coordinates == null || coordinates is! List) return null;

    final allPoints = <LatLng>[];
    if (geometryType == 'LineString') {
      for (final coord in coordinates) {
        final p = _parseCoord(coord);
        if (p != null) allPoints.add(p);
      }
    } else if (geometryType == 'MultiLineString') {
      for (final line in coordinates) {
        if (line is! List) continue;
        for (final coord in line) {
          final p = _parseCoord(coord);
          if (p != null) allPoints.add(p);
        }
      }
    } else {
      return null;
    }
    return allPoints.isEmpty ? null : allPoints;
  }

  LatLng? _parseCoord(dynamic coord) {
    if (coord is! List || coord.length < 2) return null;
    final lon = coord[0];
    final lat = coord[1];
    final lonVal = lon is num ? lon.toDouble() : (lon is String ? double.tryParse(lon) : null);
    final latVal = lat is num ? lat.toDouble() : (lat is String ? double.tryParse(lat) : null);
    if (lonVal == null || latVal == null ||
        lonVal < -180 || lonVal > 180 || latVal < -90 || latVal > 90) {
      return null;
    }
    return LatLng(latVal, lonVal);
  }

  Future<List<LatLng>?> _fetchRoute(LatLng from, LatLng to) async {
    final key = _geoapifyKey;
    if (key != null && key.trim().isNotEmpty) {
      final route = await _fetchGeoapifyRoute(from, to, 'drive', key);
      if (route != null && route.isNotEmpty) return route;
    }
    // Fallback: OSRM public car routing (no API key, reliable for drive)
    debugPrint('ItineraryMap: Falling back to OSRM for car route');
    return _fetchOSRMDriveRoute(from, to);
  }

  Future<List<LatLng>?> _fetchGeoapifyRoute(LatLng from, LatLng to, String mode, String apiKey) async {
    try {
      final url = Uri.parse(
        'https://api.geoapify.com/v1/routing'
        '?waypoints=${from.latitude},${from.longitude}|${to.latitude},${to.longitude}'
        '&mode=$mode'
        '&apiKey=$apiKey',
      );
      debugPrint('ItineraryMap: Fetching Geoapify route ($mode) from ${from.latitude},${from.longitude} to ${to.latitude},${to.longitude}');

      final res = await http.get(url).timeout(_routeTimeout);
      if (res.statusCode != 200) {
        debugPrint('Geoapify routing error: ${res.statusCode} - ${res.body}');
        return null;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final features = data['features'] as List<dynamic>?;
      if (features == null || features.isEmpty) {
        debugPrint('ItineraryMap: No features in route response');
        return null;
      }

      final geometry = features.first['geometry'] as Map<String, dynamic>?;
      final routePoints = _parseGeoJsonRouteGeometry(geometry);
      if (routePoints != null) {
        debugPrint('ItineraryMap: Geoapify route parsed: ${routePoints.length} points');
      }
      return routePoints;
    } catch (e) {
      debugPrint('ItineraryMap Geoapify route fetch error: $e');
      return null;
    }
  }

  Future<List<LatLng>?> _fetchOSRMDriveRoute(LatLng from, LatLng to) async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson',
      );
      final res = await http.get(url).timeout(_routeTimeout);
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['code'] != 'Ok') return null;
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;
      final geometry = routes.first['geometry'] as Map<String, dynamic>?;
      final coords = geometry?['coordinates'] as List<dynamic>?;
      if (coords == null) return null;
      final points = <LatLng>[];
      for (final c in coords) {
        final p = _parseCoord(c);
        if (p != null) points.add(p);
      }
      return points.isEmpty ? null : points;
    } catch (e) {
      debugPrint('ItineraryMap OSRM route error: $e');
      return null;
    }
  }

  /// Parse flight number from description (e.g., "AA123", "BA456", "DL789")
  String? _parseFlightNumber(String description) {
    // Match common flight number patterns: 2-3 letter airline code + 1-4 digits
    final regex = RegExp(r'\b([A-Z]{2,3})\s*(\d{1,4})\b', caseSensitive: false);
    final match = regex.firstMatch(description);
    if (match != null) {
      return '${match.group(1)!.toUpperCase()}${match.group(2)}';
    }
    return null;
  }

  /// Parse train number from description (e.g., "TGV 1234", "ICE 567", "Amtrak Northeast Regional")
  String? _parseTrainNumber(String description) {
    // First check if description contains any train type keywords
    final trainTypes = ['TGV', 'ICE', 'Shinkansen', 'Eurostar', 'Thalys', 'AVE', 'Frecciarossa', 'Trenitalia', 'Amtrak', 'Acela', 'Regional', 'Express'];
    final hasTrainType = trainTypes.any((type) => description.toLowerCase().contains(type.toLowerCase()));
    
    if (!hasTrainType) {
      // Try simpler pattern: just numbers that might be train numbers
      final simpleRegex = RegExp(r'\b(\d{3,5})\b');
      final simpleMatch = simpleRegex.firstMatch(description);
      if (simpleMatch != null) {
        return simpleMatch.group(1);
      }
      return null;
    }
    
    // Match train number patterns: train type + number
    final regex = RegExp(r'\b(TGV|ICE|Shinkansen|Eurostar|Thalys|AVE|Frecciarossa|Trenitalia|Amtrak|Acela|Regional|Express)\s*([A-Z]?\d+)?', caseSensitive: false);
    final match = regex.firstMatch(description);
    if (match != null) {
      final trainType = match.group(1)!;
      final number = match.group(2);
      return number != null ? '$trainType $number' : trainType;
    }
    
    // If we found a train type but no number, return the train type itself
    for (final type in trainTypes) {
      if (description.toLowerCase().contains(type.toLowerCase())) {
        return type;
      }
    }
    
    return null;
  }

  /// Parse train information from description
  /// Returns a map with train type, route name, and cities
  Map<String, String>? _parseTrainInfo(String description) {
    if (description.isEmpty) return null;
    
    final info = <String, String>{};
    
    // Train type keywords
    final trainTypes = ['TGV', 'ICE', 'Shinkansen', 'Eurostar', 'Thalys', 'AVE', 'Frecciarossa', 'Trenitalia', 'Amtrak', 'Acela', 'Regional', 'Express', 'Northeast Regional'];
    
    // Find train type/route name
    for (final type in trainTypes) {
      if (description.toLowerCase().contains(type.toLowerCase())) {
        info['type'] = type;
        
        // Try to extract full route name (e.g., "Amtrak Northeast Regional")
        final routeRegex = RegExp(r'\b(Amtrak\s+(?:Northeast\s+)?Regional|Acela\s+Express|TGV\s+\w+|ICE\s+\d+)', caseSensitive: false);
        final routeMatch = routeRegex.firstMatch(description);
        if (routeMatch != null) {
          info['route'] = routeMatch.group(1)!;
        }
        break;
      }
    }
    
    // Extract city names (common patterns: "X to Y", "X-Y", "X → Y")
    final cityPatterns = [
      RegExp(r'(\w+(?:\s+\w+)*)\s+(?:to|→|-|–)\s+(\w+(?:\s+\w+)*)', caseSensitive: false),
      RegExp(r'(\w+(?:\s+\w+)*)\s+and\s+(\w+(?:\s+\w+)*)', caseSensitive: false),
    ];
    
    for (final pattern in cityPatterns) {
      final match = pattern.firstMatch(description);
      if (match != null) {
        info['fromCity'] = match.group(1)!.trim();
        info['toCity'] = match.group(2)!.trim();
        break;
      }
    }
    
    // Extract train number if present
    final numberRegex = RegExp(r'\b([A-Z]{2,4})\s*(\d{1,4})\b', caseSensitive: false);
    final numberMatch = numberRegex.firstMatch(description);
    if (numberMatch != null) {
      info['number'] = '${numberMatch.group(1)}${numberMatch.group(2)}';
    }
    
    return info.isEmpty ? null : info;
  }

  /// Parse origin and destination place names from train description for geocoding.
  /// E.g. "AVE Barcelona Sants to Madrid Puerta de Atocha" → ("Barcelona Sants", "Madrid Puerta de Atocha")
  ///      "Amtrak Northeast Regional NYC to Washington DC" → ("NYC", "Washington DC")
  ///      "Amtrak Washington DC to Philadelphia 30th Street" → ("Washington DC", "Philadelphia 30th Street")
  (String, String)? _parseTrainOriginDestination(String description) {
    if (description.isEmpty) return null;
    final toPatterns = [' to ', ' → ', ' - ', ' – '];
    int? splitAt;
    String? separator;
    for (final sep in toPatterns) {
      final idx = description.indexOf(sep);
      if (idx != -1 && (splitAt == null || idx < splitAt)) {
        splitAt = idx;
        separator = sep;
      }
    }
    if (splitAt == null || separator == null) return null;
    var fromPart = description.substring(0, splitAt).trim();
    final toPart = description.substring(splitAt + separator.length).trim();
    if (fromPart.isEmpty || toPart.isEmpty) return null;
    // Strip leading train name so we get the place (e.g. "Amtrak Northeast Regional NYC" → "NYC", "AVE Barcelona Sants" → "Barcelona Sants")
    final trainPrefixes = RegExp(
      r'^(?:Amtrak\s+(?:Northeast\s+Regional\s+|Acela\s+Express\s+)?|AVE\s+|TGV\s+\w+\s+|ICE\s+\d+\s+|Eurostar\s+|Thalys\s+)?',
      caseSensitive: false,
    );
    fromPart = fromPart.replaceFirst(trainPrefixes, '').trim();
    if (fromPart.isEmpty) fromPart = description.substring(0, splitAt).trim();
    return (fromPart, toPart);
  }

  /// Create a great circle route (flight path) between two points
  List<LatLng> _createGreatCircleRoute(LatLng from, LatLng to, {int segments = 50}) {
    final points = <LatLng>[];
    
    // Convert to radians
    final lat1 = from.latitude * math.pi / 180;
    final lon1 = from.longitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final lon2 = to.longitude * math.pi / 180;
    
    // Calculate great circle distance
    final d = 2 * math.asin(math.sqrt(
      math.pow(math.sin((lat2 - lat1) / 2), 2) +
      math.cos(lat1) * math.cos(lat2) * math.pow(math.sin((lon2 - lon1) / 2), 2)
    ));
    
    // Handle case where points are the same or very close
    if (d < 0.0001) {
      return [from, to];
    }
    
    // Generate points along the great circle
    for (var i = 0; i <= segments; i++) {
      final f = i / segments;
      
      // Spherical interpolation
      final a = math.sin((1 - f) * d) / math.sin(d);
      final b = math.sin(f * d) / math.sin(d);
      
      final x = a * math.cos(lat1) * math.cos(lon1) + b * math.cos(lat2) * math.cos(lon2);
      final y = a * math.cos(lat1) * math.sin(lon1) + b * math.cos(lat2) * math.sin(lon2);
      final z = a * math.sin(lat1) + b * math.sin(lat2);
      
      final lat = math.atan2(z, math.sqrt(x * x + y * y)) * 180 / math.pi;
      final lon = math.atan2(y, x) * 180 / math.pi;
      
      // Validate coordinates
      if (lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180) {
        points.add(LatLng(lat, lon));
      }
    }
    
    // Ensure start and end points
    if (points.isEmpty || points.first != from) points.insert(0, from);
    if (points.isEmpty || points.last != to) points.add(to);
    
    return points;
  }

  /// Fetch flight route - creates great circle path between airports
  Future<List<LatLng>?> _fetchFlightRoute(
    LatLng from,
    LatLng to,
    String description,
    String fromCity,
    String toCity,
  ) async {
    try {
      final flightNumber = _parseFlightNumber(description);
      if (flightNumber != null) {
        debugPrint('ItineraryMap: Parsed flight number: $flightNumber from description: $description');
        // Create great circle route (actual flight path)
        final route = _createGreatCircleRoute(from, to);
        debugPrint('ItineraryMap: Created great circle route with ${route.length} points');
        return route;
      } else {
        debugPrint('ItineraryMap: Could not parse flight number from: $description');
        // Fallback: create great circle route anyway (planes follow great circle paths)
        return _createGreatCircleRoute(from, to);
      }
    } catch (e) {
      debugPrint('ItineraryMap flight route error: $e');
      // Fallback: create great circle route
      return _createGreatCircleRoute(from, to);
    }
  }

  /// Fetch train route - uses description to get station/place names, geocodes them, then requests transit route
  Future<List<LatLng>?> _fetchTrainRoute(
    LatLng from,
    LatLng to,
    String description,
    String fromCity,
    String toCity,
  ) async {
    try {
      final trainInfo = _parseTrainInfo(description);
      debugPrint('ItineraryMap: Parsed train info: $trainInfo from description: $description');

      LatLng fromWay = from;
      LatLng toWay = to;
      final originDest = _parseTrainOriginDestination(description);
      if (originDest != null) {
        final (fromPlace, toPlace) = originDest;
        debugPrint('ItineraryMap: Geocoding train places: "$fromPlace" → "$toPlace"');
        final fromCoords = await _geocodeNominatim(fromPlace);
        await Future<void>.delayed(const Duration(milliseconds: 1100));
        final toCoords = await _geocodeNominatim(toPlace);
        if (fromCoords != null && toCoords != null) {
          fromWay = LatLng(fromCoords.$1, fromCoords.$2);
          toWay = LatLng(toCoords.$1, toCoords.$2);
          debugPrint('ItineraryMap: Using geocoded station/place coords for transit request');
        } else {
          debugPrint('ItineraryMap: Geocode failed for "$fromPlace" or "$toPlace", using itinerary coords');
        }
      }

      final key = _geoapifyKey;
      if (key == null || key.trim().isEmpty) return null;

      debugPrint('ItineraryMap: Fetching train route from Geoapify transit API');
      var route = await _fetchTransitRoute(fromWay, toWay, key);
      if (route != null && route.isNotEmpty) {
        debugPrint('ItineraryMap: Fetched train route: ${route.length} points');
        return route;
      }
      // If we used geocoded station coords and got nothing, try with original itinerary coords
      if (fromWay != from || toWay != to) {
        debugPrint('ItineraryMap: Retrying transit with itinerary coords');
        route = await _fetchTransitRoute(from, to, key);
        if (route != null && route.isNotEmpty) return route;
      }
      debugPrint('ItineraryMap: No transit route returned for train segment');
      return null;
    } catch (e) {
      debugPrint('ItineraryMap train route error: $e');
      return null;
    }
  }

  /// Fetch transit route (train/public transport) using Geoapify Routing API.
  /// Tries [mode] first, then if [tryApproximated] true, tries approximated_transit.
  Future<List<LatLng>?> _fetchTransitRoute(LatLng from, LatLng to, String apiKey, {bool tryApproximated = true}) async {
    final route = await _fetchTransitRouteWithMode(from, to, apiKey, 'transit');
    if (route != null && route.isNotEmpty) return route;
    if (tryApproximated) {
      debugPrint('ItineraryMap: Trying approximated_transit after transit returned no route');
      return _fetchTransitRouteWithMode(from, to, apiKey, 'approximated_transit');
    }
    return null;
  }

  Future<List<LatLng>?> _fetchTransitRouteWithMode(LatLng from, LatLng to, String apiKey, String mode) async {
    try {
      final url = Uri.parse(
        'https://api.geoapify.com/v1/routing'
        '?waypoints=${from.latitude},${from.longitude}|${to.latitude},${to.longitude}'
        '&mode=$mode'
        '&apiKey=$apiKey',
      );
      debugPrint('ItineraryMap: Fetching $mode route');
      final res = await http.get(url).timeout(_routeTimeout);
      if (res.statusCode != 200) {
        debugPrint('Geoapify $mode error: ${res.statusCode}');
        return null;
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final features = data['features'] as List<dynamic>?;
      if (features == null || features.isEmpty) return null;
      final geometry = features.first['geometry'] as Map<String, dynamic>?;
      final routePoints = _parseGeoJsonRouteGeometry(geometry);
      if (routePoints != null) debugPrint('ItineraryMap: $mode route: ${routePoints.length} points');
      return routePoints;
    } catch (e) {
      debugPrint('ItineraryMap $mode fetch error: $e');
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
    // On web, use WebTileProvider to bypass CORS. On iOS simulator (and other platforms where
    // path_provider_foundation/objective_c can fail), disable built-in tile cache to avoid native crash.
    final TileProvider tileProvider = kIsWeb
        ? WebTileProvider()
        : NetworkTileProvider(cachingProvider: const DisabledMapCachingProvider());
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
    final routeData = widget.fullScreen && _locationStopsWithCoordsList.length >= 2
        ? _buildRouteData(primaryColor)
        : (polylines: <Polyline>[], transportMarkers: <Marker>[]);
    return SizedBox(
      height: widget.height,
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: initialPos,
          initialZoom: 12,
          initialCameraFit: initialFit,
          onTap: (_, point) {
            final nearVenue = _venueStopsWithCoordsList.any((s) =>
                s.lat != null && s.lng != null && _haversineKm(point, LatLng(s.lat!, s.lng!)) < 0.05);
            if (!nearVenue && _selectedVenue != null && mounted) {
              setState(() => _selectedVenue = null);
            }
          },
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
          if (widget.fullScreen && _locationStopsWithCoordsList.length >= 2 && routeData.polylines.isNotEmpty)
            PolylineLayer(polylines: routeData.polylines)
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
              // City markers (locations) - larger circles. In full-screen route view, skip origin (first stop) and show dots from second stop through end of route.
              ..._orderedLocationStopsForMarkers.map((stop) => Marker(
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
              // Venue markers (spots) - orange flags, tap shows name above (flag stays fixed)
              ..._venueStopsWithCoordsList.map((stop) => _buildVenueFlagMarker(stop)),
            ],
          ),
          if (_selectedVenue != null)
            MarkerLayer(markers: _buildSelectedVenueLabelMarker()),
          if (widget.fullScreen && _locationStopsWithCoordsList.length >= 2 && routeData.transportMarkers.isNotEmpty)
            MarkerLayer(markers: routeData.transportMarkers),
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

  /// Venue marker: small square (24x24) so zoom doesn't drift. Tap shows name in a separate label marker above.
  Marker _buildVenueFlagMarker(ItineraryStop stop) {
    return Marker(
      point: LatLng(stop.lat!, stop.lng!),
      width: 24,
      height: 24,
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedVenue = _selectedVenue?.id == stop.id ? null : stop;
          });
        },
        child: Icon(Icons.flag_rounded, size: 22, color: Colors.orange),
      ),
    );
  }

  /// Label marker shown above the selected venue flag (separate from flag so flag size stays square and zoom is correct).
  static const _labelOffsetLat = 0.00025;

  List<Marker> _buildSelectedVenueLabelMarker() {
    final stop = _selectedVenue;
    if (stop == null || stop.lat == null || stop.lng == null) return [];
    final pointAbove = LatLng(stop.lat! + _labelOffsetLat, stop.lng!);
    return [
      Marker(
        point: pointAbove,
        width: 130,
        height: 44,
        alignment: Alignment.bottomCenter,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.5), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            stop.name,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ];
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

  /// Point at half the path length along the polyline (true center for placing transport icon).
  LatLng _midpointOf(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(0, 0);
    if (points.length == 1) return points.first;
    if (points.length == 2) {
      final a = points[0];
      final b = points[1];
      return LatLng(
        (a.latitude + b.latitude) / 2,
        (a.longitude + b.longitude) / 2,
      );
    }
    // Sum segment lengths and find point at half total distance
    double total = 0;
    final segLengths = <double>[];
    for (var i = 0; i < points.length - 1; i++) {
      final d = _haversineKm(points[i], points[i + 1]);
      segLengths.add(d);
      total += d;
    }
    if (total <= 0) return points[points.length ~/ 2];
    final half = total / 2;
    double acc = 0;
    for (var i = 0; i < segLengths.length; i++) {
      if (acc + segLengths[i] >= half) {
        final t = (half - acc) / segLengths[i];
        final a = points[i];
        final b = points[i + 1];
        return LatLng(
          a.latitude + t * (b.latitude - a.latitude),
          a.longitude + t * (b.longitude - a.longitude),
        );
      }
      acc += segLengths[i];
    }
    return points[points.length ~/ 2];
  }

  double _haversineKm(LatLng a, LatLng b) {
    const R = 6371.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final x = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(a.latitude * math.pi / 180) *
            math.cos(b.latitude * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return R * 2 * math.atan2(math.sqrt(x), math.sqrt(1 - x));
  }

  ({List<Polyline> polylines, List<Marker> transportMarkers}) _buildRouteData(Color primaryColor) {
    final locationStops = _locationStopsWithCoordsList;
    if (locationStops.length < 2) return (polylines: [], transportMarkers: []);
    
    final ordered = List<ItineraryStop>.from(locationStops)
      ..sort((a, b) {
        final dayCmp = a.day.compareTo(b.day);
        return dayCmp != 0 ? dayCmp : a.position.compareTo(b.position);
      });

    final transitions = widget.transportTransitions ?? [];
    final polylines = <Polyline>[];
    final transportMarkers = <Marker>[];
    
    for (var i = 0; i < ordered.length - 1; i++) {
      final from = ordered[i];
      final to = ordered[i + 1];
      
      if (from.lat == null || from.lng == null || to.lat == null || to.lng == null) continue;
      
      final fromPoint = LatLng(from.lat!, from.lng!);
      final toPoint = LatLng(to.lat!, to.lng!);
      
      final transition = i < transitions.length ? transitions[i] : null;
      final transportType = transition?.type.toLowerCase() ?? 'unknown';
      final isPlane = transportType == 'plane';
      final isBoat = transportType == 'boat';
      
      List<LatLng> segmentPoints;
      bool solidLine;

      if (isPlane) {
        // Flights: always solid curved (great circle) line
        segmentPoints = _createGreatCircleRoute(fromPoint, toPoint);
        solidLine = true;
      } else if (isBoat) {
        // Boats: dotted curved line
        segmentPoints = _createCurvedLine(fromPoint, toPoint);
        solidLine = false;
      } else if (_routedSegments != null && _routedSegments!.containsKey(i)) {
        // Train or car with fetched route: solid line
        final route = _routedSegments![i]!;
        final validRoute = route.where((p) => 
          p.latitude >= -90 && p.latitude <= 90 && 
          p.longitude >= -180 && p.longitude <= 180
        ).toList();
        if (validRoute.length >= 2) {
          segmentPoints = validRoute;
          solidLine = true;
        } else {
          segmentPoints = _createCurvedLine(fromPoint, toPoint);
          solidLine = false;
        }
      } else {
        // No route (train/car/other): dotted curved
        segmentPoints = _createCurvedLine(fromPoint, toPoint);
        solidLine = false;
      }

      if (segmentPoints.length < 2) continue;

      if (solidLine) {
        polylines.add(Polyline(
          points: segmentPoints,
          color: primaryColor,
          strokeWidth: isPlane ? 3 : 5,
        ));
      } else {
        polylines.add(Polyline(
          points: segmentPoints,
          color: primaryColor,
          strokeWidth: 4,
          pattern: StrokePattern.dashed(segments: [10, 8]),
        ));
      }

      final mid = _midpointOf(segmentPoints);
      // Only show transport icon if midpoint is clearly on the line, not at a station
      final distFromStart = _haversineKm(fromPoint, mid);
      final distFromEnd = _haversineKm(mid, toPoint);
      final minDistKm = 0.5;
      if (distFromStart >= minDistKm && distFromEnd >= minDistKm) {
        final iconData = _transportIconFor(transportType);
        transportMarkers.add(Marker(
          point: mid,
          width: 28,
          height: 28,
          alignment: Alignment.center,
          child: Center(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: primaryColor, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(iconData, size: 16, color: primaryColor),
            ),
          ),
        ));
      }
    }
    
    return (polylines: polylines, transportMarkers: transportMarkers);
  }

  IconData _transportIconFor(String transportType) {
    switch (transportType) {
      case 'train':
        return Icons.train;
      case 'car':
        return Icons.directions_car;
      case 'plane':
        return Icons.flight;
      case 'boat':
        return Icons.directions_boat;
      default:
        return Icons.directions_transit;
    }
  }
}
