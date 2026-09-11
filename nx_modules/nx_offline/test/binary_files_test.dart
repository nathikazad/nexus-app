import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_offline/nx_offline_storage.dart';

void main() {
  late Directory temporary;
  late BinaryContentFiles files;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('nx-binary-files-');
    files = DirectoryBinaryContentFiles('${temporary.path}/content');
  });

  tearDown(() => temporary.delete(recursive: true));

  test('streams, verifies, and reuses content-addressed files', () async {
    final reference = await files.write(
      'books',
      '42',
      '.epub',
      Stream.fromIterable([
        [1, 2],
        [3, 4],
      ]),
    );
    expect(reference.bytes, 4);
    expect(await files.verify(reference), isTrue);
    final path = await files.localPath(reference);
    expect(await File(path).readAsBytes(), [1, 2, 3, 4]);

    final again = await files.write(
      'books',
      '42',
      '.epub',
      Stream.value([1, 2, 3, 4]),
    );
    expect(again.path, reference.path);
  });

  test('detects corruption and repairs the exact content', () async {
    final reference = await files.write(
      'books',
      '7',
      '.pdf',
      Stream.value([5, 6, 7]),
    );
    await File(await files.localPath(reference)).writeAsBytes([0, 0, 0]);
    expect(await files.verify(reference), isFalse);
    await expectLater(
      files.localPath(reference),
      throwsA(isA<FileSystemException>()),
    );

    final repaired = await files.write(
      'books',
      '7',
      '.pdf',
      Stream.value([5, 6, 7]),
    );
    expect(repaired.path, reference.path);
    expect(await files.verify(repaired), isTrue);
  });

  test('rejects unsafe extensions and references', () async {
    await expectLater(
      files.write('books', '1', '../pdf', Stream.value([1])),
      throwsFormatException,
    );
    expect(
      await files.verify(
        const BinaryContentReference(
          path: '../outside/file.pdf',
          hash: 'bad',
          bytes: 1,
        ),
      ),
      isFalse,
    );
  });
}
