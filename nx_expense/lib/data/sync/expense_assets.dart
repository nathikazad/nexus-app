import 'dart:async';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:nx_offline/nx_offline.dart' show AttachmentQueue;
import 'package:nx_offline/nx_offline_storage.dart';

/// Same queue, immutable binary storage and checksum validation used by Books.
/// A null library/files pair selects memory-only browser downloads.
class ExpenseAssets {
  ExpenseAssets({
    required this.client,
    required this.origin,
    this.library,
    this.files,
  });
  final http.Client client;
  final Uri origin;
  final FileLibrary? library;
  final BinaryContentFiles? files;
  final _queue = AttachmentQueue();
  Future<void>? _closing;
  Future<void> close() => _closing ??= _queue.close();
  static const maxBytes = 20 * 1024 * 1024;

  Future<Uint8List> read(
    String filename, {
    String? hash,
    bool foreground = true,
  }) => _queue.run(
    '$filename:$hash',
    () => _read(filename, hash),
    foreground: foreground,
  );

  Future<Uint8List> _read(String filename, String? hash) async {
    if (!RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(filename) ||
        filename.contains('..')) {
      throw const FormatException('Invalid receipt filename');
    }
    final key = '$filename:${hash ?? "legacy"}';
    final saved = await library?.read('receipt_files', key);
    if (saved != null && files != null) {
      try {
        final reference = BinaryContentReference.decode(saved);
        if ((hash == null || reference.hash == hash) &&
            await files!.verify(reference)) {
          return XFile(await files!.localPath(reference)).readAsBytes();
        }
      } catch (_) {
        /* Repair missing or damaged files from the server. */
      }
    }
    final request = http.Request(
      'GET',
      origin
          .resolve('/images/file')
          .replace(queryParameters: {'name': filename}),
    )..followRedirects = false;
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200 ||
        (response.contentLength ?? 0) > maxBytes) {
      await response.stream.drain<void>();
      throw StateError('Could not download receipt (${response.statusCode})');
    }
    final data = BytesBuilder(copy: false);
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 30),
    )) {
      if (data.length + chunk.length > maxBytes) {
        throw StateError('Receipt exceeds 20 MB');
      }
      data.add(chunk);
    }
    final bytes = data.takeBytes();
    if (hash != null && sha256.convert(bytes).toString() != hash) {
      throw StateError('Receipt checksum does not match the server');
    }
    if (library != null && files != null) {
      final ref = await files!.write(
        'receipts',
        filename,
        '.${filename.split('.').last}',
        Stream.value(bytes),
      );
      await library!.saveRemote('receipt_files', key, ref.encode());
    }
    return bytes;
  }

  Future<void> synchronize(List<Map<String, dynamic>> rows) async {
    final assets = <String, String?>{};
    for (final row in rows) {
      if (row['kind'] != 'event' ||
          row['source'] != 'expense_app' ||
          row['event_type'] != 'image') {
        continue;
      }
      final payload = row['payload'] as Map? ?? {};
      final filename = (payload['path']?.toString() ?? '')
          .replaceAll('\\', '/')
          .split('/')
          .last;
      if (filename.isNotEmpty) assets[filename] = payload['sha256'] as String?;
    }
    await Future.wait(
      assets.entries.map((e) async {
        await read(e.key, hash: e.value, foreground: false);
      }),
    );
  }
}
