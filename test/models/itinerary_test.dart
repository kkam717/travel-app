import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app/models/itinerary.dart';

void main() {
  group('Itinerary', () {
    test('fromJson parses full itinerary correctly', () {
      final json = {
        'id': 'it-1',
        'author_id': 'user-1',
        'profiles': {'name': 'Alice', 'photo_url': 'https://example.com/photo.jpg'},
        'title': 'Paris Adventure',
        'destination': 'Paris, France',
        'days_count': 5,
        'style_tags': ['foodie', 'adventure'],
        'mode': 'couple',
        'visibility': 'public',
        'forked_from_itinerary_id': null,
        'created_at': '2024-01-15T10:00:00Z',
        'updated_at': '2024-01-16T12:00:00Z',
        'stops_count': 12,
        'bookmark_count': 5,
      };

      final it = Itinerary.fromJson(json);

      expect(it.id, 'it-1');
      expect(it.authorId, 'user-1');
      expect(it.authorName, 'Alice');
      expect(it.authorPhotoUrl, 'https://example.com/photo.jpg');
      expect(it.title, 'Paris Adventure');
      expect(it.destination, 'Paris, France');
      expect(it.daysCount, 5);
      expect(it.styleTags, ['foodie', 'adventure']);
      expect(it.mode, 'couple');
      expect(it.visibility, 'public');
      expect(it.forkedFromItineraryId, isNull);
      expect(it.stopsCount, 12);
      expect(it.bookmarkCount, 5);
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 'it-2',
        'author_id': 'user-2',
        'title': 'Quick Trip',
        'destination': 'London',
        'days_count': 2,
      };

      final it = Itinerary.fromJson(json);

      expect(it.id, 'it-2');
      expect(it.authorName, isNull);
      expect(it.authorPhotoUrl, isNull);
      expect(it.styleTags, isEmpty);
      expect(it.mode, isNull);
      expect(it.visibility, 'private');
      expect(it.stops, isEmpty);
      expect(it.stopsCount, isNull);
      expect(it.bookmarkCount, isNull);
    });

    test('hasMapStops returns true when stops have lat/lng', () {
      final it = Itinerary(
        id: 'it-1',
        authorId: 'u1',
        title: 'Trip',
        destination: 'Paris',
        daysCount: 3,
        stops: [
          ItineraryStop(
            id: 's1',
            itineraryId: 'it-1',
            position: 0,
            name: 'Eiffel Tower',
            lat: 48.8584,
            lng: 2.2945,
          ),
        ],
      );
      expect(it.hasMapStops, isTrue);
    });

    test('hasMapStops returns false when stops have no coordinates', () {
      final it = Itinerary(
        id: 'it-1',
        authorId: 'u1',
        title: 'Trip',
        destination: 'Paris',
        daysCount: 3,
        stops: [
          ItineraryStop(
            id: 's1',
            itineraryId: 'it-1',
            position: 0,
            name: 'Eiffel Tower',
          ),
        ],
      );
      expect(it.hasMapStops, isFalse);
    });

    test('copyWith updates specified fields', () {
      final it = Itinerary(
        id: 'it-1',
        authorId: 'u1',
        title: 'Trip',
        destination: 'Paris',
        daysCount: 3,
        stopsCount: 5,
      );
      final updated = it.copyWith(stopsCount: 10, bookmarkCount: 2);

      expect(updated.stopsCount, 10);
      expect(updated.bookmarkCount, 2);
      expect(updated.title, 'Trip');
    });

    test('toJson produces valid map', () {
      final it = Itinerary(
        id: 'it-1',
        authorId: 'u1',
        title: 'Trip',
        destination: 'Paris',
        daysCount: 3,
        styleTags: ['foodie'],
        mode: 'solo',
        visibility: 'public',
      );
      final json = it.toJson();

      expect(json['author_id'], 'u1');
      expect(json['title'], 'Trip');
      expect(json['destination'], 'Paris');
      expect(json['days_count'], 3);
      expect(json['style_tags'], ['foodie']);
      expect(json['mode'], 'solo');
      expect(json['visibility'], 'public');
      expect(json.containsKey('updated_at'), isTrue);
    });
  });

  group('ItineraryStop', () {
    test('fromJson parses stop correctly', () {
      final json = {
        'id': 'stop-1',
        'itinerary_id': 'it-1',
        'position': 0,
        'day': 1,
        'name': 'Eiffel Tower',
        'category': 'sightseeing',
        'stop_type': 'location',
        'lat': 48.8584,
        'lng': 2.2945,
        'google_place_id': 'ChIJLU7jZClu5kcRYJSMaBEbL2s',
      };

      final stop = ItineraryStop.fromJson(json);

      expect(stop.id, 'stop-1');
      expect(stop.itineraryId, 'it-1');
      expect(stop.position, 0);
      expect(stop.day, 1);
      expect(stop.name, 'Eiffel Tower');
      expect(stop.category, 'sightseeing');
      expect(stop.stopType, 'location');
      expect(stop.lat, 48.8584);
      expect(stop.lng, 2.2945);
      expect(stop.googlePlaceId, 'ChIJLU7jZClu5kcRYJSMaBEbL2s');
      expect(stop.isLocation, isTrue);
      expect(stop.isVenue, isFalse);
    });

    test('fromJson defaults day to 1 when missing', () {
      final json = {
        'id': 'stop-1',
        'itinerary_id': 'it-1',
        'position': 0,
        'name': 'Place',
      };
      final stop = ItineraryStop.fromJson(json);
      expect(stop.day, 1);
    });

    test('isVenue returns true for venue stop_type', () {
      final stop = ItineraryStop(
        id: 's1',
        itineraryId: 'it-1',
        position: 0,
        name: 'Restaurant',
        stopType: 'venue',
      );
      expect(stop.isLocation, isFalse);
      expect(stop.isVenue, isTrue);
    });

    test('toJson produces valid map', () {
      final stop = ItineraryStop(
        id: 's1',
        itineraryId: 'it-1',
        position: 0,
        day: 2,
        name: 'Spot',
        category: 'eat',
        stopType: 'venue',
        lat: 48.0,
        lng: 2.0,
      );
      final json = stop.toJson();

      expect(json['itinerary_id'], 'it-1');
      expect(json['position'], 0);
      expect(json['day'], 2);
      expect(json['name'], 'Spot');
      expect(json['category'], 'eat');
      expect(json['stop_type'], 'venue');
      expect(json['lat'], 48.0);
      expect(json['lng'], 2.0);
    });
  });

  group('Place', () {
    test('fromJson parses place correctly', () {
      final json = {
        'id': 'place-1',
        'name': 'Eiffel Tower',
        'country': 'France',
        'city': 'Paris',
        'lat': 48.8584,
        'lng': 2.2945,
        'category': 'sightseeing',
        'external_url': 'https://maps.google.com/...',
      };

      final place = Place.fromJson(json);

      expect(place.id, 'place-1');
      expect(place.name, 'Eiffel Tower');
      expect(place.country, 'France');
      expect(place.city, 'Paris');
      expect(place.lat, 48.8584);
      expect(place.lng, 2.2945);
      expect(place.category, 'sightseeing');
      expect(place.externalUrl, 'https://maps.google.com/...');
    });

    test('fromJson handles minimal fields', () {
      final json = {'id': 'p1', 'name': 'Place'};
      final place = Place.fromJson(json);
      expect(place.id, 'p1');
      expect(place.name, 'Place');
      expect(place.country, isNull);
      expect(place.lat, isNull);
    });
  });
}
