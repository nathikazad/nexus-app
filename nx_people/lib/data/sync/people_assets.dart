import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cross_file/cross_file.dart';
import 'package:http/http.dart' as http;
import 'package:nx_offline/nx_offline_storage.dart';
import 'package:nx_people/data/sync/people_data_repository.dart';
import 'package:nx_people/data/sync/people_store.dart';
import 'package:nx_people/data/sync/people_transport.dart';

/// Stage bytes before recording a local URL. Upload acknowledgements survive
/// restarts; the server also deduplicates by content if an acknowledgement is lost.
class PeopleAssets {
  PeopleAssets(this.remote, this.domain, {this.store, this.files});
  final PeopleTransport remote;
  final int domain;
  final PeopleStore? store;
  final BinaryContentFiles? files;
  Future<void>? _downloads;
  bool _closed = false;
  Future<void> close() async {
    _closed = true;
    await _downloads;
  }

  static const maxBytes = 20 * 1024 * 1024;

  Future<String> stage(List<int> bytes, String filename) async {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw ArgumentError('File must be between 1 byte and 20 MB');
    }
    if (store == null) return (await _upload(bytes, filename))['url'] as String;
    final key = peopleOperationId();
    final reference = await files!.write(
      'people-assets',
      key,
      '.bin',
      Stream.value(bytes),
    );
    await store!.library.saveRemote(
      'people_asset_files',
      'people-local:$key',
      jsonEncode({'reference': reference.encode(), 'filename': filename}),
    );
    return 'people-local:$key';
  }

  Future<Map<String, dynamic>> _upload(List<int> bytes, String filename) async {
    final request =
        http.MultipartRequest(
            'POST',
            remote.reads.origin.resolve('/nx_people/assets'),
          )
          ..fields['domain_id'] = '$domain'
          ..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: filename),
          );
    final response = await http.Response.fromStream(
      await remote.reads.client
          .send(request)
          .timeout(const Duration(seconds: 60)),
    );
    if (response.statusCode != 200) {
      throw StateError('File upload failed (${response.statusCode})');
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<String> uploadLocal(String url) async {
    final encoded = await store!.library.read('people_asset_files', url);
    if (encoded == null) throw StateError('Local attachment is missing');
    final saved = Map<String, dynamic>.from(jsonDecode(encoded) as Map);
    if (saved['url'] case final String uploaded) return uploaded;
    final bytes = await read(url);
    final result = await _upload(bytes, saved['filename'] as String);
    await store!.library.saveRemote(
      'people_asset_files',
      url,
      jsonEncode({...saved, ...result}),
    );
    await store!.library.saveRemote(
      'people_asset_files',
      result['url'] as String,
      jsonEncode({...saved, ...result}),
    );
    return result['url'] as String;
  }

  Future<dynamic> resolve(dynamic value) async {
    if (value is String && value.startsWith('people-local:')) {
      return uploadLocal(value);
    }
    if (value is List) return Future.wait(value.map(resolve));
    if (value is Map) {
      return {for (final key in value.keys) key: await resolve(value[key])};
    }
    return value;
  }

  Future<Uint8List> read(String url) async {
    final input = Uri.tryParse(url);
    if (input?.hasAuthority == true &&
        input?.origin == remote.reads.origin.origin) {
      url = '${input!.path}${input.hasQuery ? '?${input.query}' : ''}';
    }
    final encoded = await store?.library.read('people_asset_files', url);
    if (encoded != null && files != null) {
      final reference = BinaryContentReference.decode(
        jsonDecode(encoded)['reference'] as String,
      );
      if (await files!.verify(reference)) {
        return XFile(await files!.localPath(reference)).readAsBytes();
      }
      if (url.startsWith('people-local:')) {
        throw StateError('Local attachment is damaged');
      }
    }
    final uri = remote.reads.origin.resolve(url);
    // Never send the authenticated client to an external host supplied in data.
    if (uri.origin != remote.reads.origin.origin ||
        !{'http', 'https'}.contains(uri.scheme)) {
      throw StateError('Attachment is not hosted by this Nexus server');
    }
    final request = http.Request('GET', uri)..followRedirects = false;
    final response = await remote.reads.client
        .send(request)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200 ||
        (response.contentLength ?? 0) > maxBytes) {
      await response.stream.drain<void>();
      throw StateError('Attachment unavailable (${response.statusCode})');
    }
    final result = BytesBuilder(copy: false);
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 30),
    )) {
      if (result.length + chunk.length > maxBytes) {
        throw StateError('Attachment exceeds 20 MB');
      }
      result.add(chunk);
    }
    final bytes = result.takeBytes();
    if (store != null && files != null) {
      final reference = await files!.write(
        'people-assets',
        url,
        '.bin',
        Stream.value(bytes),
      );
      await store!.library.saveRemote(
        'people_asset_files',
        url,
        jsonEncode({'reference': reference.encode()}),
      );
    }
    return bytes;
  }

  Future<void> synchronize(List<Map<String, dynamic>> rows) {
    if (_closed) return Future.value();
    return _downloads ??= _synchronize(
      rows,
    ).whenComplete(() => _downloads = null);
  }

  Future<void> _synchronize(List<Map<String, dynamic>> rows) async {
    final urls = <String>{};
    void visit(dynamic value) {
      if (value is Map) {
        for (final entry in value.entries) {
          if ({'image_url', 'url', 'avatar_url'}.contains(entry.key) &&
              entry.value is String &&
              (entry.value as String).startsWith('/')) {
            urls.add(entry.value as String);
          } else {
            visit(entry.value);
          }
        }
      } else if (value is List) {
        for (final child in value) {
          visit(child);
        }
      }
    }

    visit(rows);
    for (final url in urls) {
      if (_closed) break;
      try {
        await read(url);
      } catch (_) {
        /* Metadata stays usable; retry files on next sync. */
      }
    }
  }
}
