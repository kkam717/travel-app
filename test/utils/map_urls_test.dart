import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app/models/itinerary.dart';
import 'package:travel_app/models/user_city.dart';
import 'package:travel_app/utils/map_urls.dart';

void main() {
  group('MapUrls.buildItineraryStopMapUrl', () {
    test('Google Maps URL with coords when stop has lat/lng', () {
      final stop = ItineraryStop(
        id: 's1',
        itineraryId: 'it1',
        position: 0,
        name: 'Eiffel Tower',
        externalUrl: 'https://www.openstreetmap.org/node/123',
        lat: 48.8584,
        lng: 2.2945,
      );
      final uri = MapUrls.buildItineraryStopMapUrl(
        stop,
        platform: TargetPlatform.android,
        isWeb: false,
      );

      expect(uri.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.toString(), contains('48.8584'));
      expect(uri.toString(), contains('2.2945'));
    });

    test('Google Maps lat/lng URL when stop has coords', () {
      final stop = ItineraryStop(
        id: 's1',
        itineraryId: 'it1',
        position: 0,
        name: 'Paris, France',
        lat: 48.8566,
        lng: 2.3522,
      );
      final uri = MapUrls.buildItineraryStopMapUrl(
        stop,
        platform: TargetPlatform.android,
        isWeb: false,
      );

      expect(uri.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.toString(), contains('48.8566'));
      expect(uri.toString(), contains('2.3522'));
    });

    test('Google Maps search URL when no coords', () {
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
      expect(uri.path, startsWith('/maps/search/'));
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
      expect(uri.path, startsWith('/maps/search/'));
    });

    test('location stop with coords uses lat/lng URL', () {
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

      expect(uri.toString(), contains('35.6762'));
      expect(uri.toString(), contains('139.6503'));
    });
  });

  group('MapUrls.mapUrlFromPlace', () {
    test('builds Google Maps lat/lng URL when coords provided', () {
      final url = MapUrls.mapUrlFromPlace('Paris', 48.8566, 2.3522, null);

      expect(url, contains('google.com'));
      expect(url, contains('48.8566'));
      expect(url, contains('2.3522'));
    });

    test('builds Google Maps search URL when only name provided', () {
      final url = MapUrls.mapUrlFromPlace('Restaurant', null, null, null);

      expect(url, contains('google.com'));
      expect(url, contains('search'));
      expect(url, contains('Restaurant'));
    });
  });

  group('MapUrls.buildTopSpotMapUrl', () {
    test('returns Google Maps search URL from spot name', () {
      final spot = UserTopSpot(
        id: 's1',
        userId: 'u1',
        cityName: 'Paris',
        category: 'eat',
        name: 'Le Jules Verne',
        locationUrl: 'https://www.openstreetmap.org/node/789',
      );
      final uri = MapUrls.buildTopSpotMapUrl(spot, platform: TargetPlatform.android);

      expect(uri, isNotNull);
      expect(uri!.host, 'www.google.com');
      expect(uri.path, contains('Le'));
    });

    test('returns Google Maps search URL for spot name', () {
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
      expect(uri.path, contains('Eiffel'));
    });

    test('returns Google Maps search URL when no locationUrl', () {
      final spot = UserTopSpot(
        id: 's1',
        userId: 'u1',
        cityName: 'Paris',
        category: 'eat',
        name: 'Café de Flore',
      );
      final uri = MapUrls.buildTopSpotMapUrl(spot, platform: TargetPlatform.iOS);

      expect(uri, isNotNull);
      expect(uri!.host, 'www.google.com');
      expect(uri.path, startsWith('/maps/search/'));
    });
  });
}
