import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nexus_voice_assistant/data/file_transfer/protocol.dart';
import 'package:nexus_voice_assistant/data/necklace/phone_relay_runtime.dart';
import 'package:nexus_voice_assistant/data/socket/bg_socket_client.dart';
import 'package:nexus_voice_assistant/data/simulator/software_identity.dart';
import 'package:nexus_voice_assistant/data/simulator/firmware_process.dart';

// Faults wrap the production socket; handshake, encoding and reads remain real.
class FaultSocket extends SocketClient {
  final committed = <String>{};
  final manifests = <String, FileManifest>{};
  bool dropCommit = true, disconnectOnce = true, resumedPartial = false;
  Future<void> recovery = Future.value();
  late Future<void> Function() reconnect;
  @override
  bool sendFilePacket(Uint8List bytes) {
    final p = FilePacket.parse(bytes);
    if (p.op == FileOp.begin) manifests[p.id] = p.manifest();
    final sent = super.sendFilePacket(bytes);
    if (sent &&
        disconnectOnce &&
        p.op == FileOp.chunk &&
        manifests[p.id]?.kind == FileKind.telemetry) {
      disconnectOnce = false;
      recovery = disconnect().then((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        await reconnect();
      });
    }
    return sent;
  }

  @override
  set onFilePacket(Future<void> Function(Uint8List)? callback) {
    super.onFilePacket = callback == null
        ? null
        : (bytes) async {
            final p = FilePacket.parse(bytes);
            if (p.op == FileOp.resume &&
                p.offset > 0 &&
                manifests[p.id]?.kind == FileKind.telemetry)
              resumedPartial = true;
            if (p.op == FileOp.commit) {
              committed.add(p.id);
              if (dropCommit) {
                dropCommit = false;
                return;
              }
            }
            await callback(bytes);
          };
  }
}

void main() {
  final binary = Platform.environment['NEXUS_FIRMWARE_SIM'];
  final configPath = Platform.environment['NEXUS_NECKLACE_TEST_CONFIG'];
  test(
      'actual firmware -> stateless phone -> WebSocket -> timeline and model references',
      () async {
    final config = jsonDecode(await File(configPath!).readAsString())
        as Map<String, dynamic>;
    final configDir = File(configPath).parent;
    final identity = await SoftwareIdentity.start(
        Platform.environment['NEXUS_TEST_PYTHON'] ?? 'python3',
        'tool/necklace_sim/identity.py',
        '${configDir.path}/relay-identity.json');
    addTearDown(identity.close);
    final root =
        await Directory('../../tmp/necklace-websocket').createTemp('e2e-');
    final seeds = File('$configPath.next-seed');
    final seed =
        await seeds.exists() ? int.parse(await seeds.readAsString()) : 200000;
    await seeds.writeAsString('${seed + 2}', flush: true);
    var firmware = await FirmwareProcess.start(binary!, '${root.path}/firmware',
        seed: seed);
    final headers = {
      'x-user-id': '${config['necklace']['user_id']}',
      'x-domain-id': '${config['necklace']['domain_id']}'
    };
    final client = http.Client();
    final socket = FaultSocket();
    var relay = PhoneRelayRuntime(device: firmware, socket: socket);
    void attach() {
      firmware.onNotification = relay.onNotification;
    }

    Future<void> connect() async {
      expect(
          await relay.connect(PhoneRelaySession(
            httpUrl: config['http_url'],
            socketUrl: config['websocket_url'],
            deviceId: config['device_id'],
            domainId: config['necklace']['domain_id'],
            exchangeIdentity: identity.exchange,
            isCurrent: () => firmware.failure == null,
          )),
          true);
    }

    socket.reconnect = connect;

    Future<void> advance(int milliseconds) async {
      for (var n = 0; n < milliseconds; n += 100) {
        await firmware.request('advance 100');
        // Let real network I/O progress independently of firmware virtual time.
        await Future<void>.delayed(const Duration(milliseconds: 5));
        await relay.drained;
        await socket.recovery;
      }
    }

    addTearDown(() async {
      await relay.close();
      await firmware.close();
      client.close();
    });
    attach();
    await advance(1500);
    await firmware.request('call external.simulated_phone.attach_relay');
    await firmware.writeBackgroundAudio(0);
    await advance(3000);
    for (final key in ['photo', 'audio']) {
      final response = await client.get(
          Uri.parse('${config['http_url']}${config[key]['url']}'),
          headers: headers);
      expect(response.statusCode, 404,
          reason: 'Model reference exists before media');
    }
    expect(
        jsonDecode((await relay.execute(1, 'take_photo',
            {'file_id': config['photo']['file_id']}))!)['success'],
        true);
    await advance(3000);
    expect(socket.committed, isEmpty);
    final sd = '${root.path}/firmware/sd';
    expect(File('$sd/${config['photo']['file_id']}.jpg').existsSync(), true);
    // Device reboot + no phone file cache: backend and SD are the durable ends.
    await relay.close();
    await firmware.close();
    firmware = await FirmwareProcess.start(binary, '${root.path}/restarted',
        restoreSd: sd, seed: seed + 1);
    relay = PhoneRelayRuntime(device: firmware, socket: socket);
    attach();
    await advance(1500);
    await firmware.request('call external.simulated_phone.attach_relay');
    await firmware.writeBackgroundAudio(0);
    await advance(3000);
    await connect();
    expect(
        jsonDecode((await relay.execute(2, 'audio.start',
            {'file_id': config['audio']['file_id']}))!)['success'],
        true);
    await advance(3000);
    expect(
        jsonDecode((await relay.execute(3, 'audio.new',
            {'file_id': config['audio_new']['file_id']}))!)['success'],
        true);
    await advance(3000);
    await relay.execute(4, 'audio.stop', {});
    final telemetry =
        File('${root.path}/restarted/sd/telemetry/outbox/demo.jsonl');
    await telemetry.parent.create(recursive: true);
    await telemetry.writeAsString(List.filled(1000, '{"demo":true}\n').join());
    await advance(20000);
    for (final key in ['photo', 'audio', 'audio_new']) {
      final id = config[key]['file_id'];
      expect(socket.committed, contains(id));
      final response = await client.get(
          Uri.parse('${config['http_url']}${config[key]['url']}'),
          headers: headers);
      expect(response.statusCode, 200);
      expect(response.bodyBytes.length, socket.manifests[id]!.size);
      expect(crc32(response.bodyBytes), socket.manifests[id]!.checksum);
      expect(
          File('${root.path}/restarted/sd/${id}${key == 'photo' ? '.jpg' : '.opusraw'}')
              .existsSync(),
          false);
    }
    expect(socket.manifests.values.map((m) => m.kind).toSet(),
        FileKind.values.toSet());
    expect(Directory('${root.path}/phone').existsSync(), false);
    final telemetryManifest =
        socket.manifests.values.singleWhere((m) => m.name == 'demo.jsonl');
    expect(socket.committed, contains(telemetryManifest.id));
    expect(telemetry.existsSync(), false);
    expect(socket.resumedPartial, true,
        reason: 'Backend resumes partial telemetry after WebSocket reconnect');
    print('WebSocket transfer artifacts: ${root.path}');
  },
      skip: binary == null || configPath == null
          ? 'Requires local necklace test stack'
          : false,
      timeout: const Timeout(Duration(minutes: 4)));
}
