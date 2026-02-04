import 'dart:math' as math;
import '../models/itinerary.dart';
import '../widgets/itinerary_timeline.dart' show TransportType, transportTypeToString;

/// Allocates [daysCount] across [numCities] deterministically.
/// First city gets ceil(daysCount*0.5) capped at (daysCount - (N-1)); remaining distributed so each city gets >= 1.
/// Total allocated always equals [daysCount].
List<int> allocateDaysAcrossCities(int daysCount, int numCities) {
  if (numCities <= 0) return [];
  if (numCities == 1) return [daysCount];
  final first = math.min(
    (daysCount * 0.5).ceil().clamp(1, daysCount),
    daysCount - (numCities - 1),
  ).clamp(1, daysCount);
  final result = <int>[first];
  var remaining = daysCount - first;
  for (var i = 1; i < numCities; i++) {
    result.add(1);
    remaining -= 1;
  }
  var idx = 1;
  while (remaining > 0 && idx < numCities) {
    result[idx] += 1;
    remaining -= 1;
    idx += 1;
  }
  return result;
}

/// Redistributes [daysCount] evenly across [numCities]. Each gets daysCount ~/ n, remainder distributed from start.
List<int> autoBalanceDays(int daysCount, int numCities) {
  if (numCities <= 0) return [];
  if (numCities == 1) return [daysCount];
  final base = daysCount ~/ numCities;
  final remainder = daysCount % numCities;
  return List.generate(numCities, (i) => base + (i < remainder ? 1 : 0));
}

/// Pair of (city index, day number) in chronological order for building stops.
typedef CityDayPair = ({int cityIndex, int day});

/// Builds chronological (cityIndex, day) pairs from city day-count allocations.
/// [allocations] length must match number of cities; sum must equal total days.
List<CityDayPair> buildChronologicalPairsFromAllocations(List<int> allocations) {
  final pairs = <CityDayPair>[];
  var day = 1;
  for (var i = 0; i < allocations.length; i++) {
    final count = allocations[i].clamp(0, 999);
    for (var d = 0; d < count; d++) {
      pairs.add((cityIndex: i, day: day));
      day += 1;
    }
  }
  return pairs;
}

/// Approximate distance in km between two points (Haversine).
double _distanceKm(double? lat1, double? lng1, double? lat2, double? lng2) {
  if (lat1 == null || lng1 == null || lat2 == null || lng2 == null) return double.infinity;
  const R = 6371.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLng = (lng2 - lng1) * math.pi / 180;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) * math.sin(dLng / 2) * math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return R * c;
}

/// Infer transport type between two consecutive location stops from distance (and optional same-country hint).
/// sameCityConsecutiveDays -> unknown; <=2km -> walk; 2–250km -> train; 250–800km -> train (or plane if !sameCountry); >800km -> plane.
TransportType inferTransportType({
  required double? fromLat,
  required double? fromLng,
  required double? toLat,
  required double? toLng,
  bool sameCityConsecutiveDays = false,
  bool sameCountry = true,
}) {
  if (sameCityConsecutiveDays) return TransportType.unknown;
  final km = _distanceKm(fromLat, fromLng, toLat, toLng);
  if (km.isInfinite || km <= 0) return TransportType.unknown;
  if (km <= 2) return TransportType.walk;
  if (km <= 250) return TransportType.train;
  if (km <= 800) return sameCountry ? TransportType.train : TransportType.plane;
  return TransportType.plane;
}

/// Build list of TransportTransition for chronological pairs; length == pairs.length - 1.
/// [getCoords] returns (lat, lng) for the city at pair's cityIndex.
/// [userOverrides] optional map segmentIndex -> (type, description?); if null or missing, use inferred.
List<TransportTransition> inferTransportTransitions(
  List<CityDayPair> pairs,
  double? Function(int cityIndex) getLat,
  double? Function(int cityIndex) getLng, {
  Map<int, ({TransportType type, String? description})>? userOverrides,
}) {
  if (pairs.length < 2) return [];
  final result = <TransportTransition>[];
  for (var i = 0; i < pairs.length - 1; i++) {
    final fromCity = pairs[i].cityIndex;
    final toCity = pairs[i + 1].cityIndex;
    final samePlace = fromCity == toCity;
    final override = userOverrides?[i];
    if (override != null) {
      result.add(TransportTransition(
        type: transportTypeToString(override.type),
        description: override.description?.trim().isEmpty == true ? null : override.description?.trim(),
      ));
      continue;
    }
    if (samePlace) {
      result.add(const TransportTransition(type: 'unknown'));
      continue;
    }
    final fromLat = getLat(fromCity);
    final fromLng = getLng(fromCity);
    final toLat = getLat(toCity);
    final toLng = getLng(toCity);
    final inferred = inferTransportType(
      fromLat: fromLat,
      fromLng: fromLng,
      toLat: toLat,
      toLng: toLng,
      sameCityConsecutiveDays: false,
      sameCountry: true,
    );
    result.add(TransportTransition(type: transportTypeToString(inferred)));
  }
  return result;
}

