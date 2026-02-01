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

    testWidgets('renders step 1 - Your name', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Your name'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('shows step indicator with 3 steps', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign out'), findsOneWidget);
    });

    testWidgets('advances to step 2 when Next tapped with name', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Alice');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Countries visited'), findsOneWidget);
    });

    testWidgets('advances to step 3 when Next tapped on step 2', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Alice');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Travel preferences'), findsOneWidget);
    });

    testWidgets('step 3 shows travel styles and mode options', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Alice');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Get started'), findsOneWidget);
    });
  });
}
