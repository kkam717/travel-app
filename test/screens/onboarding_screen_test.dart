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

    testWidgets('renders Travel preferences', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Travel preferences'), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);
    });

    testWidgets('shows Sign out', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign out'), findsOneWidget);
    });

    testWidgets('shows travel styles and mode options', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Travel styles'), findsOneWidget);
      expect(find.text('Travel mode'), findsOneWidget);
    });
  });
}
