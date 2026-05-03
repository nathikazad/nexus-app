import 'package:flutter_test/flutter_test.dart';
import 'package:nx_notes/domain/essay/essay_query.dart';

void main() {
  test('tag filter records hierarchy intent', () {
    const filter = EssayTagFilter(
      system: 'Area',
      node: 'Work',
      includeDescendants: true,
    );

    expect(filter.system, 'Area');
    expect(filter.node, 'Work');
    expect(filter.includeDescendants, isTrue);
  });
}
