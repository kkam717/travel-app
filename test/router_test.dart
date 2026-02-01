import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:travel_app/router.dart';

void main() {
  group('Router', () {
    test('createRouter returns non-null GoRouter', () {
      final router = createRouter();
      expect(router, isNotNull);
      expect(router, isA<GoRouter>());
    });
  });
}
