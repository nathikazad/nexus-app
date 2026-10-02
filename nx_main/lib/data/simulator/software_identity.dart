import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../devices/necklace_identity.dart';

/// Crypto/storage stand-in for the board; HTTP authentication remains production code.
class SoftwareIdentity {
  SoftwareIdentity._(this.process, this.lines);
  final Process process;
  final StreamIterator<String> lines;
  Future<void> _tail = Future.value();
  static Future<SoftwareIdentity> start(
      String python, String script, String state) async {
    final process = await Process.start(python, [script, state]);
    process.stderr.transform(utf8.decoder).listen(stderr.write);
    return SoftwareIdentity._(
        process,
        StreamIterator(process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())));
  }

  Future<Uint8List> exchange(Uint8List bytes) {
    final result = _tail.then((_) async {
      process.stdin.writeln(jsonEncode({'hex': identityHex(bytes)}));
      await process.stdin.flush();
      if (!await lines.moveNext().timeout(const Duration(seconds: 10)))
        throw StateError('Software identity exited');
      final reply = jsonDecode(lines.current) as Map<String, dynamic>;
      if (reply.containsKey('error'))
        throw StateError('Identity operation failed: ${reply['error']}');
      final hex = reply['hex'] as String;
      return hex.isEmpty ? Uint8List(0) : identityBytes(hex);
    });
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> close() async {
    await _tail;
    await process.stdin.close();
    try {
      await process.exitCode.timeout(const Duration(seconds: 5));
    } finally {
      process.kill();
      await lines.cancel();
    }
  }
}
