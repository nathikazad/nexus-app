import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lib/ has no top-level state/ (use domain + features/ per arch.md)', () {
    expect(Directory('lib/state').existsSync(), isFalse);
  });

  test(
    'lib/ top-level names match arch.md: core, data, domain, features + app shell',
    () {
      final libRoot = Directory('lib');
      final allowedDirs = {'core', 'data', 'domain', 'features'};
      final allowedFiles = {'main.dart', 'app.dart', 'router.dart'};
      for (final entity in libRoot.listSync()) {
        final name = entity.path.split(Platform.pathSeparator).last;
        if (entity is Directory) {
          expect(
            allowedDirs.contains(name),
            isTrue,
            reason: 'Unexpected directory in lib/: $name',
          );
        } else if (entity is File && name.endsWith('.dart')) {
          expect(
            allowedFiles.contains(name),
            isTrue,
            reason: 'Unexpected file in lib/: $name',
          );
        }
      }
    },
  );
}
