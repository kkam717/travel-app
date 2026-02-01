import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:travel_app/core/theme.dart';
import 'package:travel_app/screens/welcome_screen.dart';
import 'package:travel_app/screens/email_auth_screen.dart';
import 'package:travel_app/screens/onboarding_screen.dart';
import 'package:travel_app/screens/main_shell.dart';
import 'package:travel_app/screens/home_screen.dart';
import 'package:travel_app/screens/search_screen.dart';
import 'package:travel_app/screens/saved_screen.dart';
import 'package:travel_app/screens/profile_screen.dart';
import 'package:travel_app/screens/create_itinerary_screen.dart';
import 'package:travel_app/screens/itinerary_detail_screen.dart';
import 'package:travel_app/screens/author_profile_screen.dart';
import 'package:travel_app/screens/city_detail_screen.dart';
import 'package:travel_app/screens/visited_countries_map_screen.dart';
import 'package:travel_app/screens/my_trips_screen.dart';
import 'package:travel_app/screens/followers_screen.dart';
import 'package:travel_app/screens/profile_stats_screen.dart';

/// Creates a GoRouter for testing that does NOT check Supabase auth.
/// Use this to test screens in isolation without initializing Supabase.
GoRouter createTestRouter({String initialLocation = '/'}) {
  return GoRouter(
    initialLocation: initialLocation,
    redirect: (_, __) => null, // No auth redirect in tests
    routes: [
      GoRoute(path: '/', builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: '/auth/email', builder: (_, __) => const EmailAuthScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      ShellRoute(
        builder: (_, __, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (_, __) => const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: '/search',
            pageBuilder: (_, __) => const NoTransitionPage(child: SearchScreen()),
          ),
          GoRoute(
            path: '/create',
            pageBuilder: (_, __) => const NoTransitionPage(child: CreateItineraryScreen()),
          ),
          GoRoute(
            path: '/saved',
            pageBuilder: (_, __) => const NoTransitionPage(child: SavedScreen()),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (_, __) => const NoTransitionPage(child: ProfileScreen()),
          ),
        ],
      ),
      GoRoute(
        path: '/itinerary/:id',
        builder: (_, state) {
          final id = state.pathParameters['id'] ?? '';
          return ItineraryDetailScreen(itineraryId: id);
        },
      ),
      GoRoute(
        path: '/itinerary/:id/edit',
        builder: (_, state) {
          final id = state.pathParameters['id'] ?? '';
          return CreateItineraryScreen(itineraryId: id);
        },
      ),
      GoRoute(
        path: '/author/:id',
        builder: (_, state) {
          final id = state.pathParameters['id'] ?? '';
          return AuthorProfileScreen(authorId: id);
        },
      ),
      GoRoute(
        path: '/city/:cityName',
        builder: (_, state) {
          final cityName = Uri.decodeComponent(state.pathParameters['cityName'] ?? '');
          final userId = state.uri.queryParameters['userId'] ?? '';
          return CityDetailScreen(
            userId: userId,
            cityName: cityName,
            isOwnProfile: false,
          );
        },
      ),
      GoRoute(
        path: '/map/countries',
        builder: (_, state) {
          final codes = state.uri.queryParameters['codes']?.split(',').where((s) => s.isNotEmpty).toList() ?? [];
          final canEdit = state.uri.queryParameters['editable'] == '1';
          return VisitedCountriesMapScreen(visitedCountryCodes: codes, canEdit: canEdit);
        },
      ),
      GoRoute(path: '/profile/trips', builder: (_, __) => const MyTripsScreen()),
      GoRoute(
        path: '/profile/stats',
        builder: (_, state) {
          final userId = state.uri.queryParameters['userId'];
          return ProfileStatsScreen(userId: userId);
        },
      ),
      GoRoute(
        path: '/trips/:userId',
        builder: (_, state) {
          final userId = state.pathParameters['userId'];
          return MyTripsScreen(userId: userId?.isEmpty == true ? null : userId);
        },
      ),
      GoRoute(path: '/profile/followers', builder: (_, __) => const FollowersScreen(showFollowing: false)),
      GoRoute(path: '/profile/following', builder: (_, __) => const FollowersScreen(showFollowing: true)),
    ],
  );
}

/// Pumps the app with test router for widget tests.
Future<void> pumpTestApp(
  WidgetTester tester, {
  String initialLocation = '/',
}) async {
  await tester.pumpWidget(
    MaterialApp.router(
      title: 'Travel App Test',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: createTestRouter(initialLocation: initialLocation),
    ),
  );
}
