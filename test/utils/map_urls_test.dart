import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app/models/itinerary.dart';
import 'package:travel_app/models/user_city.dart';
import 'package:travel_app/utils/map_urls.dart';

void main() {
  group('MapUrls.buildItineraryStopMapUrl', () {
    test('Google Maps URL with Google Place ID on Android', () {
      final stop = ItineraryStop(
        id: 's1',
        itineraryId: 'it1',
        position: 0,
        name: 'Eiffel Tower',
        googlePlaceId: 'ChIJLU7jZClu5kcRYJSMaBEbL2s',
      );
      final uri = MapUrls.buildItineraryStopMapUrl(
        stop,
        platform: TargetPlatform.android,
        isWeb: false,
      );

      expect(uri.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/search/');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['query'], 'Eiffel Tower');
      expect(uri.queryParameters['query_place_id'], 'ChIJLU7jZClu5kcRYJSMaBEbL2s');
    });

    test('Google Maps URL without Place ID on Android', () {
      final stop = ItineraryStop(
        id: 's1',
        itineraryId: 'it1',
        position: 0,
        name: 'Paris, France',
      );
      final uri = MapUrls.buildItineraryStopMapUrl(
        stop,
        platform: TargetPlatform.android,
        isWeb: false,
      );

      expect(uri.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.queryParameters['query'], 'Paris, France');
      expect(uri.queryParameters.containsKey('query_place_id'), isFalse);
    });

    test('Google Maps URL on iOS for place_id accuracy (Apple Maps lacks place_id)', () {
      final stop = ItineraryStop(
        id: 's1',
        itineraryId: 'it1',
        position: 0,
        name: 'Eiffel Tower',
        googlePlaceId: 'ChIJLU7jZClu5kcRYJSMaBEbL2s',
      );
      final uri = MapUrls.buildItineraryStopMapUrl(
        stop,
        platform: TargetPlatform.iOS,
        isWeb: false,
      );

      expect(uri.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/search/');
      expect(uri.queryParameters['query'], 'Eiffel Tower');
      expect(uri.queryParameters['query_place_id'], 'ChIJLU7jZClu5kcRYJSMaBEbL2s');
    });

    test('encodes special characters in place name', () {
      final stop = ItineraryStop(
        id: 's1',
        itineraryId: 'it1',
        position: 0,
        name: 'Café de Flore, Paris',
      );
      final uri = MapUrls.buildItineraryStopMapUrl(
        stop,
        platform: TargetPlatform.iOS,
        isWeb: false,
      );

      expect(uri.host, 'www.google.com');
      expect(uri.queryParameters['query'], isNotNull);
      expect(uri.queryParameters['query']!.length, greaterThan(5));
    });

    test('Google Maps URL on Web', () {
      final stop = ItineraryStop(
        id: 's1',
        itineraryId: 'it1',
        position: 0,
        name: 'Le Jules Verne',
        googlePlaceId: 'ChIJ123',
      );
      final uri = MapUrls.buildItineraryStopMapUrl(
        stop,
        platform: TargetPlatform.android,
        isWeb: true,
      );

      expect(uri.host, 'www.google.com');
      expect(uri.queryParameters['query_place_id'], 'ChIJ123');
    });

    test('placeId starting with ChIJ used as Google Place ID', () {
      final stop = ItineraryStop(
        id: 's1',
        itineraryId: 'it1',
        position: 0,
        name: 'Restaurant',
        placeId: 'ChIJabc123',
      );
      final uri = MapUrls.buildItineraryStopMapUrl(
        stop,
        platform: TargetPlatform.android,
        isWeb: false,
      );

      expect(uri.queryParameters['query_place_id'], 'ChIJabc123');
    });

    test('placeId that is UUID not used as Google Place ID', () {
      final stop = ItineraryStop(
        id: 's1',
        itineraryId: 'it1',
        position: 0,
        name: 'Place',
        placeId: '550e8400-e29b-41d4-a716-446655440000',
      );
      final uri = MapUrls.buildItineraryStopMapUrl(
        stop,
        platform: TargetPlatform.android,
        isWeb: false,
      );

      expect(uri.queryParameters.containsKey('query_place_id'), isFalse);
      expect(uri.queryParameters['query'], 'Place');
    });

    test('location stop with coords still uses name for URL', () {
      final stop = ItineraryStop(
        id: 's1',
        itineraryId: 'it1',
        position: 0,
        name: 'Tokyo',
        lat: 35.6762,
        lng: 139.6503,
      );
      final uri = MapUrls.buildItineraryStopMapUrl(
        stop,
        platform: TargetPlatform.android,
        isWeb: false,
      );

      expect(uri.queryParameters['query'], 'Tokyo');
    });
  });

  group('MapUrls.mapUrlFromPlaceId', () {
    test('builds correct Google Maps search URL with api=1', () {
      const placeId = 'ChIJLU7jZClu5kcRYJSMaBEbL2s';
      const placeName = 'Eiffel Tower';
      final url = MapUrls.mapUrlFromPlaceId(placeId, placeName);

      expect(url, contains('api=1'));
      expect(url, contains('query_place_id=$placeId'));
      expect(url, contains('query='));
    });

    test('handles different place IDs', () {
      final url = MapUrls.mapUrlFromPlaceId('ChIJabc', 'Restaurant');
      expect(url, contains('ChIJabc'));
      expect(url, contains('Restaurant'));
    });
  });

  group('MapUrls.buildTopSpotMapUrl', () {
    test('uses Google Maps search URL with place_id from locationUrl', () {
      final spot = UserTopSpot(
        id: 's1',
        userId: 'u1',
        cityName: 'Paris',
        category: 'eat',
        name: 'Le Jules Verne',
        locationUrl: 'https://www.google.com/maps/place/?q=place_id:ChIJ123',
      );
      final uri = MapUrls.buildTopSpotMapUrl(spot, platform: TargetPlatform.android);

      expect(uri, isNotNull);
      expect(uri!.host, 'www.google.com');
      expect(uri.path, '/maps/search/');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['query_place_id'], 'ChIJ123');
    });

    test('uses Google Maps on iOS for place_id accuracy (Apple Maps lacks place_id)', () {
      final spot = UserTopSpot(
        id: 's1',
        userId: 'u1',
        cityName: 'Paris',
        category: 'eat',
        name: 'Eiffel Tower',
        locationUrl: 'https://www.google.com/maps/place/?q=place_id:ChIJ123',
      );
      final uri = MapUrls.buildTopSpotMapUrl(spot, platform: TargetPlatform.iOS);

      expect(uri, isNotNull);
      expect(uri!.host, 'www.google.com');
      expect(uri.path, '/maps/search/');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['query_place_id'], 'ChIJ123');
    });

    test('parses query_place_id from new URL format', () {
      final spot = UserTopSpot(
        id: 's1',
        userId: 'u1',
        cityName: 'London',
        category: 'eat',
        name: 'Dishoom',
        locationUrl: 'https://www.google.com/maps/search/?api=1&query=Dishoom&query_place_id=ChIJabc123xyz',
      );
      final uri = MapUrls.buildTopSpotMapUrl(spot, platform: TargetPlatform.android);

      expect(uri, isNotNull);
      expect(uri!.host, 'www.google.com');
      expect(uri.path, '/maps/search/');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['query_place_id'], 'ChIJabc123xyz');
    });

    test('falls back to search by name when no locationUrl', () {
      final spot = UserTopSpot(
        id: 's1',
        userId: 'u1',
        cityName: 'Paris',
        category: 'eat',
        name: 'Café de Flore',
      );
      final uri = MapUrls.buildTopSpotMapUrl(spot, platform: TargetPlatform.android);

      expect(uri, isNotNull);
      expect(uri!.queryParameters['query'], 'Café de Flore');
    });
  });
}
