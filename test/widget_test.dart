import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app/main.dart';

void main() {
  testWidgets('TravelApp smoke test', (WidgetTester tester) async {
    expect(const TravelApp(), isNotNull);
  });
}
