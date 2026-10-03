import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../devices/necklace_identity.dart';
import '../file_transfer/protocol.dart';
import '../file_transfer/relay.dart';
import '../socket/bg_socket_client.dart';
import 'necklace_command_handler.dart';
import 'necklace_device_port.dart';
import 'necklace_relay.dart';

/// Account/device selection belongs to the host. Authentication and forwarding
/// are identical on the phone, desktop simulator and desktop Bluetooth runner.
class PhoneRelaySession {
  const PhoneRelaySession(
      {required this.httpUrl,
      required this.socketUrl,
      required this.deviceId,
      required this.exchangeIdentity,
      required this.isCurrent,
      this.domainId});
  final String httpUrl, socketUrl, deviceId;
  final IdentityExchange exchangeIdentity;
  final bool Function() isCurrent;
  final int? domainId;
}

/// Owns a single device/server session. Never stores file bytes on the phone.
/// The host feeds actual notifications and owns physical connection/startup.
class PhoneRelayRuntime {
  PhoneRelayRuntime(
      {required this.device,
      required this.socket,
      void Function(String, Map<String, dynamic>)? emit})
      : _emit = emit ?? _ignore {
    if (device is! NecklaceFilePort) {
      throw ArgumentError('Device must support the file characteristic');
    }
    _audio = NecklaceRelay(
        device: device,
        socketClient: socket,
        emit: _emit,
        currentGeneration: () => _generation);
    _commands = NecklaceCommandHandler(device);
    _attachCallbacks();
  }
  static void _ignore(String _, Map<String, dynamic> __) {}
  final NecklaceDevicePort device;
  final SocketClient socket;
  final void Function(String, Map<String, dynamic>) _emit;
  late final NecklaceRelay _audio;
  late final NecklaceCommandHandler _commands;
  NecklaceDeviceAuth? _auth;
  FileRelay? _files;
  PhoneRelaySession? _session;
  int _generation = 0;
  bool _closed = false, _retired = false;
  Future<void> _fileWrites = Future.value();
  Future<void> get drained => _fileWrites;

  void _attachCallbacks() {
    final generation = _generation;
    _audio.attachSocket();
    final downlink = socket.onPacketFromServer!;
    socket.onPacketFromServer = (bytes) async {
      if (!_closed &&
          !_retired &&
          generation == _generation &&
          (_session == null || _session!.isCurrent())) await downlink(bytes);
    };
    socket.onDeviceRequest = (id, action, params) {
      if (generation != _generation) {
        return Future.value(
            jsonEncode({'success': false, 'error': 'Obsolete device session'}));
      }
      return execute(id, action, params);
    };
  }

  Future<String?> execute(int id, String action, Map<String, dynamic> params) {
    if (_closed || _retired || (_session != null && !_session!.isCurrent())) {
      return Future.value(
          jsonEncode({'success': false, 'error': 'Device session retired'}));
    }
    return _commands.handle(id, action, params);
  }

  void onNotification(String channel, Uint8List bytes) {
    if (_closed || _retired || (_session != null && !_session!.isCurrent()))
      return;
    if (channel == 'audio') _audio.onAudioPacket(bytes);
    if (channel != 'file') return;
    // Legacy image/telemetry packets cannot bypass durable server ingestion.
    if (bytes.length < 4 || bytes[0] != 0 || bytes[1] != 0x84) return;
    try {
      final files = _files;
      if (files == null) return;
      if (!files.fromDevice(bytes)) {
        final session = _session;
        if (session != null && session.isCurrent()) {
          unawaited(socket
              .ensureConnected(reason: 'file retry')
              .catchError((Object error) {
            _emit('relay.error', {'error': error.toString()});
            return false;
          }));
        }
      }
    } catch (error) {
      _emit('relay.error', {'error': error.toString()});
    }
  }

  Future<bool> connect(PhoneRelaySession session) async {
    if (_closed) throw StateError('Relay is closed');
    if (session.domainId != null && session.domainId! <= 0) {
      throw ArgumentError('Domain ID must be positive');
    }
    final retiring = disconnect();
    final generation = _generation;
    await retiring;
    if (generation != _generation || _closed || !session.isCurrent())
      return false;
    _retired = false;
    _session = session;
    bool current() =>
        generation == _generation && !_closed && session.isCurrent();
    final auth = NecklaceDeviceAuth(
        baseUrl: session.httpUrl,
        deviceId: session.deviceId,
        exchange: session.exchangeIdentity,
        isCurrent: current);
    _auth = auth;
    final files = FileRelay(
        sendToServer: socket.sendFilePacket,
        sendToDevice: (bytes) async {
          if (!current()) return;
          if (!await (device as NecklaceFilePort).writeFileRx(bytes)) {
            throw StateError('File acknowledgment write failed');
          }
        });
    _files = files;
    _attachCallbacks();
    socket.onFilePacket = (bytes) {
      if (!current()) return Future.value();
      final write = files.fromServer(bytes);
      // Keep failures visible to the transport; draining remains usable after one failure.
      _fileWrites = write.catchError((Object error) {
        _emit('relay.error', {'error': error.toString()});
      });
      return write;
    };
    try {
      final connected = await socket.connect(session.socketUrl,
          headers: {
            'X-Client-Id': 'necklace',
            if (session.domainId != null) 'X-Domain-Id': '${session.domainId}',
          },
          authHeaders: auth.headers);
      if (!current()) return false;
      if (!connected) {
        await disconnect();
        return false;
      }
      if (!await (device as NecklaceFilePort)
          .writeFileRx(Uint8List.fromList(fileHello))) {
        throw StateError('File protocol negotiation failed');
      }
      return true;
    } catch (_) {
      if (current()) await disconnect();
      rethrow;
    }
  }

  Future<void> disconnect() async {
    ++_generation;
    _retired = true;
    _session = null;
    final auth = _auth, files = _files;
    _auth = null;
    _files = null;
    socket.onFilePacket = null;
    auth?.close();
    final closing = socket.disconnect();
    await files?.close();
    await closing;
  }

  Future<void> close() async {
    _closed = true;
    await disconnect();
    socket.onPacketFromServer = null;
    socket.onDeviceRequest = null;
    socket.onAudioReceptionSummary = null;
  }
}
