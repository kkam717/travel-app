class Itinerary {
  final String id;
  final String authorId;
  final String? authorName;
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

  const Itinerary({
    required this.id,
    required this.authorId,
    this.authorName,
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
  });

  factory Itinerary.fromJson(Map<String, dynamic> json, {List<ItineraryStop>? stops}) {
    return Itinerary(
      id: json['id'] as String,
      authorId: json['author_id'] as String,
      authorName: json['profiles']?['name'] as String?,
      title: json['title'] as String,
      destination: json['destination'] as String,
      daysCount: json['days_count'] as int,
      styleTags: List<String>.from(json['style_tags'] ?? []),
      mode: json['mode'] as String?,
      visibility: json['visibility'] as String? ?? 'private',
      forkedFromItineraryId: json['forked_from_itinerary_id'] as String?,
      stops: stops ?? [],
      stopsCount: json['stops_count'] as int?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
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
    };
  }

  bool get hasMapStops => stops.any((s) => s.lat != null && s.lng != null);

  Itinerary copyWith({List<ItineraryStop>? stops, int? stopsCount}) => Itinerary(
        id: id,
        authorId: authorId,
        authorName: authorName,
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
