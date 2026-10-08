import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Bounded, local-only metadata journal. Never records audio, credentials or URLs.
/// A serialized asynchronous writer cannot block BLE delivery or throw into it.
class NecklaceDiagnostics {
  NecklaceDiagnostics(
      {required this.directory,
      this.maxBytes = 1024 * 1024,
      this.maxPending = 256});

  static final instance = NecklaceDiagnostics(
      directory: () async => Directory(
          '${(await getApplicationDocumentsDirectory()).path}/diagnostics'));
  final Future<Directory> Function() directory;
  final int maxBytes;
  final int maxPending;
  Future<void> _tail = Future.value();
  int _pending = 0;
  int _dropped = 0;
  File? _file;

  void record(String event, [Map<String, Object?> fields = const {}]) {
    if (_pending >= maxPending) {
      _dropped++;
      return;
    }
    // Encode before scheduling so mutable caller data cannot change the record.
    final line = '${jsonEncode({
          'time': DateTime.now().toUtc().toIso8601String(),
          'event': event,
          ...fields,
          if (_dropped > 0) 'dropped': _dropped
        })}\n';
    _dropped = 0;
    _pending++;
    _tail = _tail.then((_) async {
      try {
        final dir = await directory();
        await dir.create(recursive: true);
        final file = _file ??= File('${dir.path}/necklace.jsonl');
        if (await file.exists() &&
            await file.length() + utf8.encode(line).length > maxBytes) {
          final previous = File('${dir.path}/necklace.previous.jsonl');
          if (await previous.exists()) await previous.delete();
          await file.rename(previous.path);
        }
        await file.writeAsString(line, mode: FileMode.append, flush: true);
      } catch (_) {
        // Diagnostics must never break recording; retry on the next event.
        _dropped++;
      } finally {
        _pending--;
      }
    });
  }

  Future<void> flush() => _tail;
}
