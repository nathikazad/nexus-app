import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Same guard as [nx_time]: `lib/domain/` must stay pure Dart.
void main() {
  test('lib/domain has no flutter / riverpod imports', () {
    final root = Directory.current;
    final domain = Directory('${root.path}/lib/domain');
    expect(domain.existsSync(), isTrue, reason: 'lib/domain/ must exist');
    final bad = <String, List<String>>{};
    for (final f in domain.listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final text = f.readAsStringSync();
      for (final line in const [
        "import 'package:flutter",
        "import 'package:flutter_riverpod",
      ]) {
        if (text.contains(line)) {
          final rel = f.path.replaceFirst('${root.path}/', '');
          bad[rel] = (bad[rel] ?? [])..add(line);
        }
      }
    }
    expect(
      bad,
      isEmpty,
      reason: 'Remove Flutter/Riverpod from domain: $bad',
    );
  });
}
