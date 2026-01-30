class Profile {
  final String id;
  final String? name;
  final String? photoUrl;
  final List<String> visitedCountries;
  final List<String> travelStyles;
  final String? travelMode;
  final List<String> favouriteCountries;
  final List<CityLived> citiesLived;
  final List<IdeaTrip> ideasFutureTrips;
  final String? favouriteTripTitle;
  final String? favouriteTripDescription;
  final String? favouriteTripLink;
  final bool onboardingComplete;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Profile({
    required this.id,
    this.name,
    this.photoUrl,
    this.visitedCountries = const [],
    this.travelStyles = const [],
    this.travelMode,
    this.favouriteCountries = const [],
    this.citiesLived = const [],
    this.ideasFutureTrips = const [],
    this.favouriteTripTitle,
    this.favouriteTripDescription,
    this.favouriteTripLink,
    this.onboardingComplete = false,
    this.createdAt,
    this.updatedAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      name: json['name'] as String?,
      photoUrl: json['photo_url'] as String?,
      visitedCountries: List<String>.from(json['visited_countries'] ?? []),
      travelStyles: List<String>.from(json['travel_styles'] ?? []),
      travelMode: json['travel_mode'] as String?,
      favouriteCountries: List<String>.from(json['favourite_countries'] ?? []),
      citiesLived: (json['cities_lived'] as List<dynamic>?)
              ?.map((e) => CityLived.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      ideasFutureTrips: (json['ideas_future_trips'] as List<dynamic>?)
              ?.map((e) => IdeaTrip.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      favouriteTripTitle: json['favourite_trip_title'] as String?,
      favouriteTripDescription: json['favourite_trip_description'] as String?,
      favouriteTripLink: json['favourite_trip_link'] as String?,
      onboardingComplete: json['onboarding_complete'] as bool? ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'photo_url': photoUrl,
      'visited_countries': visitedCountries,
      'travel_styles': travelStyles,
      'travel_mode': travelMode,
      'favourite_countries': favouriteCountries,
      'cities_lived': citiesLived.map((e) => e.toJson()).toList(),
      'ideas_future_trips': ideasFutureTrips.map((e) => e.toJson()).toList(),
      'favourite_trip_title': favouriteTripTitle,
      'favourite_trip_description': favouriteTripDescription,
      'favourite_trip_link': favouriteTripLink,
      'onboarding_complete': onboardingComplete,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Profile copyWith({
    String? name,
    String? photoUrl,
    List<String>? visitedCountries,
    List<String>? travelStyles,
    String? travelMode,
    List<String>? favouriteCountries,
    List<CityLived>? citiesLived,
    List<IdeaTrip>? ideasFutureTrips,
    String? favouriteTripTitle,
    String? favouriteTripDescription,
    String? favouriteTripLink,
    bool? onboardingComplete,
  }) {
    return Profile(
      id: id,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      visitedCountries: visitedCountries ?? this.visitedCountries,
      travelStyles: travelStyles ?? this.travelStyles,
      travelMode: travelMode ?? this.travelMode,
      favouriteCountries: favouriteCountries ?? this.favouriteCountries,
      citiesLived: citiesLived ?? this.citiesLived,
      ideasFutureTrips: ideasFutureTrips ?? this.ideasFutureTrips,
      favouriteTripTitle: favouriteTripTitle ?? this.favouriteTripTitle,
      favouriteTripDescription: favouriteTripDescription ?? this.favouriteTripDescription,
      favouriteTripLink: favouriteTripLink ?? this.favouriteTripLink,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class CityLived {
  final String city;
  final String country;

  const CityLived({required this.city, required this.country});

  factory CityLived.fromJson(Map<String, dynamic> json) {
    return CityLived(
      city: json['city'] as String? ?? '',
      country: json['country'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'city': city, 'country': country};
}

class IdeaTrip {
  final String title;
  final String notes;

  const IdeaTrip({required this.title, required this.notes});

  factory IdeaTrip.fromJson(Map<String, dynamic> json) {
    return IdeaTrip(
      title: json['title'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'title': title, 'notes': notes};
}
