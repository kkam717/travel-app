import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:travel_app/core/theme.dart';
import 'package:travel_app/screens/onboarding_screen.dart';

void main() {
  group('OnboardingScreen', () {
    late GoRouter router;

    setUp(() {
      router = GoRouter(
        initialLocation: '/onboarding',
        routes: [
          GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
        ],
      );
    });

    testWidgets('renders step 1 - Countries visited', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Countries visited'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('shows step indicator with 2 steps', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign out'), findsOneWidget);
    });

    testWidgets('advances to step 2 when Next tapped on Countries', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Travel preferences'), findsOneWidget);
    });

    testWidgets('step 2 shows travel styles and mode options', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Get started'), findsOneWidget);
    });
  });
}
