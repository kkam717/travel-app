bool? _parseBool(dynamic v) {
  if (v == null) return null;
  if (v is bool) return v;
  if (v is String) return v.toLowerCase() == 'true';
  return null;
}

/// A single transport transition between consecutive locations.
/// Supports legacy format (string only) and new format (type + description).
class TransportTransition {
  final String type; // plane, train, car, bus, boat, walk, other, unknown
  final String? description;

  const TransportTransition({required this.type, this.description});

  factory TransportTransition.fromJson(dynamic json) {
    if (json == null) return const TransportTransition(type: 'unknown');
    if (json is String) return TransportTransition(type: json);
    if (json is Map<String, dynamic>) {
      return TransportTransition(
        type: json['type'] as String? ?? 'unknown',
        description: json['description'] as String?,
      );
    }
    return const TransportTransition(type: 'unknown');
  }

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{'type': type};
    if (description != null && description!.trim().isNotEmpty) m['description'] = description;
    return m;
  }
}

class Itinerary {
  final String id;
  final String authorId;
  final String? authorName;
  final String? authorPhotoUrl;
  final String title;
  final String destination;
  final int daysCount;
  final List<String> styleTags;
  final String? mode;
  final String visibility;
  final String? forkedFromItineraryId;
  final List<ItineraryStop> stops;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? stopsCount;
  final int? bookmarkCount;
  final int? likeCount;
  final bool? useDates;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? durationYear;
  final int? durationMonth;
  final String? durationSeason;
  final List<TransportTransition>? transportTransitions;

  const Itinerary({
    required this.id,
    required this.authorId,
    this.authorName,
    this.authorPhotoUrl,
    required this.title,
    required this.destination,
    required this.daysCount,
    this.styleTags = const [],
    this.mode,
    this.visibility = 'private',
    this.forkedFromItineraryId,
    this.stops = const [],
    this.createdAt,
    this.updatedAt,
    this.stopsCount,
    this.bookmarkCount,
    this.likeCount,
    this.useDates,
    this.startDate,
    this.endDate,
    this.durationYear,
    this.durationMonth,
    this.durationSeason,
    this.transportTransitions,
  });

  factory Itinerary.fromJson(Map<String, dynamic> json, {List<ItineraryStop>? stops}) {
    return Itinerary(
      id: json['id'] as String,
      authorId: json['author_id'] as String,
      authorName: json['profiles']?['name'] as String?,
      authorPhotoUrl: json['profiles']?['photo_url'] as String?,
      title: json['title'] as String,
      destination: json['destination'] as String,
      daysCount: json['days_count'] as int,
      styleTags: List<String>.from(json['style_tags'] ?? []),
      mode: json['mode'] as String?,
      visibility: json['visibility'] as String? ?? 'private',
      forkedFromItineraryId: json['forked_from_itinerary_id'] as String?,
      stops: stops ?? [],
      stopsCount: json['stops_count'] as int?,
      bookmarkCount: (json['bookmark_count'] as num?)?.toInt(),
      likeCount: (json['like_count'] as num?)?.toInt(),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      useDates: _parseBool(json['use_dates']),
      startDate: json['start_date'] != null ? DateTime.parse(json['start_date'] as String) : null,
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date'] as String) : null,
      durationYear: (json['duration_year'] as num?)?.toInt(),
      durationMonth: (json['duration_month'] as num?)?.toInt(),
      durationSeason: json['duration_season'] as String?,
      transportTransitions: json['transport_transitions'] != null
          ? (json['transport_transitions'] as List).map((e) => TransportTransition.fromJson(e)).toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'author_id': authorId,
      'title': title,
      'destination': destination,
      'days_count': daysCount,
      'style_tags': styleTags,
      'mode': mode,
      'visibility': visibility,
      'forked_from_itinerary_id': forkedFromItineraryId,
      'updated_at': DateTime.now().toIso8601String(),
      if (useDates != null) 'use_dates': useDates,
      if (startDate != null) 'start_date': startDate!.toIso8601String().split('T').first,
      if (endDate != null) 'end_date': endDate!.toIso8601String().split('T').first,
      if (durationYear != null) 'duration_year': durationYear,
      if (durationMonth != null) 'duration_month': durationMonth,
      if (durationSeason != null) 'duration_season': durationSeason,
      if (transportTransitions != null && transportTransitions!.isNotEmpty)
        'transport_transitions': transportTransitions!.map((t) => t.toJson()).toList(),
    };
  }

  bool get hasMapStops => stops.any((s) => s.lat != null && s.lng != null);

  Itinerary copyWith({
    List<ItineraryStop>? stops,
    int? stopsCount,
    int? bookmarkCount,
    int? likeCount,
    bool? useDates,
    DateTime? startDate,
    DateTime? endDate,
    int? durationYear,
    int? durationMonth,
    String? durationSeason,
    List<TransportTransition>? transportTransitions,
  }) =>
      Itinerary(
        id: id,
        authorId: authorId,
        authorName: authorName,
        authorPhotoUrl: authorPhotoUrl,
        title: title,
        destination: destination,
        daysCount: daysCount,
        styleTags: styleTags,
        mode: mode,
        visibility: visibility,
        forkedFromItineraryId: forkedFromItineraryId,
        stops: stops ?? this.stops,
        createdAt: createdAt,
        updatedAt: updatedAt,
        stopsCount: stopsCount ?? this.stopsCount,
        bookmarkCount: bookmarkCount ?? this.bookmarkCount,
        likeCount: likeCount ?? this.likeCount,
        useDates: useDates ?? this.useDates,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        durationYear: durationYear ?? this.durationYear,
        durationMonth: durationMonth ?? this.durationMonth,
        durationSeason: durationSeason ?? this.durationSeason,
        transportTransitions: transportTransitions ?? this.transportTransitions,
      );
}

class ItineraryStop {
  final String id;
  final String itineraryId;
  final int position;
  final int day;
  final String name;
  final String? category;
  final String? stopType; // 'location' = city/town, 'venue' = restaurant/bar/hotel
  final String? externalUrl;
  final double? lat;
  final double? lng;
  final String? placeId;
  final String? googlePlaceId;

  const ItineraryStop({
    required this.id,
    required this.itineraryId,
    required this.position,
    this.day = 1,
    required this.name,
    this.category,
    this.stopType,
    this.externalUrl,
    this.lat,
    this.lng,
    this.placeId,
    this.googlePlaceId,
  });

  bool get isLocation => stopType == 'location';
  bool get isVenue => stopType != 'location';

  factory ItineraryStop.fromJson(Map<String, dynamic> json) {
    return ItineraryStop(
      id: json['id'] as String,
      itineraryId: json['itinerary_id'] as String,
      position: json['position'] as int,
      day: json['day'] as int? ?? 1,
      name: json['name'] as String,
      category: json['category'] as String?,
      stopType: json['stop_type'] as String?,
      externalUrl: json['external_url'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      placeId: json['place_id'] as String?,
      googlePlaceId: json['google_place_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itinerary_id': itineraryId,
      'position': position,
      'day': day,
      'name': name,
      'category': category,
      'stop_type': stopType,
      'external_url': externalUrl,
      'lat': lat,
      'lng': lng,
      'place_id': placeId,
      'google_place_id': googlePlaceId,
    };
  }
}

class Place {
  final String id;
  final String name;
  final String? country;
  final String? city;
  final double? lat;
  final double? lng;
  final String? category;
  final String? externalUrl;

  const Place({
    required this.id,
    required this.name,
    this.country,
    this.city,
    this.lat,
    this.lng,
    this.category,
    this.externalUrl,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      id: json['id'] as String,
      name: json['name'] as String,
      country: json['country'] as String?,
      city: json['city'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      category: json['category'] as String?,
      externalUrl: json['external_url'] as String?,
    );
  }
}
