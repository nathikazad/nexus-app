import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../necklace/necklace_device_port.dart';
import '../devices/necklace_identity.dart';

/// A single serialized IPC channel to the real application simulator.
class FirmwareProcess implements NecklaceDevicePort, NecklaceAudioControlPort {
  FirmwareProcess._(this.process, this._lines);
  final Process process;
  final StreamIterator<String> _lines;
  Future<void> _tail = Future.value();
  Map<String, dynamic> state = {};
  void Function(String channel, Uint8List bytes)? onNotification;
  void Function(Uint8List pcm)? onSpeaker;
  Object? failure;
  bool _closed = false;

  static Future<FirmwareProcess> start(String binary, String output) async {
    final process = await Process.start(binary, ['-', output, '0']);
    process.stderr.transform(utf8.decoder).listen(stderr.write);
    final self = FirmwareProcess._(
        process,
        StreamIterator(process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())));
    try {
      await self._receive();
      return self;
    } catch (_) {
      process.kill();
      await self._lines.cancel();
      rethrow;
    }
  }

  Future<void> _receive() async {
    if (!await _lines.moveNext().timeout(const Duration(seconds: 10))) {
      throw StateError('Firmware simulator exited');
    }
    final reply = jsonDecode(_lines.current) as Map<String, dynamic>;
    if (reply['ok'] != true) throw StateError('Firmware rejected request');
    state = Map<String, dynamic>.from(reply['state'] as Map);
    final pcm = reply['speaker_pcm'] as String? ?? '';
    if (pcm.isNotEmpty) onSpeaker?.call(identityBytes(pcm));
    for (final event in (reply['notifications'] as List? ?? [])) {
      onNotification?.call(
          event['channel'] as String, identityBytes(event['hex'] as String));
    }
  }

  Future<void> request(String command) {
    if (_closed) return Future.error(StateError('Simulator is closed'));
    if (command.contains('\n') || command.contains('\r'))
      return Future.error(ArgumentError('Embedded newline'));
    final next = _tail.then((_) async {
      if (failure != null) throw StateError('Simulator IPC failed');
      process.stdin.writeln(command);
      await process.stdin.flush();
      await _receive();
    });
    _tail = next.catchError((Object e) {
      failure = e;
    });
    return next;
  }

  Future<void> write(String characteristic, Uint8List bytes) => request(
      'call external.simulated_phone.write_$characteristic ${identityHex(bytes)}');
  @override
  Future<void> sendAudio(Uint8List bytes) => write('audio', bytes);
  @override
  Future<bool> writeCamera(Uint8List bytes) async {
    if (bytes.isEmpty || bytes[0] == 5)
      return false; // Cold reset is not modeled.
    await write('camera', bytes);
    return true;
  }

  @override
  Future<bool> writeBackgroundAudio(int operation) async {
    if (operation < 0 || operation > 2) return false;
    await write('background', Uint8List.fromList([operation]));
    return true;
  }

  @override
  Future<(bool, int)?> readCameraStatus() async {
    await request('observe');
    return (state['camera_auto'] == 1, state['camera_period'] as int);
  }

  @override
  Future<Uint8List?> readBattery() async =>
      null; // No invented real battery reading.
  @override
  Future<bool> writeHaptic(int effectId) async => false;

  Future<void> close() async {
    if (_closed) return;
    try {
      if (failure == null) await request('quit');
      _closed = true;
      await process.stdin.close();
      await process.exitCode.timeout(const Duration(seconds: 10));
    } finally {
      _closed = true;
      process.kill();
      await _lines.cancel();
    }
  }
}
