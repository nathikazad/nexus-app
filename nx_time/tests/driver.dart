// Host-side driver: receives PNG bytes from the device over `binding.takeScreenshot`
// and writes them under `tests/screenshots/` next to this file.
//
// Run:
//   flutter drive \
//     --driver=tests/driver.dart \
//     --target=tests/screenshot_test.dart \
//     -d <ios_simulator_id>

import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final dir = Directory('tests/screenshots');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final safe = name.replaceAll(RegExp(r'[^\w\-]'), '_');
      final file = File('tests/screenshots/$safe.png');
      await file.writeAsBytes(bytes);
      stdout.writeln('Saved screenshot: ${file.absolute.path} (${bytes.length} bytes)');
      return true;
    },
  );
}
