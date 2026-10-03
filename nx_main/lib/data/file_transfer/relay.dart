import 'dart:typed_data';
import 'protocol.dart';

/// No disk or offline queue. Backend RESUME grants an eight-packet window;
/// only a backend COMMIT can authorize deletion. SD retains disconnected work.
class FileRelay {
  FileRelay({required this.sendToServer, required this.sendToDevice});
  final bool Function(Uint8List) sendToServer;
  final Future<void> Function(Uint8List) sendToDevice;
  bool _closed = false;
  Future<void> _replies = Future.value();

  bool fromDevice(Uint8List bytes) {
    if (_closed) return false;
    final p = FilePacket.parse(bytes);
    if (![FileOp.begin, FileOp.chunk, FileOp.finish].contains(p.op)) {
      throw const FormatException('Unexpected device file operation');
    }
    return sendToServer(bytes);
  }

  Future<void> fromServer(Uint8List bytes) {
    final p = FilePacket.parse(bytes);
    if (![FileOp.resume, FileOp.commit].contains(p.op)) {
      throw const FormatException('Unexpected server file operation');
    }
    final copy = Uint8List.fromList(bytes);
    final next = _replies.then((_) async {
      if (!_closed) await sendToDevice(copy);
    });
    _replies = next.catchError((Object _) {});
    return next;
  }

  Future<void> close() async {
    _closed = true;
    await _replies;
  }
}
