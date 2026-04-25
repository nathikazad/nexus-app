import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Each tab `*_screen.dart` must import both `mobile_*_body` and `desktop_*_body`
/// (view-shape recipe in `docs/arch.md`).
void main() {
  final cases = <String, List<String>>{
    'lib/features/priority/priority_screen.dart': [
      'mobile_priority_body.dart',
      'desktop_priority_body.dart',
    ],
    'lib/features/projects/projects_screen.dart': [
      'mobile_projects_body.dart',
      'desktop_projects_body.dart',
    ],
    'lib/features/sprint/sprint_screen.dart': [
      'mobile_sprint_body.dart',
      'desktop_sprint_body.dart',
    ],
    'lib/features/daily/daily_screen.dart': [
      'mobile_daily_body.dart',
      'desktop_daily_body.dart',
    ],
  };

  for (final e in cases.entries) {
    test('${e.key} imports view-shape bodies', () {
      final file = File(e.key);
      expect(file.existsSync(), isTrue);
      final text = file.readAsStringSync();
      for (final name in e.value) {
        expect(
          text.contains(name),
          isTrue,
          reason: 'Expected import of $name',
        );
      }
    });
  }
}
