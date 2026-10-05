import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../devices/necklace_identity.dart';
import '../file_transfer/protocol.dart';
import '../necklace/phone_relay_runtime.dart';
import '../socket/bg_socket_client.dart';
import 'firmware_process.dart';

/// Loopback-only UI. PCM enters the simulated microphone, never the server socket.
class SimulatorPanel {
  SimulatorPanel(this.firmware, this.relay, this.assets, this.artifacts);
  final FirmwareProcess firmware;
  final PhoneRelayRuntime relay;
  SocketClient get socket => relay.socket;
  final Directory assets, artifacts;
  bool cameraEnabled = false;
  int cameraRequest = 0, photoVersion = 0;
  Completer<void>? _frameReady;
  Uint8List? _photo;
  FileManifest? _preview;
  int? _previewHandle;
  final List<int> _previewBytes = [];

  /// Bounded UI preview only: no storage, ACKs or upload policy live here.
  void onFilePacket(Uint8List bytes) {
    try {
      final packet = FilePacket.parse(bytes);
      if (packet.op == FileOp.open) {
        final manifest = packet.manifest();
        if (manifest.kind != FileKind.photo) {
          _preview = null;
          _previewHandle = null;
          _previewBytes.clear();
          return;
        }
        if (_preview?.id != manifest.id) {
          _previewBytes.clear();
          _previewHandle = null;
        }
        _preview = manifest;
      }
      final manifest = _preview;
      if (manifest == null) return;
      if (packet.op == FileOp.data &&
          (_previewHandle == null || _previewHandle == packet.handle) &&
          packet.offset == _previewBytes.length &&
          _previewBytes.length + bytes.length - fileDataHeader <= 512 * 1024) {
        _previewHandle = packet.handle;
        _previewBytes.addAll(bytes.sublist(fileDataHeader));
      }
      if (packet.op == FileOp.close &&
          packet.handle == _previewHandle &&
          _previewBytes.length == packet.offset &&
          crc32(_previewBytes) == packet.checksum) {
        _photo = Uint8List.fromList(_previewBytes);
        photoVersion++;
        _preview = null;
        _previewBytes.clear();
        event(
            'Photo received from necklace: ${manifest.name} (${_photo!.length} bytes)');
      }
    } on FormatException {
      // Malformed preview packets cannot affect the authoritative relay.
    }
  }

  Future<void> _freshFrame() async {
    await firmware.request('observe');
    if (firmware.state['camera_active'] != 0)
      throw StateError('Camera is already capturing');
    if (!cameraEnabled)
      throw StateError('Enable webcam in the phone panel first');
    if (_frameReady != null) throw StateError('Camera request already pending');
    final pending = Completer<void>();
    _frameReady = pending;
    cameraRequest++;
    try {
      await pending.future.timeout(const Duration(seconds: 10));
    } finally {
      _frameReady = null;
    }
  }

  final String sessionId = DateTime.now().microsecondsSinceEpoch.toString();
  final List<Map<String, Object?>> events = [];
  final List<int> _speaker = [];
  HttpServer? _server;
  Timer? _watchdog;
  bool stopped = false, held = false, microphone = false;
  DateTime _lastMic = DateTime.now();
  DateTime _lastReconnect = DateTime.fromMillisecondsSinceEpoch(0);
  int _eventId = 0;
  Future<void> _controls = Future.value();
  int get port => _server!.port;
  void event(String text) {
    events.add({
      'id': ++_eventId,
      'text': text,
      'at': DateTime.now().toIso8601String()
    });
    if (events.length > 80) events.removeAt(0);
  }

  Future<void> start(int port) async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    firmware.onSpeaker = (bytes) {
      _speaker.addAll(bytes);
      if (_speaker.length > 64000)
        _speaker.removeRange(0, _speaker.length - 64000);
    };
    final original = socket.onDeviceRequest!;
    socket.onDeviceRequest = (id, action, params) async {
      event('Agent → $action');
      if (action == 'start_record') {
        return jsonEncode({
          'success': false,
          'error':
              'Periodic webcam capture is not supported by this live adapter; request take_photo for a fresh photo.'
        });
      }
      if (action == 'take_photo') {
        try {
          await _freshFrame();
        } catch (error) {
          event('Camera unavailable: $error');
          return jsonEncode({
            'success': false,
            'error':
                'Enable the webcam in the simulator phone panel; capture must complete within 10 seconds.'
          });
        }
      }
      final result = await original(id, action, params);
      event('$action: $result');
      return result;
    };
    _server!.listen(_handle);
    _watchdog = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!socket.isConnected &&
          !stopped &&
          DateTime.now().difference(_lastReconnect).inSeconds >= 5) {
        _lastReconnect = DateTime.now();
        unawaited(socket.ensureConnected(reason: 'simulator_panel').then((ok) {
          if (ok) event('Server connection restored');
        }).catchError((Object _) {}));
      }
      if (microphone && DateTime.now().difference(_lastMic).inSeconds >= 2) {
        microphone = false;
        unawaited(_control(() async {
          await _release();
          await firmware
              .request('call hardware.esp.simulated_microphone.stream_pcm16');
          event('Microphone disconnected; button released');
        }).catchError((Object _) {}));
      }
    });
    event('Connected to server through the real phone relay');
  }

  Future<void> _control(Future<void> Function() action) {
    final next = _controls.then((_) => action());
    _controls = next.catchError((Object _) {});
    return next;
  }

  Future<void> _release() async {
    if (held) {
      await firmware.request('input button 0');
      held = false;
      event('Button released → finish voice turn');
    }
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      final expected = '127.0.0.1:$port';
      final origin = request.headers.value('origin');
      if (request.headers.value('host') != expected ||
          (origin != null && origin != 'http://$expected')) {
        request.response.statusCode = 403;
        return;
      }
      request.response.headers.set('Cache-Control', 'no-store');
      final path = request.uri.path;
      if (request.method == 'GET' &&
          {'/', '/panel.js', '/mic-worklet.js'}.contains(path)) {
        final filename = path == '/' ? 'index.html' : path.substring(1);
        request.response.headers.contentType = ContentType(
            path == '/' ? 'text' : 'application',
            path == '/' ? 'html' : 'javascript',
            charset: 'utf-8');
        request.response
            .add(await File('${assets.path}/$filename').readAsBytes());
      } else if (request.method == 'GET' && path == '/state') {
        await firmware.request('observe');
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          ...firmware.state,
          'session_id': sessionId,
          'relay_connected': socket.isConnected,
          'held': held,
          'camera_enabled': cameraEnabled,
          'camera_request': _frameReady == null ? 0 : cameraRequest,
          'photo_version': photoVersion,
          'microphone': microphone,
          'events': events,
          'speaker_pcm': base64Encode(_speaker)
        }));
        _speaker.clear();
      } else if (request.method == 'GET' && path == '/photo.jpg') {
        if (_photo == null) {
          request.response.statusCode = 404;
        } else {
          request.response.headers.contentType = ContentType('image', 'jpeg');
          request.response.add(_photo!);
        }
      } else if (request.method == 'POST' && path == '/camera/frame') {
        final id = int.tryParse(request.uri.queryParameters['id'] ?? '');
        final pending = _frameReady;
        if (pending == null || id != cameraRequest || !cameraEnabled) {
          request.response.statusCode = 409;
          return;
        }
        final builder = BytesBuilder();
        await for (final bytes in request) {
          if (builder.length + bytes.length > 32000)
            throw const FormatException('JPEG too large');
          builder.add(bytes);
        }
        final jpeg = builder.takeBytes();
        if (jpeg.length < 4 ||
            jpeg[0] != 255 ||
            jpeg[1] != 216 ||
            jpeg[jpeg.length - 2] != 255 ||
            jpeg.last != 217) {
          throw const FormatException('JPEG required');
        }
        if (!identical(_frameReady, pending) || !cameraEnabled) {
          request.response.statusCode = 409;
          return;
        }
        final file = File('${artifacts.path}/webcam-input.jpg');
        await file.writeAsBytes(jpeg, flush: true);
        await firmware.request(
            'call hardware.esp.simulated_camera.load_jpeg ${file.path}');
        if (!pending.isCompleted) pending.complete();
      } else if (request.method == 'POST' && path == '/take_photo') {
        // The capture wait stays outside _controls so incoming webcam frames
        // and microphone operations cannot deadlock behind it.
        await _freshFrame();
        final result = await relay.execute(0, 'take_photo', {});
        event('Phone → take_photo: $result');
        request.response.headers.contentType = ContentType.json;
        request.response.write(result);
      } else if (request.method == 'POST' && path == '/pcm') {
        final builder = BytesBuilder();
        await for (final bytes in request) {
          if (builder.length + bytes.length > 32000)
            throw const FormatException('PCM batch too large');
          builder.add(bytes);
        }
        final pcm = builder.takeBytes();
        if (pcm.length.isOdd) throw const FormatException('PCM16 required');
        await _control(() async {
          if (!microphone) throw StateError('Enable microphone first');
          _lastMic = DateTime.now();
          await firmware.request(
              'call hardware.esp.simulated_microphone.stream_pcm16 ${identityHex(pcm)}');
        });
      } else if (request.method == 'POST') {
        await _control(() async {
          if (path == '/camera/on') {
            cameraEnabled = true;
            event('Computer webcam enabled as necklace camera');
          } else if (path == '/camera/off') {
            cameraEnabled = false;
            final pending = _frameReady;
            if (pending != null && !pending.isCompleted)
              pending.completeError(StateError('Webcam disabled'));
            event('Webcam off');
          } else if (path == '/microphone/on') {
            await firmware
                .request('call hardware.esp.simulated_microphone.stream_pcm16');
            microphone = true;
            _lastMic = DateTime.now();
            event('Live microphone enabled');
          } else if (path == '/microphone/off') {
            await _release();
            microphone = false;
            await firmware
                .request('call hardware.esp.simulated_microphone.stream_pcm16');
            event('Microphone off');
          } else if (path == '/press') {
            await firmware.request('input button 1');
            held = true;
            event('Button held → start voice turn');
          } else if (path == '/release') {
            await _release();
          } else if (path == '/stop') {
            await _release();
            stopped = true;
          } else if ({'/audio.start', '/audio.new', '/audio.stop'}
              .contains(path)) {
            final result = await relay.execute(0, path.substring(1), {});
            event('Direct control ${path.substring(1)}: $result');
          } else {
            request.response.statusCode = 404;
          }
        });
      } else {
        request.response.statusCode = 404;
      }
    } catch (error) {
      request.response.statusCode = error is FormatException ? 400 : 503;
      request.response.write('Simulator request failed');
    } finally {
      await request.response.close();
    }
  }

  Future<void> close() async {
    stopped = true;
    _watchdog?.cancel();
    await _server?.close(force: true);
    await _controls;
    firmware.onSpeaker = null;
  }
}
