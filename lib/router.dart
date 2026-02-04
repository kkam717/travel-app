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
import 'screens/explore_screen.dart';
import 'screens/create_itinerary_screen.dart';
import 'screens/saved_screen.dart';
import 'screens/itinerary_detail_screen.dart';
import 'screens/author_profile_screen.dart';
import 'screens/city_detail_screen.dart';
import 'screens/visited_countries_map_screen.dart';
import 'screens/my_trips_screen.dart';
import 'screens/followers_screen.dart';
import 'screens/profile_stats_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/profile_qr_screen.dart';
import 'screens/profile_qr_view_screen.dart';

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
      if (!needsOnboarding && state.matchedLocation == '/search') {
        return '/explore';
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
            path: '/explore',
            pageBuilder: (_, state) => const NoTransitionPage(child: ExploreScreen()),
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
        routes: [
          GoRoute(
            path: 'qr',
            builder: (_, state) {
              final id = state.pathParameters['id']!;
              final extra = state.extra as Map<String, dynamic>?;
              final userName = extra?['userName'] as String?;
              return ProfileQRViewScreen(userId: id, userName: userName);
            },
          ),
        ],
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
          final canEdit = state.uri.queryParameters['editable'] == '1';
          return VisitedCountriesMapScreen(visitedCountryCodes: codes, canEdit: canEdit);
        },
      ),
      GoRoute(
        path: '/profile/trips',
        builder: (_, __) => const MyTripsScreen(),
      ),
      GoRoute(
        path: '/profile/stats',
        builder: (_, state) {
          final userId = state.uri.queryParameters['userId'];
          final open = state.uri.queryParameters['open'];
          return ProfileStatsScreen(userId: userId, openEditor: open);
        },
      ),
      GoRoute(
        path: '/trips/:userId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) {
          final userId = state.pathParameters['userId'] ?? state.uri.pathSegments.lastOrNull;
          return MyTripsScreen(userId: userId?.isEmpty == true ? null : userId);
        },
      ),
      GoRoute(
        path: '/profile/settings',
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/profile/qr',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final userId = extra?['userId'] as String? ?? Supabase.instance.client.auth.currentUser?.id ?? '';
          final userName = extra?['userName'] as String?;
          return ProfileQRScreen(userId: userId, userName: userName);
        },
      ),
      GoRoute(
        path: '/profile/followers',
        builder: (_, state) {
          final userId = state.uri.queryParameters['userId'];
          return FollowersScreen(userId: userId, showFollowing: false);
        },
      ),
      GoRoute(
        path: '/profile/following',
        builder: (_, state) {
          final userId = state.uri.queryParameters['userId'];
          return FollowersScreen(userId: userId, showFollowing: true);
        },
      ),
    ],
  );
}
