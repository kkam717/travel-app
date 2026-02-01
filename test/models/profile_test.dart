import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app/models/profile.dart';

void main() {
  group('Profile', () {
    test('fromJson parses full profile correctly', () {
      final json = {
        'id': 'user-1',
        'name': 'Alice',
        'photo_url': 'https://example.com/avatar.jpg',
        'current_city': 'Paris',
        'visited_countries': ['FR', 'IT', 'ES'],
        'travel_styles': ['foodie', 'adventure'],
        'travel_mode': 'solo',
        'favourite_trip_title': 'Best of Europe',
        'favourite_trip_description': 'Amazing trip',
        'favourite_trip_link': 'https://example.com/trip',
        'onboarding_complete': true,
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-15T12:00:00Z',
      };

      final profile = Profile.fromJson(json);

      expect(profile.id, 'user-1');
      expect(profile.name, 'Alice');
      expect(profile.photoUrl, 'https://example.com/avatar.jpg');
      expect(profile.currentCity, 'Paris');
      expect(profile.visitedCountries, ['FR', 'IT', 'ES']);
      expect(profile.travelStyles, ['foodie', 'adventure']);
      expect(profile.travelMode, 'solo');
      expect(profile.favouriteTripTitle, 'Best of Europe');
      expect(profile.favouriteTripDescription, 'Amazing trip');
      expect(profile.favouriteTripLink, 'https://example.com/trip');
      expect(profile.onboardingComplete, true);
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 'user-2',
      };

      final profile = Profile.fromJson(json);

      expect(profile.id, 'user-2');
      expect(profile.name, isNull);
      expect(profile.photoUrl, isNull);
      expect(profile.currentCity, isNull);
      expect(profile.visitedCountries, isEmpty);
      expect(profile.travelStyles, isEmpty);
      expect(profile.onboardingComplete, false);
    });

    test('toJson produces valid map', () {
      final profile = Profile(
        id: 'user-1',
        name: 'Alice',
        visitedCountries: ['FR'],
        travelStyles: ['foodie'],
        onboardingComplete: true,
      );
      final json = profile.toJson();

      expect(json['name'], 'Alice');
      expect(json['visited_countries'], ['FR']);
      expect(json['travel_styles'], ['foodie']);
      expect(json['onboarding_complete'], true);
      expect(json.containsKey('updated_at'), isTrue);
    });

    test('copyWith updates specified fields', () {
      final profile = Profile(
        id: 'user-1',
        name: 'Alice',
        currentCity: 'Paris',
      );
      final updated = profile.copyWith(
        name: 'Alice Smith',
        currentCity: 'London',
      );

      expect(updated.name, 'Alice Smith');
      expect(updated.currentCity, 'London');
      expect(updated.id, 'user-1');
    });
  });

  group('ProfileSearchResult', () {
    test('fromJson parses result correctly', () {
      final json = {
        'id': 'user-1',
        'name': 'Alice',
        'photo_url': 'https://example.com/photo.jpg',
        'trips_count': 5,
        'followers_count': 42,
      };

      final result = ProfileSearchResult.fromJson(json);

      expect(result.id, 'user-1');
      expect(result.name, 'Alice');
      expect(result.photoUrl, 'https://example.com/photo.jpg');
      expect(result.tripsCount, 5);
      expect(result.followersCount, 42);
    });

    test('fromJson defaults counts to 0 when missing', () {
      final json = {'id': 'user-1'};
      final result = ProfileSearchResult.fromJson(json);
      expect(result.tripsCount, 0);
      expect(result.followersCount, 0);
    });

    test('fromJson handles num types for counts', () {
      final json = {
        'id': 'user-1',
        'trips_count': 10.0,
        'followers_count': 100.0,
      };
      final result = ProfileSearchResult.fromJson(json);
      expect(result.tripsCount, 10);
      expect(result.followersCount, 100);
    });
  });
}
