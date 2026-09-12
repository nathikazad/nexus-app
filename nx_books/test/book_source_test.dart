import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:epub_view/epub_view.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:nx_books/epub/book_source.dart';
import 'package:nx_books/epub/chapter_book_source.dart';
import 'package:nx_books/epub/epub_source_resolver.dart';
import 'package:nx_books/epub/epub_reader_page.dart';
import 'package:nx_documents/nx_documents.dart';
import 'epub_reader_test.dart' show sampleEpub;

final sourceJson = <String, dynamic>{
  'version': 1,
  'book_id': 23,
  'sha256': 'a' * 64,
  'resource': 'two.xhtml',
  'quote': {'exact': 'Target paragraph.'},
};

void main() {
  test('portable metadata roundtrips and rejects malformed destinations', () {
    expect(BookSource.fromJson(sourceJson)!.toJson(), sourceJson);
    for (final bad in [
      {...sourceJson, 'version': 2},
      {...sourceJson, 'book_id': '23'},
      {...sourceJson, 'resource': '../file'},
      {...sourceJson, 'resource': 'https://example.com'},
      {
        ...sourceJson,
        'quote': {'exact': ''},
      },
      {...sourceJson, 'sha256': 'oops'},
    ]) {
      expect(BookSource.fromJson(bad), isNull);
    }
  });

  test('only an actual chapter related to that book exposes a source', () {
    DocumentContent content(String? type, int parent) => DocumentContent(
      identity: const DocumentIdentity(id: 7, modelType: 'Document'),
      modelTypeName: type,
      modelRelations: [
        DocumentModelRelation(parent, 'Book', 'book_book_chapter'),
      ],
      title: 'Chapter',
      plainText: '',
      jsonDocument: {},
      updatedAt: DateTime.utc(2026),
    );
    for (final type in [null, 'Book', 'Document', 'Essay']) {
      expect(
        chapterBookSource(content(type, 23), {'book_source': sourceJson}),
        isNull,
      );
    }
    expect(
      chapterBookSource(content('Book Chapter', 24), {
        'book_source': sourceJson,
      }),
      isNull,
    );
    expect(
      chapterBookSource(content('Book Chapter', 23), {
        'book_source': sourceJson,
      })!.bookId,
      23,
    );
  });

  test('heading edits and AppFlowy serialization preserve the reference', () {
    final heading = Node(
      type: 'heading',
      attributes: {
        'level': 2,
        'delta': [
          {'insert': 'Old heading'},
        ],
        'book_source': sourceJson,
      },
    );
    heading.updateAttributes({
      'delta': [
        {'insert': 'Renamed heading'},
      ],
    });
    final restored = Node.fromJson(heading.toJson());
    expect(restored.attributes['book_source'], sourceJson);
    expect(restored.delta!.toPlainText(), 'Renamed heading');
  });

  test(
    'adapter handles quote, anchor, fallback, ambiguity and resource scoping',
    () async {
      final book = await EpubReader.readBook(sampleEpub());
      final quote = BookSource.fromJson(sourceJson)!;
      expect(resolveEpubSource(book, quote).block, 4);
      expect(
        resolveEpubSource(
          book,
          BookSource.fromJson({
            ...sourceJson,
            'fragment': 'target',
            'quote': null,
          })!,
        ).block,
        4,
      );
      expect(
        resolveEpubSource(
          book,
          BookSource.fromJson({...sourceJson, 'fragment': 'missing'})!,
        ).block,
        4,
      );
      expect(
        () => resolveEpubSource(
          book,
          BookSource.fromJson({...sourceJson, 'resource': 'one.xhtml'})!,
        ),
        throwsStateError,
      );
      book.Chapters![1].HtmlContent =
          '<html><body><p>Target paragraph.</p><p>Target paragraph.</p></body></html>';
      expect(() => resolveEpubSource(book, quote), throwsStateError);
      book.Chapters![1].HtmlContent =
          '<html><body><p>Before Target paragraph. After</p><p>Different Target paragraph.</p></body></html>';
      final contextual = BookSource.fromJson({
        ...sourceJson,
        'quote': {
          'exact': 'Target paragraph.',
          'prefix': 'Before',
          'suffix': 'After',
        },
      })!;
      expect(resolveEpubSource(book, contextual).block, 3);
    },
  );

  final realPath = Platform.environment['NX_EPUB_TEST_PATH'];
  test(
    'three real source references resolve to the verified passages',
    () async {
      final book = await loadLocalEpub(realPath!);
      for (final pair in {
        'Netflix Cracks the Code': 161,
        'Why do Scale Economies result in Power?': 178,
        'Beyond fixed costs, Scale Economies emerge from other sources': 204,
      }.entries) {
        final source = BookSource.fromJson({
          ...sourceJson,
          'resource': 'OEBPS/chap01.html',
          'quote': {'exact': pair.key},
        })!;
        expect(resolveEpubSource(book, source).block, pair.value);
      }
    },
    skip: realPath == null,
  );
}
