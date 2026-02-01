import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app/core/theme.dart';
import 'package:travel_app/models/itinerary.dart';
import 'package:travel_app/widgets/itinerary_map.dart';

void main() {
  setUpAll(() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      await dotenv.load(fileName: '.env.example');
    }
  });

  group('ItineraryMap', () {
    testWidgets('renders without crashing with stops that have coords', (WidgetTester tester) async {
      final stops = [
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
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ItineraryMap(
              stops: stops,
              destination: 'Paris, France',
              height: 280,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.byType(ItineraryMap), findsOneWidget);
      expect(find.text('Route'), findsOneWidget);
    });

    testWidgets('renders empty state when no map data', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ItineraryMap(
              stops: [],
              destination: null,
              height: 280,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ItineraryMap), findsOneWidget);
      expect(find.text('No map data yet'), findsOneWidget);
    });

    testWidgets('renders with stops that have coords', (WidgetTester tester) async {
      final stops = [
        ItineraryStop(
          id: 's1',
          itineraryId: 'it1',
          position: 0,
          name: 'Berlin',
          lat: 52.52,
          lng: 13.405,
        ),
        ItineraryStop(
          id: 's2',
          itineraryId: 'it1',
          position: 1,
          name: 'Munich',
          lat: 48.1351,
          lng: 11.5820,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ItineraryMap(
              stops: stops,
              destination: 'Germany',
              height: 200,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.byType(ItineraryMap), findsOneWidget);
    });
  });
}
