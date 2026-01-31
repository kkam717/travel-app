/// Past city the user previously lived in.
class UserPastCity {
  final String id;
  final String userId;
  final String cityName;
  final int position;
  final DateTime? createdAt;

  const UserPastCity({
    required this.id,
    required this.userId,
    required this.cityName,
    this.position = 0,
    this.createdAt,
  });

  factory UserPastCity.fromJson(Map<String, dynamic> json) {
    return UserPastCity(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      cityName: json['city_name'] as String,
      position: (json['position'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'city_name': cityName,
        'position': position,
      };
}

/// Top spot in a city (Eat, Drink, Date, Chill).
class UserTopSpot {
  final String id;
  final String userId;
  final String cityName;
  final String category; // eat, drink, date, chill
  final String name;
  final String? description;
  final String? locationUrl;
  final int position;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserTopSpot({
    required this.id,
    required this.userId,
    required this.cityName,
    required this.category,
    required this.name,
    this.description,
    this.locationUrl,
    this.position = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory UserTopSpot.fromJson(Map<String, dynamic> json) {
    return UserTopSpot(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      cityName: json['city_name'] as String,
      category: json['category'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      locationUrl: json['location_url'] as String?,
      position: (json['position'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'city_name': cityName,
        'category': category,
        'name': name,
        'description': description,
        'location_url': locationUrl,
        'position': position,
        'updated_at': DateTime.now().toIso8601String(),
      };
}

/// Category labels for top spots.
const Map<String, String> topSpotCategoryLabels = {
  'eat': 'Eat',
  'drink': 'Drink',
  'date': 'Date',
  'chill': 'Chill',
};

