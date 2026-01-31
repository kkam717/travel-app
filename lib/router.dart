import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import 'screens/welcome_screen.dart';
import 'screens/email_auth_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_shell.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/search_screen.dart';
import 'screens/create_itinerary_screen.dart';
import 'screens/saved_screen.dart';
import 'screens/itinerary_detail_screen.dart';
import 'screens/author_profile_screen.dart';
import 'screens/city_detail_screen.dart';
import 'screens/visited_countries_map_screen.dart';
import 'screens/my_trips_screen.dart';
import 'screens/followers_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter() {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) async {
      final session = Supabase.instance.client.auth.currentSession;
      final isAuth = session != null;
      final isAuthRoute = state.matchedLocation == '/' || state.matchedLocation.startsWith('/auth');
      final isOnboardingRoute = state.matchedLocation.startsWith('/onboarding');

      if (!isAuth) {
        if (!isAuthRoute) return '/';
        return null;
      }

      final userId = session!.user.id;
      final profile = await SupabaseService.getProfile(userId);
      final needsOnboarding = profile == null || !profile.onboardingComplete;

      if (needsOnboarding && !isOnboardingRoute) {
        return '/onboarding';
      }
      if (!needsOnboarding && isOnboardingRoute) {
        return '/home';
      }
      if (!needsOnboarding && state.matchedLocation == '/') {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/auth/email',
        builder: (_, __) => const EmailAuthScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (_, __, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (_, state) => const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: '/search',
            pageBuilder: (_, state) => const NoTransitionPage(child: SearchScreen()),
          ),
          GoRoute(
            path: '/create',
            pageBuilder: (_, state) => const NoTransitionPage(child: CreateItineraryScreen()),
          ),
          GoRoute(
            path: '/saved',
            pageBuilder: (_, state) => const NoTransitionPage(child: SavedScreen()),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (_, state) => const NoTransitionPage(child: ProfileScreen()),
          ),
        ],
      ),
      GoRoute(
        path: '/itinerary/:id',
        builder: (_, state) {
          final id = state.pathParameters['id']!;
          return ItineraryDetailScreen(itineraryId: id);
        },
      ),
      GoRoute(
        path: '/itinerary/:id/edit',
        builder: (_, state) {
          final id = state.pathParameters['id']!;
          return CreateItineraryScreen(itineraryId: id);
        },
      ),
      GoRoute(
        path: '/author/:id',
        builder: (_, state) {
          final id = state.pathParameters['id']!;
          return AuthorProfileScreen(authorId: id);
        },
      ),
      GoRoute(
        path: '/city/:cityName',
        builder: (_, state) {
          final cityName = Uri.decodeComponent(state.pathParameters['cityName']!);
          final userId = state.uri.queryParameters['userId'] ?? Supabase.instance.client.auth.currentUser?.id ?? '';
          final isOwn = Supabase.instance.client.auth.currentUser?.id == userId;
          return CityDetailScreen(
            userId: userId,
            cityName: cityName,
            isOwnProfile: isOwn,
          );
        },
      ),
      GoRoute(
        path: '/map/countries',
        builder: (_, state) {
          final codes = state.uri.queryParameters['codes']?.split(',').where((s) => s.isNotEmpty).toList() ?? [];
          return VisitedCountriesMapScreen(visitedCountryCodes: codes);
        },
      ),
      GoRoute(
        path: '/profile/trips',
        builder: (_, __) => const MyTripsScreen(),
      ),
      GoRoute(
        path: '/profile/followers',
        builder: (_, __) => const FollowersScreen(),
      ),
    ],
  );
}
