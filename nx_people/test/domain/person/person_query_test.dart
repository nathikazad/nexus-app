import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_people/data/fake_people_repository.dart';

void main() {
  test('people repository filters search and context rows', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final repository = container.read(peopleRepositoryProvider);

    expect(repository.search('atlas').map((person) => person.name), [
      'Marcus Rivera',
      'Daniel Brooks',
    ]);

    expect(repository.context('Company', 'Northstar Labs').personIds, [1, 6]);
    expect(repository.context('Status', 'Follow up').personIds, [1, 6]);
    expect(repository.context('Meeting', 'Investor Intro').personIds, [1, 2, 4]);
  });
}
