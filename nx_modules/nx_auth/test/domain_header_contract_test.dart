import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every app and shared module uses the canonical domain header', () {
    final root = Directory.current.parent.parent;
    expect(Directory('${root.path}/nx_cards/lib').existsSync(), isTrue);
    final retired =
        'x-'
        'nexus-domain-id';
    final offending = <String>[];
    final packages = [
      ...root.listSync().whereType<Directory>().where(
        (d) => d.path.split('/').last.startsWith('nx_'),
      ),
      ...Directory('${root.path}/nx_modules').listSync().whereType<Directory>(),
    ];
    for (final package in packages) {
      for (final folder in [
        'lib',
        'android/src',
        'android/app/src',
        'ios/Classes',
        'ios/Runner',
        'macos/Runner',
      ]) {
        final source = Directory('${package.path}/$folder');
        if (!source.existsSync()) continue;
        for (final file
            in source
                .listSync(recursive: true, followLinks: false)
                .whereType<File>()) {
          if (!RegExp(r'\.(dart|kt|java|swift|m|mm)$').hasMatch(file.path))
            continue;
          if (file.readAsStringSync().toLowerCase().contains(retired))
            offending.add(file.path);
        }
      }
    }
    expect(
      offending,
      isEmpty,
      reason: 'All app transports must use x-domain-id.',
    );
  });
}
