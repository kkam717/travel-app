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
import 'core/analytics.dart';

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
        path: '/author/:id',
        builder: (_, state) {
          final id = state.pathParameters['id']!;
          return AuthorProfileScreen(authorId: id);
        },
      ),
    ],
  );
}
