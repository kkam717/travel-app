import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app/models/user_city.dart';

void main() {
  group('UserPastCity', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': 'city-1',
        'user_id': 'user-1',
        'city_name': 'Paris',
        'position': 0,
      };

      final city = UserPastCity.fromJson(json);

      expect(city.id, 'city-1');
      expect(city.userId, 'user-1');
      expect(city.cityName, 'Paris');
      expect(city.position, 0);
    });
  });

  group('UserTopSpot', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': 'spot-1',
        'user_id': 'user-1',
        'city_name': 'Paris',
        'category': 'eat',
        'name': 'Le Jules Verne',
        'description': 'Fine dining',
        'location_url': 'https://maps.google.com/...',
        'position': 0,
      };

      final spot = UserTopSpot.fromJson(json);

      expect(spot.id, 'spot-1');
      expect(spot.userId, 'user-1');
      expect(spot.cityName, 'Paris');
      expect(spot.category, 'eat');
      expect(spot.name, 'Le Jules Verne');
      expect(spot.description, 'Fine dining');
      expect(spot.locationUrl, 'https://maps.google.com/...');
      expect(spot.position, 0);
    });
  });
}
