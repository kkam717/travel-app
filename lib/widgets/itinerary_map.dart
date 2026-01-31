import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/itinerary.dart';

class ItineraryMap extends StatefulWidget {
  final List<ItineraryStop> stops;
  final double height;

  const ItineraryMap({super.key, required this.stops, this.height = 280});

  @override
  State<ItineraryMap> createState() => _ItineraryMapState();
}

class _ItineraryMapState extends State<ItineraryMap> {
  final Completer<GoogleMapController> _controller = Completer();
  static const _defaultCenter = LatLng(40.0, -3.0);

  Set<Marker> get _markers {
    final stopsWithCoords = widget.stops.where((s) => s.lat != null && s.lng != null).toList();
    return stopsWithCoords.asMap().entries.map((e) {
      final i = e.key + 1;
      final s = e.value;
      return Marker(
        markerId: MarkerId(s.id),
        position: LatLng(s.lat!, s.lng!),
        infoWindow: InfoWindow(title: s.name, snippet: 'Stop $i'),
      );
    }).toSet();
  }

  List<LatLng> get _polylinePoints {
    return widget.stops
        .where((s) => s.lat != null && s.lng != null)
        .map((s) => LatLng(s.lat!, s.lng!))
        .toList();
  }

  LatLngBounds? _bounds() {
    final points = _polylinePoints;
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
    final hasCoords = widget.stops.any((s) => s.lat != null && s.lng != null);
    if (!hasCoords) {
      return Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text('No map data', style: TextStyle(color: Colors.grey[600])),
            ],
          ),
        ),
      );
    }

    final initialPos = _polylinePoints.isNotEmpty ? _polylinePoints.first : _defaultCenter;
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: initialPos, zoom: 12),
          mapType: MapType.normal,
          markers: _markers,
          polylines: {
            if (_polylinePoints.length >= 2)
              Polyline(
                polylineId: const PolylineId('route'),
                points: _polylinePoints,
                color: Theme.of(context).colorScheme.primary,
                width: 4,
              ),
          },
          onMapCreated: (ctrl) {
            _controller.complete(ctrl);
            if (mounted) _fitBounds();
          },
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
          },
          myLocationButtonEnabled: true,
          zoomControlsEnabled: true,
        ),
      ),
    );
  }
}
