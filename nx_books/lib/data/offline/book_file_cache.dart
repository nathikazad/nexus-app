import 'package:nx_offline/nx_offline.dart' show AttachmentQueue;
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:nx_books/domain/book/book.dart';
import 'package:nx_books/domain/book/book_file_report.dart';
import 'package:nx_books/domain/book/download_report.dart';
import 'package:nx_offline/nx_offline_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class BookFileCache {
  BookFileCache({
    required this.accountKey,
    required this.origin,
    required this.client,
    required this.files,
    this.reportStore,
    this.onReportChanged,
  });

  static const int maximumBytes = 500 * 1024 * 1024;

  final String accountKey;
  final Uri origin;
  final http.Client client;
  final BinaryContentFiles files;
  final BookFileReportStore? reportStore;
  final void Function()? onReportChanged;

  String _key(int id) => 'nx_books.offline.$accountKey.book_file.$id';

  final _queue = AttachmentQueue();
  Future<String> openPath(NxBook book) => _queue.run(
    '${book.id}:${book.bookLink}:${book.bookFileHash}',
    () => _ensure(book),
    foreground: true,
  );
  Future<void> close() => _queue.close();

  Future<void> synchronize(List<NxBook> books) async {
    final linked = [
      for (final book in books)
        if (book.bookLink.isNotEmpty) book,
    ];
    final failures = <String>[];
    var verified = 0;
    await _report(DownloadPhase.downloading, linked.length, verified, failures);
    await Future.wait(
      linked.map((book) async {
        try {
          await _queue.run(
            '${book.id}:${book.bookLink}:${book.bookFileHash}',
            () => _ensure(book),
          );
          verified++;
        } catch (_) {
          failures.add('${book.id}: ${book.title}');
        }
        await _report(
          DownloadPhase.downloading,
          linked.length,
          verified,
          failures,
        );
      }),
    );
    await _report(
      failures.isEmpty ? DownloadPhase.complete : DownloadPhase.incomplete,
      linked.length,
      verified,
      failures,
    );
    if (failures.isNotEmpty) {
      throw StateError('${failures.length} book files could not be verified');
    }
  }

  Future<String> _ensure(NxBook book) async {
    final link = book.bookLink.trim();
    if (link.isEmpty) throw StateError('This book has no attached file');
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_key(book.id));
    if (encoded != null) {
      try {
        final cached = _CachedBookFile.decode(encoded);
        if (cached.link == link &&
            (book.bookFileHash == null ||
                cached.reference.hash == book.bookFileHash) &&
            (book.bookFileSize == null ||
                cached.reference.bytes == book.bookFileSize) &&
            await files.verify(cached.reference)) {
          return files.localPath(cached.reference);
        }
      } catch (_) {
        // Missing, malformed, or corrupt entries are repaired by downloading.
      }
    }

    final uri = _resolveLink(link);
    final request = http.Request('GET', uri)..followRedirects = false;
    final response = await client.send(request);
    if (response.statusCode != 200) {
      await response.stream.drain<void>();
      throw StateError('Book download failed (${response.statusCode})');
    }
    final declaredLength = response.contentLength;
    if (declaredLength != null && declaredLength > maximumBytes) {
      await response.stream.drain<void>();
      throw StateError('Book file exceeds the 500 MB offline limit');
    }
    final extension = _extension(uri);
    var received = 0;
    Stream<List<int>> limited() async* {
      await for (final chunk in response.stream) {
        received += chunk.length;
        if (received > maximumBytes) {
          throw StateError('Book file exceeds the 500 MB offline limit');
        }
        yield chunk;
      }
    }

    final reference = await files.write(
      'book_files',
      '${book.id}',
      extension,
      limited(),
    );
    if ((book.bookFileHash != null && reference.hash != book.bookFileHash) ||
        (book.bookFileSize != null && reference.bytes != book.bookFileSize)) {
      throw StateError('Downloaded book does not match the server checksum');
    }
    final saved = await preferences.setString(
      _key(book.id),
      _CachedBookFile(link, reference).encode(),
    );
    if (!saved) throw StateError('Could not remember the offline book file');
    return files.localPath(reference);
  }

  Uri _resolveLink(String link) {
    final parsed = Uri.tryParse(link);
    if (parsed == null) throw const FormatException('Invalid book file link');
    final uri = origin.resolveUri(parsed);
    if ((uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.scheme != origin.scheme ||
        uri.host != origin.host ||
        uri.port != origin.port ||
        !uri.path.startsWith('/books/')) {
      throw const FormatException('Book file link is outside Nexus');
    }
    return uri;
  }

  String _extension(Uri uri) {
    final path = uri.path.toLowerCase();
    if (path.endsWith('.pdf')) return '.pdf';
    if (path.endsWith('.epub')) return '.epub';
    throw const FormatException('Book file must be PDF or EPUB');
  }

  Future<void> _report(
    DownloadPhase phase,
    int total,
    int verified,
    List<String> failed,
  ) async {
    await reportStore?.save(
      BookFileReport(
        phase: phase,
        total: total,
        verified: verified,
        failed: List.unmodifiable(failed),
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    onReportChanged?.call();
  }
}

final class _CachedBookFile {
  const _CachedBookFile(this.link, this.reference);

  final String link;
  final BinaryContentReference reference;

  String encode() => '$link\n${reference.encode()}';

  factory _CachedBookFile.decode(String value) {
    final separator = value.indexOf('\n');
    if (separator < 1) throw const FormatException('Invalid cached book file');
    return _CachedBookFile(
      value.substring(0, separator),
      BinaryContentReference.decode(value.substring(separator + 1)),
    );
  }
}
