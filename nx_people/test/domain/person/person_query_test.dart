import 'package:flutter_test/flutter_test.dart';
import 'package:nx_people/data/fake_people_repository.dart';

void main() {
  test('people repository filters search and context rows', () async {
    final repository = FakePeopleRepository();

    expect((await repository.search('atlas')).map((person) => person.name), [
      'Marcus Rivera',
      'Daniel Brooks',
    ]);

    expect((await repository.context('Company', 'Northstar Labs')).personIds, [
      1,
      6,
    ]);
    expect((await repository.context('Status', 'Follow up')).personIds, [1, 6]);
    expect((await repository.context('Meeting', 'Investor Intro')).personIds, [
      1,
      2,
      4,
    ]);
  });
}
