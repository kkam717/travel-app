import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app/core/theme.dart';
import 'package:travel_app/models/itinerary.dart';
import 'package:travel_app/widgets/static_map_image.dart';

void main() {
  setUpAll(() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // Ensure dotenv is initialized even if .env missing (avoids NotInitializedError)
      await dotenv.load(fileName: '.env.example');
    }
  });
  group('StaticMapImage', () {
    Itinerary itineraryWithCoords() => Itinerary(
          id: 'it1',
          authorId: 'u1',
          title: 'Test Trip',
          destination: 'Paris, France',
          daysCount: 3,
          styleTags: [],
          visibility: 'public',
          stops: [
            ItineraryStop(
              id: 's1',
              itineraryId: 'it1',
              position: 0,
              name: 'Eiffel Tower',
              lat: 48.8584,
              lng: 2.2945,
            ),
            ItineraryStop(
              id: 's2',
              itineraryId: 'it1',
              position: 1,
              name: 'Louvre',
              lat: 48.8606,
              lng: 2.3376,
            ),
          ],
        );

    Itinerary itineraryEmpty() => Itinerary(
          id: 'it2',
          authorId: 'u1',
          title: 'Empty Trip',
          destination: '',
          daysCount: 1,
          styleTags: [],
          visibility: 'public',
          stops: [],
        );

    testWidgets('renders without crashing with stops that have coords', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: StaticMapImage(
              itinerary: itineraryWithCoords(),
              width: 400,
              height: 200,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Without GEOAPIFY_API_KEY, shows "No map data" or loading/placeholder
      // With key, would show Image.network. Either way, no crash.
      expect(find.byType(StaticMapImage), findsOneWidget);
    });

    testWidgets('renders without crashing with empty itinerary', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: StaticMapImage(
              itinerary: itineraryEmpty(),
              width: 400,
              height: 200,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(StaticMapImage), findsOneWidget);
    });
  });
}
