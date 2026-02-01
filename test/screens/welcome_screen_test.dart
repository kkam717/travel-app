import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:travel_app/core/theme.dart';
import 'package:travel_app/screens/welcome_screen.dart';
import 'package:travel_app/screens/email_auth_screen.dart';

void main() {
  group('WelcomeScreen', () {
    late GoRouter router;

    setUpAll(() {
      dotenv.testLoad(fileInput: 'SUPABASE_URL=https://test.supabase.co\nSUPABASE_ANON_KEY=test-key\n');
    });

    setUp(() {
      router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (_, __) => const WelcomeScreen()),
          GoRoute(path: '/auth/email', builder: (_, __) => const EmailAuthScreen()),
        ],
      );
    });

    testWidgets('renders app title and tagline', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Travel App'), findsOneWidget);
      expect(find.text('Plan trips, discover places, share adventures'), findsOneWidget);
    });

    testWidgets('shows Continue with Email button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Continue with Email'), findsOneWidget);
    });

    testWidgets('tapping Continue with Email navigates to email auth', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue with Email'));
      await tester.pumpAndSettle();

      expect(find.byType(EmailAuthScreen), findsOneWidget);
    });

    testWidgets('shows Apple and Google sign in buttons', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Continue with Apple'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('tapping Apple shows coming soon snackbar', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue with Apple'));
      await tester.pumpAndSettle();

      expect(find.text('Apple Sign In coming soon'), findsOneWidget);
    });

    testWidgets('tapping Google shows coming soon snackbar', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(find.text('Google Sign In coming soon'), findsOneWidget);
    });
  });
}
