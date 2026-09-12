import 'package:epub_view/src/data/image_target.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Nudge images resolve relative to their nested chapter', () {
    const keys = ['OEBPS/image/17-1.jpg', 'OEBPS/image/18-1.jpg'];
    for (final number in ['17', '18']) {
      expect(resolveEpubImageKey('../image/$number-1.jpg',
          'OEBPS/xhtml/11_chapter001.xhtml', keys), 'OEBPS/image/$number-1.jpg');
    }
  });
  test('root, encoded and normalized paths retain exact manifest keys', () {
    expect(resolveEpubImageKey('cover.png', 'one.xhtml', ['cover.png']), 'cover.png');
    expect(resolveEpubImageKey('../image/a%20b.png#fig', 'Text/ch.xhtml',
        ['image/a b.png']), 'image/a b.png');
    expect(resolveEpubImageKey('../image/./a.png?x=1', 'Text/ch.xhtml',
        ['image/a.png']), 'image/a.png');
    expect(resolveEpubImageKey('pic.png', 'Text/ch.xhtml',
        ['Other/pic.png', 'Text/pic.png']), 'Text/pic.png');
  });
  test('missing and external assets never fall back to a same-named file', () {
    for (final source in ['missing.png', 'https://example.com/pic.png', '//example.com/pic.png', '%zz']) {
      expect(resolveEpubImageKey(source, 'Text/ch.xhtml', ['Other/missing.png']), isNull);
    }
  });
}
