import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app/main.dart';

void main() {
  group('SetupRequiredApp', () {
    testWidgets('renders setup required message', (WidgetTester tester) async {
      await tester.pumpWidget(const SetupRequiredApp());
      await tester.pumpAndSettle();

      expect(find.text('Setup Required'), findsOneWidget);
      expect(find.textContaining('Add your Supabase credentials'), findsOneWidget);
    });

    testWidgets('shows settings icon', (WidgetTester tester) async {
      await tester.pumpWidget(const SetupRequiredApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.settings), findsOneWidget);
    });
  });

  group('ErrorApp', () {
    testWidgets('renders error message', (WidgetTester tester) async {
      const error = 'Test error message';
      await tester.pumpWidget(const ErrorApp(error: error));
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text(error), findsOneWidget);
    });

    testWidgets('shows error icon', (WidgetTester tester) async {
      await tester.pumpWidget(const ErrorApp(error: 'Error'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });
}
