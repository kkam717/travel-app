import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app/services/places_service.dart';

void main() {
  group('PlacePrediction.fromPhoton', () {
    test('parses city feature from Photon GeoJSON', () {
      final feature = {
        'type': 'Feature',
        'properties': {
          'osm_type': 'R',
          'osm_id': 62422,
          'name': 'Berlin',
          'country': 'Germany',
          'countrycode': 'DE',
        },
        'geometry': {
          'type': 'Point',
          'coordinates': [13.3951309, 52.5173885],
        },
      };

      final p = PlacePrediction.fromPhoton(feature);

      expect(p.mainText, 'Berlin');
      expect(p.placeId, 'osm:R:62422');
      expect(p.lat, closeTo(52.5173885, 0.0001));
      expect(p.lng, closeTo(13.3951309, 0.0001));
      expect(p.osmUrl, 'https://www.openstreetmap.org/relation/62422');
    });

    test('parses venue feature with street and city', () {
      final feature = {
        'type': 'Feature',
        'properties': {
          'osm_type': 'W',
          'osm_id': 9393789,
          'name': 'Berlin Zoo',
          'street': 'Hardenbergplatz',
          'housenumber': '8',
          'city': 'Berlin',
          'country': 'Germany',
          'countrycode': 'DE',
        },
        'geometry': {
          'type': 'Point',
          'coordinates': [13.33923057, 52.50844935],
        },
      };

      final p = PlacePrediction.fromPhoton(feature);

      expect(p.mainText, 'Berlin Zoo');
      expect(p.secondaryText, contains('Hardenbergplatz'));
      expect(p.secondaryText, contains('Berlin'));
      expect(p.secondaryText, contains('Germany'));
      expect(p.lat, closeTo(52.50844935, 0.0001));
      expect(p.lng, closeTo(13.33923057, 0.0001));
      expect(p.osmUrl, 'https://www.openstreetmap.org/way/9393789');
    });

    test('handles node type', () {
      final feature = {
        'type': 'Feature',
        'properties': {'osm_type': 'N', 'osm_id': 12345, 'name': 'Test Node'},
        'geometry': {'type': 'Point', 'coordinates': [0.0, 0.0]},
      };

      final p = PlacePrediction.fromPhoton(feature);

      expect(p.mainText, 'Test Node');
      expect(p.osmUrl, 'https://www.openstreetmap.org/node/12345');
      expect(p.placeId, 'osm:N:12345');
    });

    test('handles missing geometry', () {
      final feature = {
        'type': 'Feature',
        'properties': {'name': 'Unknown'},
        'geometry': null,
      };

      final p = PlacePrediction.fromPhoton(feature);

      expect(p.mainText, 'Unknown');
      expect(p.lat, isNull);
      expect(p.lng, isNull);
      expect(p.osmUrl, isNull);
    });

    test('handles empty properties', () {
      final feature = <String, dynamic>{
        'type': 'Feature',
        'properties': <String, dynamic>{},
        'geometry': <String, dynamic>{'type': 'Point', 'coordinates': [1.0, 2.0]},
      };

      final p = PlacePrediction.fromPhoton(feature);

      expect(p.mainText, '');
      expect(p.lat, 2.0);
      expect(p.lng, 1.0);
      expect(p.placeId, startsWith('osm:'));
    });
  });
}
