import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../l10n/app_strings.dart';
import '../models/itinerary.dart';

/// Transport type for timeline connectors.
enum TransportType {
  plane,
  train,
  car,
  bus,
  boat,
  walk,
  other,
  unknown,
}

/// Parse transport string from DB to TransportType.
/// Accepts legacy 'ferry' as boat.
TransportType transportTypeFromString(String? s) {
  if (s == null || s.isEmpty) return TransportType.unknown;
  switch (s.toLowerCase()) {
    case 'plane': return TransportType.plane;
    case 'train': return TransportType.train;
    case 'car': return TransportType.car;
    case 'bus': return TransportType.bus;
    case 'boat':
    case 'ferry': return TransportType.boat;
    case 'walk': return TransportType.walk;
    case 'other': return TransportType.other;
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

String _categoryLabel(BuildContext context, String category) {
  switch (category) {
    case 'experience': return AppStrings.t(context, 'experience');
    case 'restaurant': return AppStrings.t(context, 'restaurant');
    case 'hotel': return AppStrings.t(context, 'hotel');
    case 'guide': return AppStrings.t(context, 'guide');
    case 'bar': return AppStrings.t(context, 'drinks');
    default: return AppStrings.t(context, 'experience');
  }
}

/// Vertical dotted connector between location cards with transport icon.
/// Renders in the gap between cards - does not affect card layout.
/// If [description] is provided and non-empty, tapping shows it in a dialog.
class TimelineConnector extends StatelessWidget {
  final TransportType transport;
  final String? description;

  static const double _gapHeight = 80;
  static const double _lineWidth = 2;
  static const double _iconSize = 24;
  static const double _connectorWidth = 32;

  const TimelineConnector({super.key, this.transport = TransportType.unknown, this.description});

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
    final content = SizedBox(
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

    final hasDescription = description != null && description!.trim().isNotEmpty;
    if (hasDescription) {
      return GestureDetector(
        onTap: () => _showTransportDescription(context),
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }
    return content;
  }

  void _showTransportDescription(BuildContext context) {
    if (description == null || description!.trim().isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconFor(transport), color: Theme.of(ctx).colorScheme.primary),
            const SizedBox(width: 8),
            Text(_labelFor(transport)),
          ],
        ),
        content: Text(description!.trim()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(AppStrings.t(context, 'close')),
          ),
        ],
      ),
    );
  }

  String _labelFor(TransportType t) {
    switch (t) {
      case TransportType.plane: return 'Plane';
      case TransportType.train: return 'Train';
      case TransportType.car: return 'Car';
      case TransportType.bus: return 'Bus';
      case TransportType.boat: return 'Boat';
      case TransportType.walk: return 'Walk';
      case TransportType.other: return 'Other';
      case TransportType.unknown: return 'Transport';
    }
  }

  IconData _iconFor(TransportType t) {
    switch (t) {
      case TransportType.plane:
        return Icons.flight_rounded;
      case TransportType.train:
        return Icons.train_rounded;
      case TransportType.car:
        return Icons.directions_car_rounded;
      case TransportType.bus:
        return Icons.directions_bus_rounded;
      case TransportType.boat:
        return Icons.directions_boat_rounded;
      case TransportType.walk:
        return Icons.directions_walk_rounded;
      case TransportType.other:
        return Icons.help_outline_rounded;
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
/// [showLocationName] when false, omits the place name (for subsequent same-place cards).
class LocationCard extends StatelessWidget {
  final int day;
  final List<ItineraryStop> locations;
  final List<ItineraryStop> venues;
  final void Function(ItineraryStop) onOpenInMaps;
  final bool showLocationName;

  const LocationCard({
    super.key,
    required this.day,
    required this.locations,
    required this.venues,
    required this.onOpenInMaps,
    this.showLocationName = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locationName = locations.isNotEmpty ? locations.first.name : '${AppStrings.t(context, 'day')} $day';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
                      '${AppStrings.t(context, 'day')} $day',
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      if (showLocationName)
                        Text(
                          locationName,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      if (showLocationName && (locations.length > 1 || venues.isNotEmpty))
                        const SizedBox(height: AppTheme.spacingSm),
                      if (locations.length > 1) ...[
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
                              ? Text(_categoryLabel(context, s.category!), style: theme.textTheme.bodySmall)
                              : null,
                          trailing: Icon(Icons.open_in_new, size: 18, color: theme.colorScheme.onSurfaceVariant),
                          onTap: () => onOpenInMaps(s),
                        )),
                      ],
                      if (locations.isNotEmpty && venues.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: AppTheme.spacingSm),
                          child: Text(AppStrings.t(context, 'no_places_added'), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        ),
                    ],
                ),
              ),
            ),
          ),
        ],
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

/// Optional descriptions per transport transition (index -> description).
typedef TransportDescriptions = Map<int, String>;

/// Returns empty widget when primary location is the same on consecutive days;
/// otherwise returns the dotted TimelineConnector.
Widget _buildConnectorIfDifferentPlace({
  required List<ItineraryStop> dayILocations,
  required List<ItineraryStop> dayNextLocations,
  required TransportType transport,
  String? description,
}) {
  final loc1 = dayILocations.isNotEmpty ? dayILocations.first : null;
  final loc2 = dayNextLocations.isNotEmpty ? dayNextLocations.first : null;
  if (loc1 == null || loc2 == null) return const SizedBox.shrink();
  // Same place = same primary location (by name; coords if both have them)
  final sameName = loc1.name == loc2.name;
  final sameCoords = loc1.lat != null && loc1.lng != null && loc2.lat != null && loc2.lng != null
      ? (loc1.lat == loc2.lat && loc1.lng == loc2.lng)
      : sameName;
  if (sameName && (loc1.lat == null || loc2.lat == null || sameCoords)) {
    return const SizedBox.shrink();
  }
  // Match LocationCard layout: Row with day column (56) + spacing + centered connector
  return Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      const SizedBox(width: 56),
      const SizedBox(width: AppTheme.spacingMd),
      Expanded(
        child: Center(
          child: TimelineConnector(transport: transport, description: description),
        ),
      ),
    ],
  );
}

/// Reusable timeline: location cards with dotted connectors and transport icons.
/// [transportOverrides] is optional: Map<transitionIndex, TransportType>. Default: unknown.
/// [transportDescriptions] is optional: Map<transitionIndex, description> for tap-to-show.
class ItineraryTimeline extends StatelessWidget {
  final Itinerary itinerary;
  final TransportOverrides? transportOverrides;
  final TransportDescriptions? transportDescriptions;
  final void Function(ItineraryStop) onOpenInMaps;

  const ItineraryTimeline({
    super.key,
    required this.itinerary,
    this.transportOverrides,
    this.transportDescriptions,
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
              Text(AppStrings.t(context, 'no_places_yet'), style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }

    // Build visible items: skip subsequent same-place cards with no venues
    final visible = <_VisibleDay>[];
    for (var i = 0; i < sortedDays.length; i++) {
      final day = sortedDays[i];
      final dayLocs = stopsByDay[day]!.where((s) => s.isLocation).toList();
      final dayVenues = stopsByDay[day]!.where((s) => s.isVenue).toList();
      final primaryLoc = dayLocs.isNotEmpty ? dayLocs.first : null;
      final prevLoc = visible.isNotEmpty && visible.last.locations.isNotEmpty ? visible.last.locations.first : null;
      final samePlace = primaryLoc != null && prevLoc != null &&
          primaryLoc.name == prevLoc.name &&
          (primaryLoc.lat == null || prevLoc.lat == null || (primaryLoc.lat == prevLoc.lat && primaryLoc.lng == prevLoc.lng));
      if (samePlace && dayVenues.isEmpty) continue; // Skip subsequent same-place with no info
      visible.add(_VisibleDay(day: day, locations: dayLocs, venues: dayVenues, showLocationName: !samePlace, originalIndex: i));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var v = 0; v < visible.length; v++) ...[
          LocationCard(
            day: visible[v].day,
            locations: visible[v].locations,
            venues: visible[v].venues,
            onOpenInMaps: onOpenInMaps,
            showLocationName: visible[v].showLocationName,
          ),
          if (v < visible.length - 1) ...[
            _buildConnectorIfDifferentPlace(
              dayILocations: visible[v].locations,
              dayNextLocations: visible[v + 1].locations,
              transport: transportOverrides?[visible[v].originalIndex] ?? TransportType.unknown,
              description: transportDescriptions?[visible[v].originalIndex],
            ),
          ],
        ],
      ],
    );
  }
}

class _VisibleDay {
  final int day;
  final List<ItineraryStop> locations;
  final List<ItineraryStop> venues;
  final bool showLocationName;
  final int originalIndex;

  _VisibleDay({required this.day, required this.locations, required this.venues, required this.showLocationName, required this.originalIndex});
}
