import 'package:flutter_test/flutter_test.dart';
import 'package:nx_docs/tags/tag_system.dart';

import '../support/offline_fixtures.dart';

void main() {
  test('builds deterministic tag systems and document counts', () {
    final first = offlineTestDocument().copyWith(
      tagsBySystem: const <String, List<String>>{
        'Topic': <String>['Flutter', 'Offline'],
      },
    );
    final second = offlineTestDocument(id: 2).copyWith(
      tagsBySystem: const <String, List<String>>{
        'Topic': <String>['Flutter', 'Flutter'],
      },
    );

    final systems = tagSystemsFromDocuments([first, second]);

    expect(systems.map((system) => system.name), <String>['Topic']);
    expect(
      systems.last.nodes.map((node) => (node.name, node.count)),
      <(String, int)>[('Flutter', 2), ('Offline', 1)],
    );
  });
}
