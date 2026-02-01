import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:travel_app/core/theme.dart';
import 'package:travel_app/screens/main_shell.dart';

void main() {
  group('MainShell', () {
    testWidgets('renders bottom nav with Home, Search, Saved, Profile', (WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          ShellRoute(
            builder: (_, __, child) => MainShell(child: child),
            routes: [
              GoRoute(
                path: '/home',
                pageBuilder: (_, __) => const NoTransitionPage(child: Placeholder()),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('renders FAB for create', (WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          ShellRoute(
            builder: (_, __, child) => MainShell(child: child),
            routes: [
              GoRoute(
                path: '/home',
                pageBuilder: (_, __) => const NoTransitionPage(child: Placeholder()),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });

    testWidgets('FAB tap navigates to create route', (WidgetTester tester) async {
      const createPageKey = Key('create_page');
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          ShellRoute(
            builder: (_, __, child) => MainShell(child: child),
            routes: [
              GoRoute(
                path: '/home',
                pageBuilder: (_, __) => const NoTransitionPage(child: Placeholder()),
              ),
              GoRoute(
                path: '/create',
                pageBuilder: (_, __) => NoTransitionPage(
                  child: Placeholder(key: createPageKey),
                ),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.byKey(createPageKey), findsOneWidget);
    });
  });
}
