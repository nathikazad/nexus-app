import 'package:flutter_test/flutter_test.dart';
import 'package:epub_view/src/ui/paged_content.dart';

void main() {
  test('EPUB window follows position and stays bounded', () {
    final text = List.generate(2000, (i) => 'word$i').join(' ');
    final window = epubReadingWindow(text, text.indexOf('word500'));
    expect(window, startsWith('word400 '));
    expect(window, contains('[Current reading position]\nword500 '));
    expect(window, endsWith('word899'));
    expect(epubReadingWindow('', 0), isEmpty);
    expect(
      epubReadingWindow(text, 0),
      startsWith('\n[Current reading position]\nword0'),
    );
    expect(epubReadingWindow(text, text.length), endsWith('word1999'));
    expect(epubReadingWindow('x' * 10000, 0).length, lessThan(5800));
  });
}
