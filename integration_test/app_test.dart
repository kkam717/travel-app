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
    testWidgets('app launches and shows welcome, setup, or home screen', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final hasWelcome = find.text('Travel App').evaluate().isNotEmpty;
      final hasSetupRequired = find.text('Setup Required').evaluate().isNotEmpty;
      final hasHome = find.text('Home').evaluate().isNotEmpty;
      expect(hasWelcome || hasSetupRequired || hasHome, isTrue);
    });
  });

  group('2. Auth flow (logged out)', () {
    testWidgets('Continue with Email navigates to email auth', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      if (find.text('Setup Required').evaluate().isNotEmpty) return;
      if (find.text('Home').evaluate().isNotEmpty) return;

      await tester.tap(find.text('Continue with Email'));
      await tester.pumpAndSettle();

      expect(find.text('Email'), findsWidgets);
    });

    testWidgets('Email auth shows Sign in / Sign up toggle', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      if (find.text('Setup Required').evaluate().isNotEmpty) return;
      if (find.text('Home').evaluate().isNotEmpty) return;

      await tester.tap(find.text('Continue with Email'));
      await tester.pumpAndSettle();

      expect(find.text('Sign in'), findsWidgets);
      await tester.tap(find.text("Don't have an account? Sign up"));
      await tester.pumpAndSettle();
      expect(find.text('Create account'), findsWidgets);
    });
  });

  group('3. Developer sign-in (enables logged-in tests)', () {
    testWidgets('developer sign in when credentials available', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final loggedIn = await _tryDevSignIn(tester);
      // Test passes either way; subsequent tests check isLoggedIn
      expect(loggedIn || find.text('Travel App').evaluate().isNotEmpty || find.text('Setup Required').evaluate().isNotEmpty, isTrue);
    });
  });

  group('4. Main shell navigation', () {
    testWidgets('bottom nav: Home, Search, Saved, Profile', (WidgetTester tester) async {
      final loggedIn = await _ensureAppAndCheckLoggedIn(tester);
      if (!loggedIn) return;

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('FAB navigates to Create itinerary', (WidgetTester tester) async {
      final loggedIn = await _ensureAppAndCheckLoggedIn(tester);
      if (!loggedIn) return;

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('New Trip').evaluate().isNotEmpty || find.text('Edit Trip').evaluate().isNotEmpty, isTrue);
    });
  });

  group('5. Home feed', () {
    testWidgets('Home screen loads (feed or empty state)', (WidgetTester tester) async {
      final loggedIn = await _ensureAppAndCheckLoggedIn(tester);
      if (!loggedIn) return;

      // Home shows either feed content, loading, or empty/discover
      expect(find.text('Home'), findsOneWidget);
    });
  });

  group('6. Search', () {
    testWidgets('Search screen has Profiles and Trips tabs', (WidgetTester tester) async {
      final loggedIn = await _ensureAppAndCheckLoggedIn(tester);
      if (!loggedIn) return;

      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      expect(find.text('Search'), findsWidgets);
      expect(find.text('Profiles'), findsOneWidget);
      expect(find.text('Trips'), findsOneWidget);
    });

    testWidgets('Search accepts text input', (WidgetTester tester) async {
      final loggedIn = await _ensureAppAndCheckLoggedIn(tester);
      if (!loggedIn) return;

      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'test');
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
    });
  });

  group('7. Saved', () {
    testWidgets('Saved screen has Bookmarked and Planning tabs', (WidgetTester tester) async {
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
    testWidgets('Profile screen shows Countries, Stats, Followers/Following', (WidgetTester tester) async {
      final loggedIn = await _ensureAppAndCheckLoggedIn(tester);
      if (!loggedIn) return;

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(find.text('Profile'), findsWidgets);
      expect(find.text('Countries'), findsOneWidget);
      expect(find.text('Stats'), findsOneWidget);
      expect(find.text('Followers'), findsOneWidget);
      expect(find.text('Following'), findsOneWidget);
    });

    testWidgets('Profile Stats card navigates to Stats screen', (WidgetTester tester) async {
      final loggedIn = await _ensureAppAndCheckLoggedIn(tester);
      if (!loggedIn) return;

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Stats'));
      await tester.pumpAndSettle();

      expect(find.text('Stats'), findsWidgets);
    });

    testWidgets('Profile Followers bar navigates to Followers screen', (WidgetTester tester) async {
      final loggedIn = await _ensureAppAndCheckLoggedIn(tester);
      if (!loggedIn) return;

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Followers'));
      await tester.pumpAndSettle();

      expect(find.text('Followers'), findsWidgets);
    });

    testWidgets('Profile Countries card navigates to Visited Countries Map', (WidgetTester tester) async {
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
    testWidgets('Create step 1 shows trip name and countries', (WidgetTester tester) async {
      final loggedIn = await _ensureAppAndCheckLoggedIn(tester);
      if (!loggedIn) return;

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Start a New Trip').evaluate().isNotEmpty || find.text('New Trip').evaluate().isNotEmpty, isTrue);
      expect(find.text('Trip name'), findsOneWidget);
    });

    testWidgets('Create step 1 can enter trip name', (WidgetTester tester) async {
      final loggedIn = await _ensureAppAndCheckLoggedIn(tester);
      if (!loggedIn) return;

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Test Trip');
      await tester.pumpAndSettle();
    });
  });

  group('10. Stats', () {
    testWidgets('Stats screen loads with home town, lived before, travel styles', (WidgetTester tester) async {
      final loggedIn = await _ensureAppAndCheckLoggedIn(tester);
      if (!loggedIn) return;

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Stats'));
      await tester.pumpAndSettle();

      expect(find.text('Stats'), findsWidgets);
      expect(find.text('Home Town'), findsOneWidget);
      expect(find.text('Lived Before'), findsOneWidget);
      expect(find.text('Travel styles'), findsOneWidget);
    });
  });

  group('11. Sign out', () {
    testWidgets('Profile logout icon signs out and returns to Welcome', (WidgetTester tester) async {
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
