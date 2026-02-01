import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:travel_app/core/theme.dart';
import 'package:travel_app/screens/email_auth_screen.dart';

void main() {
  group('EmailAuthScreen', () {
    late GoRouter router;

    setUp(() {
      router = GoRouter(
        initialLocation: '/auth/email',
        routes: [
          GoRoute(path: '/auth/email', builder: (_, __) => const EmailAuthScreen()),
        ],
      );
    });

    testWidgets('renders email auth form', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EmailAuthScreen), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2)); // email and password
    });

    testWidgets('shows Sign in by default', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign in'), findsWidgets);
    });

    testWidgets('has back button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });

    testWidgets('can toggle to Sign up mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("Don't have an account? Sign up"));
      await tester.pumpAndSettle();

      expect(find.text('Create account'), findsWidgets);
    });

    testWidgets('validates empty email', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Enter your email'), findsOneWidget);
    });
  });
}
