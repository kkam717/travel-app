class ProfileSearchResult {
  final String id;
  final String? name;
  final String? photoUrl;
  final int tripsCount;
  final int followersCount;
  /// When from location search: "Country - City1 • City2 • City3" for that place.
  final String? placesSummary;

  const ProfileSearchResult({
    required this.id,
    this.name,
    this.photoUrl,
    this.tripsCount = 0,
    this.followersCount = 0,
    this.placesSummary,
  });

  factory ProfileSearchResult.fromJson(Map<String, dynamic> json) {
    return ProfileSearchResult(
      id: json['id'] as String,
      name: json['name'] as String?,
      photoUrl: json['photo_url'] as String?,
      tripsCount: (json['trips_count'] as num?)?.toInt() ?? 0,
      followersCount: (json['followers_count'] as num?)?.toInt() ?? 0,
      placesSummary: json['places_summary'] as String?,
    );
  }
}

class Profile {
  final String id;
  final String? name;
  final String? photoUrl;
  final String? currentCity;
  final List<String> visitedCountries;
  final List<String> travelStyles;
  final String? travelMode;
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
    this.currentCity,
    this.visitedCountries = const [],
    this.travelStyles = const [],
    this.travelMode,
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
      currentCity: json['current_city'] as String?,
      visitedCountries: List<String>.from(json['visited_countries'] ?? []),
      travelStyles: List<String>.from(json['travel_styles'] ?? []),
      travelMode: json['travel_mode'] as String?,
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
      'current_city': currentCity,
      'visited_countries': visitedCountries,
      'travel_styles': travelStyles,
      'travel_mode': travelMode,
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
    String? currentCity,
    List<String>? visitedCountries,
    List<String>? travelStyles,
    String? travelMode,
    String? favouriteTripTitle,
    String? favouriteTripDescription,
    String? favouriteTripLink,
    bool? onboardingComplete,
  }) {
    return Profile(
      id: id,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      currentCity: currentCity ?? this.currentCity,
      visitedCountries: visitedCountries ?? this.visitedCountries,
      travelStyles: travelStyles ?? this.travelStyles,
      travelMode: travelMode ?? this.travelMode,
      favouriteTripTitle: favouriteTripTitle ?? this.favouriteTripTitle,
      favouriteTripDescription: favouriteTripDescription ?? this.favouriteTripDescription,
      favouriteTripLink: favouriteTripLink ?? this.favouriteTripLink,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
