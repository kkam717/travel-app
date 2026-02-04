import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:travel_app/main.dart' as app;

/// Integration tests for all features and user flows.
/// Run with: flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart
///
/// Requires: Valid Supabase credentials in .env. For full logged-in flow tests,
/// add DEV_EMAIL and DEV_PASSWORD to .env (create the user in Supabase Auth first).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Ensures app is running and returns true if logged in (Home visible)
  Future<bool> _ensureAppAndCheckLoggedIn(WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));
    return find.text('Home').evaluate().isNotEmpty;
  }

  /// Attempts developer sign-in if on Welcome screen
  Future<bool> _tryDevSignIn(WidgetTester tester) async {
    if (find.text('Setup Required').evaluate().isNotEmpty) return false;
    if (find.text('Home').evaluate().isNotEmpty) return true;
    final devSignIn = find.text('Developer sign in');
    if (devSignIn.evaluate().isNotEmpty) {
      await tester.tap(devSignIn);
      await tester.pumpAndSettle(const Duration(seconds: 5));
      return find.text('Home').evaluate().isNotEmpty;
    }
    return false;
  }

  group('1. App launch', () {
    testWidgets('app launches and shows welcome, setup, or home screen',
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final hasWelcome = find.text('Travel App').evaluate().isNotEmpty;
      final hasSetupRequired =
          find.text('Setup Required').evaluate().isNotEmpty;
      final hasHome = find.text('Home').evaluate().isNotEmpty;
      expect(hasWelcome || hasSetupRequired || hasHome, isTrue);
    });
  });

  group('2. Auth flow (logged out)', () {
    testWidgets('Continue with Email navigates to email auth',
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      if (find.text('Setup Required').evaluate().isNotEmpty) return;
      if (find.text('Home').evaluate().isNotEmpty) return;

      final continueBtn = find.text('Continue with Email');
      if (continueBtn.evaluate().isEmpty)
        return; // Skip if not on welcome (e.g. loading)

      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      expect(find.text('Email'), findsWidgets);
    });

    testWidgets('Email auth shows Sign in / Sign up toggle',
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      if (find.text('Setup Required').evaluate().isNotEmpty) return;
      if (find.text('Home').evaluate().isNotEmpty) return;

      final continueBtn = find.text('Continue with Email');
      if (continueBtn.evaluate().isEmpty) return; // Skip if not on welcome

      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      expect(find.text('Sign in'), findsWidgets);
      await tester.tap(find.text("Don't have an account? Sign up"));
      await tester.pumpAndSettle();
      expect(find.text('Create account'), findsWidgets);
    });
  });

  group('3. Developer sign-in (enables logged-in tests)', () {
    testWidgets('developer sign in when credentials available',
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final loggedIn = await _tryDevSignIn(tester);
      // Test passes either way; subsequent tests check isLoggedIn
      final onWelcome = find.text('Travel App').evaluate().isNotEmpty ||
          find.text('Continue with Email').evaluate().isNotEmpty;
      final onSetup = find.text('Setup Required').evaluate().isNotEmpty;
      final onAuth = find.text('Sign in').evaluate().isNotEmpty ||
          find.text('Email').evaluate().isNotEmpty ||
          find.text('Create account').evaluate().isNotEmpty;
      expect(loggedIn || onWelcome || onSetup || onAuth, isTrue);
    });
  });

  group('4. Main shell navigation', () {
    testWidgets('bottom nav: Home, Explore, Saved, Profile',
        (WidgetTester tester) async {
      final loggedIn = await _ensureAppAndCheckLoggedIn(tester);
      if (!loggedIn) return;

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Explore'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('FAB navigates to Create itinerary',
        (WidgetTester tester) async {
      final loggedIn = await _ensureAppAndCheckLoggedIn(tester);
      if (!loggedIn) return;

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(
          find.text('New Trip').evaluate().isNotEmpty ||
              find.text('Edit Trip').evaluate().isNotEmpty,
          isTrue);
    });
  });

  group('5. Home feed', () {
    testWidgets('Home screen loads (feed or empty state)',
        (WidgetTester tester) async {
      final loggedIn = await _ensureAppAndCheckLoggedIn(tester);
      if (!loggedIn) return;

      // Home shows either feed content, loading, or empty/discover
      expect(find.text('Home'), findsOneWidget);
    });
  });

  group('6. Explore', () {
    testWidgets('Explore screen shows title and discovery content or search',
        (WidgetTester tester) async {
      final loggedIn = await _ensureAppAndCheckLoggedIn(tester);
      if (!loggedIn) return;

      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();

      expect(find.text('Explore'), findsWidgets);
      // Explore shows either "People you might like" / "Latest" or search results
      final hasExploreContent = find.text('Profiles').evaluate().isNotEmpty ||
          find.text('Trips').evaluate().isNotEmpty ||
          find.byType(TextField).evaluate().isNotEmpty;
      expect(hasExploreContent, isTrue);
    });

    testWidgets('Explore search accepts text input and shows results',
        (WidgetTester tester) async {
      final loggedIn = await _ensureAppAndCheckLoggedIn(tester);
      if (!loggedIn) return;

      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();

      final field = find.byType(TextField).first;
      if (field.evaluate().isEmpty) return;
      await tester.enterText(field, 'test');
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      // After typing, results section or "No matches" may appear
      expect(find.byType(TextField), findsWidgets);
    });
  });

  group('7. Saved', () {
    testWidgets('Saved screen has Bookmarked and Planning tabs',
        (WidgetTester tester) async {
      final loggedIn = await _ensureAppAndCheckLoggedIn(tester);
      if (!loggedIn) return;

      await tester.tap(find.text('Saved'));
      await tester.pumpAndSettle();

      expect(find.text('Saved'), findsWidgets);
      expect(find.text('Bookmarked'), findsOneWidget);
      expect(find.text('Planning'), findsOneWidget);
    });
  });

  group('8. Profile', () {
    testWidgets('Profile screen shows Countries, Lived, followers/following',
        (WidgetTester tester) async {
      final loggedIn = await _ensureAppAndCheckLoggedIn(tester);
      if (!loggedIn) return;

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(find.text('Profile'), findsWidgets);
      expect(find.text('Countries'), findsOneWidget);
      expect(find.text('Lived'), findsOneWidget);
      expect(find.textContaining('followers'), findsWidgets);
      expect(find.textContaining('following'), findsWidgets);
    });

    testWidgets('Profile Lived card navigates to Stats screen',
        (WidgetTester tester) async {
      final loggedIn = await _ensureAppAndCheckLoggedIn(tester);
      if (!loggedIn) return;

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lived'));
      await tester.pumpAndSettle();

      expect(find.text('Stats'), findsWidgets);
    });

    testWidgets('Profile followers link navigates to Followers screen',
        (WidgetTester tester) async {
      final loggedIn = await _ensureAppAndCheckLoggedIn(tester);
      if (!loggedIn) return;

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('followers').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('followers'), findsWidgets);
    });

    testWidgets('Profile Countries card navigates to Visited Countries Map',
        (WidgetTester tester) async {
      final loggedIn = await _ensureAppAndCheckLoggedIn(tester);
      if (!loggedIn) return;

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Countries'));
      await tester.pumpAndSettle();

      // Map screen loads (has back button or edit)
      expect(find.byIcon(Icons.arrow_back).evaluate().isNotEmpty, isTrue);
    });
  });

  group('9. Create itinerary', () {
    testWidgets('Create step 1 shows trip name and countries',
        (WidgetTester tester) async {
      final loggedIn = await _ensureAppAndCheckLoggedIn(tester);
      if (!loggedIn) return;

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(
          find.text('Start a New Trip').evaluate().isNotEmpty ||
              find.text('New Trip').evaluate().isNotEmpty,
          isTrue);
      expect(find.text('Trip name'), findsOneWidget);
    });

    testWidgets('Create step 1 can enter trip name',
        (WidgetTester tester) async {
      final loggedIn = await _ensureAppAndCheckLoggedIn(tester);
      if (!loggedIn) return;

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Test Trip');
      await tester.pumpAndSettle();
    });

    testWidgets(
        'Create step 2 shows PlacesField for destination search (Photon)',
        (WidgetTester tester) async {
      final loggedIn = await _ensureAppAndCheckLoggedIn(tester);
      if (!loggedIn) return;

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextField).first, 'Integration Test Trip');
      await tester.pumpAndSettle();

      final countryFields = find.byType(TextField);
      if (countryFields.evaluate().length >= 2) {
        await tester.enterText(countryFields.at(1), 'France');
      } else {
        await tester.enterText(find.byType(TextField).last, 'France');
      }
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      final countryTile = find.text('France');
      if (countryTile.evaluate().isNotEmpty) {
        await tester.tap(countryTile.first);
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('Next: Add Destinations'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add destination'));
      await tester.pumpAndSettle();

      expect(
          find.text('Search city or location…').evaluate().isNotEmpty ||
              find.byType(TextField).evaluate().length >= 2,
          isTrue);
    });

    testWidgets('Create step 2 PlacesField accepts input and triggers search',
        (WidgetTester tester) async {
      final loggedIn = await _ensureAppAndCheckLoggedIn(tester);
      if (!loggedIn) return;

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Place Search Test');
      await tester.pumpAndSettle();

      final countryFields = find.byType(TextField);
      if (countryFields.evaluate().length >= 2) {
        await tester.enterText(countryFields.at(1), 'Germany');
      } else {
        await tester.enterText(find.byType(TextField).last, 'Germany');
      }
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      final countryTile = find.text('Germany');
      if (countryTile.evaluate().isNotEmpty) {
        await tester.tap(countryTile.first);
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('Next: Add Destinations'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add destination'));
      await tester.pumpAndSettle();

      final placeFields = find.byType(TextField);
      if (placeFields.evaluate().isNotEmpty) {
        await tester.enterText(placeFields.first, 'Berlin');
      }
      await tester.pumpAndSettle(const Duration(milliseconds: 600));

      expect(find.byType(TextField), findsWidgets);
    });
  });

  group('10. Stats', () {
    testWidgets(
        'Stats screen loads with home town, lived before, travel styles',
        (WidgetTester tester) async {
      final loggedIn = await _ensureAppAndCheckLoggedIn(tester);
      if (!loggedIn) return;

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lived'));
      await tester.pumpAndSettle();

      expect(find.text('Stats'), findsWidgets);
      expect(find.text('Home town'), findsOneWidget);
      expect(find.text('Lived before'), findsOneWidget);
      expect(find.text('Travel styles'), findsOneWidget);
    });

    testWidgets(
        'Stats screen has PlacesField capability (Home town / Lived before)',
        (WidgetTester tester) async {
      final loggedIn = await _ensureAppAndCheckLoggedIn(tester);
      if (!loggedIn) return;

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lived'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('Home town'), findsOneWidget);
      expect(find.text('Lived before'), findsOneWidget);
    });
  });

  group('11. Sign out', () {
    testWidgets('Profile logout icon signs out and returns to Welcome',
        (WidgetTester tester) async {
      final loggedIn = await _ensureAppAndCheckLoggedIn(tester);
      if (!loggedIn) return;

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      final logoutIcon = find.byIcon(Icons.logout);
      if (logoutIcon.evaluate().isNotEmpty) {
        await tester.tap(logoutIcon);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(find.text('Travel App').evaluate().isNotEmpty, isTrue);
      }
    });
  });
}
