import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/itinerary.dart';

/// Transport type for timeline connectors.
enum TransportType {
  plane,
  train,
  car,
  ferry,
  walk,
  unknown,
}

/// Parse transport string from DB to TransportType.
TransportType transportTypeFromString(String? s) {
  if (s == null || s.isEmpty) return TransportType.unknown;
  switch (s.toLowerCase()) {
    case 'plane': return TransportType.plane;
    case 'train': return TransportType.train;
    case 'car': return TransportType.car;
    case 'ferry': return TransportType.ferry;
    case 'walk': return TransportType.walk;
    default: return TransportType.unknown;
  }
}

/// Serialize TransportType to string for DB.
String transportTypeToString(TransportType t) {
  if (t == TransportType.unknown) return 'unknown';
  return t.name;
}

/// Optional transport override per transition index (0 = between first and second card).
/// When absent, falls back to [TransportType.unknown].
typedef TransportOverrides = Map<int, TransportType>;

/// Optional UI-only config: lookup transport by (fromLocationId, toLocationId).
/// Use [buildOverridesFromStops] to convert to [TransportOverrides] for [ItineraryTimeline].
class TransportConfig {
  final Map<(String, String), TransportType> _map = {};

  void set(String fromLocationId, String toLocationId, TransportType type) {
    _map[(fromLocationId, toLocationId)] = type;
  }

  TransportType? get(String fromLocationId, String toLocationId) =>
      _map[(fromLocationId, toLocationId)];

  /// Build [TransportOverrides] from an itinerary's ordered location stops.
  /// Returns null if no entries match (caller can omit transportOverrides).
  TransportOverrides? buildOverridesFromStops(List<ItineraryStop> locationStops) {
    final overrides = <int, TransportType>{};
    for (var i = 0; i < locationStops.length - 1; i++) {
      final t = get(locationStops[i].id, locationStops[i + 1].id);
      if (t != null) overrides[i] = t;
    }
    return overrides.isEmpty ? null : overrides;
  }
}

/// Vertical dotted connector between location cards with transport icon.
/// Renders in the gap between cards - does not affect card layout.
class TimelineConnector extends StatelessWidget {
  final TransportType transport;
  static const double _gapHeight = 80;
  static const double _lineWidth = 2;
  static const double _iconSize = 24;
  static const double _connectorWidth = 32;

  const TimelineConnector({super.key, this.transport = TransportType.unknown});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline.withValues(alpha: 0.6);
    final halfGap = (_gapHeight - _iconSize) / 2;
    final centerWidget = transport == TransportType.unknown
        ? Container(
            width: _iconSize,
            height: _iconSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
          )
        : Icon(_iconFor(transport), size: _iconSize, color: color);
    return SizedBox(
      height: _gapHeight,
      width: _connectorWidth,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: halfGap,
            width: _connectorWidth,
            child: Center(
              child: SizedBox(
                width: _lineWidth,
                height: halfGap,
                child: CustomPaint(
                  painter: _DottedLinePainter(color: color, lineWidth: _lineWidth),
                  size: Size(_lineWidth, halfGap),
                ),
              ),
            ),
          ),
          centerWidget,
          SizedBox(
            height: halfGap,
            width: _connectorWidth,
            child: Center(
              child: SizedBox(
                width: _lineWidth,
                height: halfGap,
                child: CustomPaint(
                  painter: _DottedLinePainter(color: color, lineWidth: _lineWidth),
                  size: Size(_lineWidth, halfGap),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(TransportType t) {
    switch (t) {
      case TransportType.plane:
        return Icons.flight_rounded;
      case TransportType.train:
        return Icons.train_rounded;
      case TransportType.car:
        return Icons.directions_car_rounded;
      case TransportType.ferry:
        return Icons.directions_boat_rounded;
      case TransportType.walk:
        return Icons.directions_walk_rounded;
      case TransportType.unknown:
        return Icons.swap_horiz_rounded;
    }
  }
}

class _DottedLinePainter extends CustomPainter {
  final Color color;
  final double lineWidth;

  _DottedLinePainter({required this.color, required this.lineWidth});

  @override
  void paint(Canvas canvas, Size size) {
    const dashHeight = 4.0;
    const gapHeight = 4.0;
    var y = 0.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.fill;

    while (y < size.height) {
      final dotHeight = (y + dashHeight <= size.height) ? dashHeight : size.height - y;
      final x = (size.width - lineWidth) / 2;
      canvas.drawRect(Rect.fromLTWH(x, y, lineWidth, dotHeight), paint);
      y += dashHeight + gapHeight;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Single location card: day/date in left rail, location(s), venues.
class LocationCard extends StatelessWidget {
  final int day;
  final List<ItineraryStop> locations;
  final List<ItineraryStop> venues;
  final void Function(ItineraryStop) onOpenInMaps;

  const LocationCard({
    super.key,
    required this.day,
    required this.locations,
    required this.venues,
    required this.onOpenInMaps,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locationName = locations.isNotEmpty ? locations.first.name : 'Day $day';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 56,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Day $day',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacingMd),
          Expanded(
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        locationName,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (locations.length > 1) ...[
                        const SizedBox(height: AppTheme.spacingSm),
                        Wrap(
                          spacing: AppTheme.spacingXs,
                          runSpacing: AppTheme.spacingXs,
                          children: locations.skip(1).map((loc) => _LocationChip(
                            stop: loc,
                            onTap: () => onOpenInMaps(loc),
                          )).toList(),
                        ),
                      ],
                      if (venues.isNotEmpty) ...[
                        const SizedBox(height: AppTheme.spacingMd),
                        ...venues.map((s) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Icon(Icons.place_outlined, size: 22, color: theme.colorScheme.onPrimaryContainer),
                          ),
                          title: Text(s.name, style: theme.textTheme.titleSmall),
                          subtitle: s.category != null && s.category != 'location'
                              ? Text(s.category!, style: theme.textTheme.bodySmall)
                              : null,
                          trailing: Icon(Icons.open_in_new, size: 18, color: theme.colorScheme.onSurfaceVariant),
                          onTap: () => onOpenInMaps(s),
                        )),
                      ],
                      if (locations.isNotEmpty && venues.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: AppTheme.spacingSm),
                          child: Text('No places added', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        ),
                    ],
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

class _LocationChip extends StatelessWidget {
  final ItineraryStop stop;
  final VoidCallback onTap;

  const _LocationChip({required this.stop, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_city_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(stop.name, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface)),
            const SizedBox(width: 4),
            Icon(Icons.open_in_new, size: 14, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Reusable timeline: location cards with dotted connectors and transport icons.
/// [transportOverrides] is optional: Map<transitionIndex, TransportType>. Default: unknown.
class ItineraryTimeline extends StatelessWidget {
  final Itinerary itinerary;
  final TransportOverrides? transportOverrides;
  final void Function(ItineraryStop) onOpenInMaps;

  const ItineraryTimeline({
    super.key,
    required this.itinerary,
    this.transportOverrides,
    required this.onOpenInMaps,
  });

  @override
  Widget build(BuildContext context) {
    final stopsByDay = <int, List<ItineraryStop>>{};
    for (final s in itinerary.stops) {
      stopsByDay.putIfAbsent(s.day, () => []).add(s);
    }
    for (final list in stopsByDay.values) {
      list.sort((a, b) => a.position.compareTo(b.position));
    }
    final sortedDays = stopsByDay.keys.toList()..sort();

    if (sortedDays.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingXl),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.place_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: AppTheme.spacingMd),
              Text('No places yet', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < sortedDays.length; i++) ...[
          LocationCard(
            day: sortedDays[i],
            locations: stopsByDay[sortedDays[i]]!.where((s) => s.isLocation).toList(),
            venues: stopsByDay[sortedDays[i]]!.where((s) => s.isVenue).toList(),
            onOpenInMaps: onOpenInMaps,
          ),
          if (i < sortedDays.length - 1)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(width: 56),
                const SizedBox(width: AppTheme.spacingMd),
                Expanded(
                  child: Center(
                    child: TimelineConnector(
                      transport: transportOverrides?[i] ?? TransportType.unknown,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ],
    );
  }
}
