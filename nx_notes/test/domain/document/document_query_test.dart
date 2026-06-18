import 'package:flutter_test/flutter_test.dart';
import 'package:nx_notes/domain/document/document_query.dart';

void main() {
  test('tag filter records hierarchy intent', () {
    const filter = DocumentTagFilter(
      system: 'Area',
      node: 'Work',
      includeDescendants: true,
    );

    expect(filter.system, 'Area');
    expect(filter.node, 'Work');
    expect(filter.includeDescendants, isTrue);
  });
}
