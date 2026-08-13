import 'package:flutter_test/flutter_test.dart';
import 'package:nx_docs/domain/tags/tag_system_index.dart';

import '../../support/offline_fixtures.dart';

void main() {
  test('builds deterministic tag systems and document counts', () {
    final first = offlineTestDocument().copyWith(
      tagsBySystem: const <String, List<String>>{
        'Topic': <String>['Flutter', 'Offline'],
        'Status': <String>['Draft'],
      },
    );
    final second = offlineTestDocument(id: 2).copyWith(
      tagsBySystem: const <String, List<String>>{
        'Topic': <String>['Flutter', 'Flutter'],
        'Status': <String>['Published'],
      },
    );

    final systems = tagSystemsFromDocuments([first, second]);

    expect(systems.map((system) => system.name), <String>['Status', 'Topic']);
    expect(
      systems.last.nodes.map((node) => (node.name, node.count)),
      <(String, int)>[('Flutter', 2), ('Offline', 1)],
    );
  });
}
