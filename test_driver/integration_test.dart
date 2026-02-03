import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final screenshotDir = Directory('/Users/kiankamshad/Travel App/screenshots');
  
  await integrationDriver(
    onScreenshot: (String screenshotName, List<int> screenshotBytes, [Map<String, Object?>? args]) async {
      // screenshotName already includes .png from takeScreenshot call
      final file = File('${screenshotDir.path}/$screenshotName');
      await file.create(recursive: true);
      await file.writeAsBytes(screenshotBytes);
      print('Screenshot saved: $screenshotName');
      return true;
    },
  );
}
