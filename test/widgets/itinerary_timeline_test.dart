import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app/core/theme.dart';
import 'package:travel_app/models/itinerary.dart';
import 'package:travel_app/widgets/itinerary_timeline.dart';

/// Demo dataset: Milano (Day 1) -> Roma (Day 2) -> Napoli (Day 3)
/// Transport overrides: 0=plane (Milano→Roma), 1=train (Roma→Napoli)
Itinerary _demoItinerary() {
  return Itinerary(
    id: 'demo-1',
    authorId: 'u1',
    title: 'Italy Trip',
    destination: 'Italy',
    daysCount: 3,
    stops: [
      ItineraryStop(id: 'l1', itineraryId: 'demo-1', position: 0, day: 1, name: 'Milano', stopType: 'location'),
      ItineraryStop(id: 'v1', itineraryId: 'demo-1', position: 1, day: 1, name: 'Restaurant A', category: 'restaurant', stopType: 'venue'),
      ItineraryStop(id: 'l2', itineraryId: 'demo-1', position: 0, day: 2, name: 'Roma', stopType: 'location'),
      ItineraryStop(id: 'v2', itineraryId: 'demo-1', position: 1, day: 2, name: 'Hotel B', category: 'hotel', stopType: 'venue'),
      ItineraryStop(id: 'l3', itineraryId: 'demo-1', position: 0, day: 3, name: 'Napoli', stopType: 'location'),
    ],
  );
}

/// Demo dataset: Milano → Roma → Napoli → Firenze (4 locations)
/// Transport: 0=plane (Milano→Roma), 1=train (Roma→Napoli), 2=missing (Napoli→Firenze fallback)
Itinerary _demoItineraryMixedTransport() {
  return Itinerary(
    id: 'demo-2',
    authorId: 'u1',
    title: 'Italy Grand Tour',
    destination: 'Italy',
    daysCount: 4,
    stops: [
      ItineraryStop(id: 'l1', itineraryId: 'demo-2', position: 0, day: 1, name: 'Milano', stopType: 'location'),
      ItineraryStop(id: 'l2', itineraryId: 'demo-2', position: 0, day: 2, name: 'Roma', stopType: 'location'),
      ItineraryStop(id: 'l3', itineraryId: 'demo-2', position: 0, day: 3, name: 'Napoli', stopType: 'location'),
      ItineraryStop(id: 'l4', itineraryId: 'demo-2', position: 0, day: 4, name: 'Firenze', stopType: 'location'),
    ],
  );
}

void main() {
  group('ItineraryTimeline', () {
    testWidgets('renders empty state when no stops', (WidgetTester tester) async {
      final it = Itinerary(
        id: 'e1',
        authorId: 'u1',
        title: 'Empty',
        destination: 'Nowhere',
        daysCount: 0,
        stops: [],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ItineraryTimeline(
              itinerary: it,
              onOpenInMaps: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No places yet'), findsOneWidget);
    });

    testWidgets('renders location cards with day labels', (WidgetTester tester) async {
      final it = _demoItinerary();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ItineraryTimeline(
                itinerary: it,
                onOpenInMaps: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Day 1'), findsWidgets);
      expect(find.text('Day 2'), findsWidgets);
      expect(find.text('Day 3'), findsWidgets);
      expect(find.text('Milano'), findsOneWidget);
      expect(find.text('Roma'), findsOneWidget);
      expect(find.text('Napoli'), findsOneWidget);
    });

    testWidgets('renders TimelineConnector with plane when transport override', (WidgetTester tester) async {
      final it = _demoItinerary();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ItineraryTimeline(
                itinerary: it,
                transportOverrides: {0: TransportType.plane},
                onOpenInMaps: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.flight_rounded), findsOneWidget);
    });

    testWidgets('renders TimelineConnector with train when transport override', (WidgetTester tester) async {
      final it = _demoItinerary();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ItineraryTimeline(
                itinerary: it,
                transportOverrides: {1: TransportType.train},
                onOpenInMaps: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.train_rounded), findsOneWidget);
    });

    testWidgets('renders dotted line only when no transport override', (WidgetTester tester) async {
      final it = _demoItinerary();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ItineraryTimeline(
                itinerary: it,
                onOpenInMaps: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TimelineConnector), findsNWidgets(2));
      expect(find.byIcon(Icons.swap_horiz_rounded), findsNothing);
    });

    testWidgets('renders plane, train, and dotted line only in one timeline (mixed transport demo)', (WidgetTester tester) async {
      final it = _demoItineraryMixedTransport();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ItineraryTimeline(
                itinerary: it,
                transportOverrides: {0: TransportType.plane, 1: TransportType.train},
                onOpenInMaps: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.flight_rounded), findsOneWidget);
      expect(find.byIcon(Icons.train_rounded), findsOneWidget);
      expect(find.byType(TimelineConnector), findsNWidgets(3));
      expect(find.byIcon(Icons.swap_horiz_rounded), findsNothing);
    });
  });

  group('TimelineConnector', () {
    testWidgets('renders with plane icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: TimelineConnector(transport: TransportType.plane),
          ),
        ),
      );
      expect(find.byIcon(Icons.flight_rounded), findsOneWidget);
    });

    testWidgets('renders dotted line only when unknown (no icon)', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: TimelineConnector(),
          ),
        ),
      );
      expect(find.byType(TimelineConnector), findsOneWidget);
      expect(find.byIcon(Icons.swap_horiz_rounded), findsNothing);
    });

    testWidgets('renders car icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: TimelineConnector(transport: TransportType.car),
          ),
        ),
      );
      expect(find.byIcon(Icons.directions_car_rounded), findsOneWidget);
    });

    testWidgets('renders boat icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: TimelineConnector(transport: TransportType.boat),
          ),
        ),
      );
      expect(find.byIcon(Icons.directions_boat_rounded), findsOneWidget);
    });

    testWidgets('renders walk icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: TimelineConnector(transport: TransportType.walk),
          ),
        ),
      );
      expect(find.byIcon(Icons.directions_walk_rounded), findsOneWidget);
    });

    testWidgets('renders other icon (question mark)', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: TimelineConnector(transport: TransportType.other),
          ),
        ),
      );
      expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);
    });
  });

  group('TransportConfig', () {
    test('buildOverridesFromStops returns overrides for configured transitions', () {
      final config = TransportConfig();
      config.set('l1', 'l2', TransportType.plane);
      config.set('l2', 'l3', TransportType.train);
      final stops = [
        ItineraryStop(id: 'l1', itineraryId: 'x', position: 0, day: 1, name: 'A', stopType: 'location'),
        ItineraryStop(id: 'l2', itineraryId: 'x', position: 0, day: 2, name: 'B', stopType: 'location'),
        ItineraryStop(id: 'l3', itineraryId: 'x', position: 0, day: 3, name: 'C', stopType: 'location'),
      ];
      final overrides = config.buildOverridesFromStops(stops);
      expect(overrides, isNotNull);
      expect(overrides![0], TransportType.plane);
      expect(overrides[1], TransportType.train);
    });

    test('buildOverridesFromStops returns null when no matches', () {
      final config = TransportConfig();
      config.set('l99', 'l98', TransportType.plane);
      final stops = [
        ItineraryStop(id: 'l1', itineraryId: 'x', position: 0, day: 1, name: 'A', stopType: 'location'),
        ItineraryStop(id: 'l2', itineraryId: 'x', position: 0, day: 2, name: 'B', stopType: 'location'),
      ];
      expect(config.buildOverridesFromStops(stops), isNull);
    });
  });
}
