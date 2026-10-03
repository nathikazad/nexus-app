import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nexus_voice_assistant/data/file_transfer/protocol.dart';
import 'package:nexus_voice_assistant/data/file_transfer/relay.dart';
import 'package:nexus_voice_assistant/data/necklace/necklace_command_handler.dart';
import 'package:nexus_voice_assistant/data/simulator/firmware_process.dart';

void main() {
  final binary = Platform.environment['NEXUS_FIRMWARE_SIM'];
  final configPath = Platform.environment['NEXUS_NECKLACE_TEST_CONFIG'];
  test(
      'actual firmware -> stateless phone -> WebSocket -> timeline and model references',
      () async {
    final config = jsonDecode(await File(configPath!).readAsString())
        as Map<String, dynamic>;
    final configDir = File(configPath).parent;
    final token = await File('${configDir.path}/device-token').readAsString();
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
    WebSocket? socket;
    Future<void> replies = Future.value();
    final committed = <String>{}, manifests = <String, FileManifest>{};
    var dropCommit = true, disconnectOnce = true, resumedPartial = false;
    Future<void> reconnectWork = Future.value();
    late Future<void> Function() reconnect;
    final relay = FileRelay(sendToServer: (b) {
      final p = FilePacket.parse(b);
      if (p.op == FileOp.begin) manifests[p.id] = p.manifest();
      File('${root.path}/frames.log').writeAsStringSync(
          'TX ${p.op} ${p.id} ${b.length}\n',
          mode: FileMode.append);
      if (socket?.readyState != WebSocket.open) return false;
      socket!.add(b);
      if (disconnectOnce &&
          p.op == FileOp.chunk &&
          manifests[p.id]?.kind == FileKind.telemetry) {
        disconnectOnce = false;
        final closing = socket!;
        socket = null;
        reconnectWork = closing.close().then((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          await reconnect();
        });
      }
      return true;
    }, sendToDevice: (b) async {
      final p = FilePacket.parse(b);
      File('${root.path}/frames.log')
          .writeAsStringSync('RX ${p.op} ${p.id}\n', mode: FileMode.append);
      if (p.op == FileOp.resume &&
          p.offset > 0 &&
          manifests[p.id]?.kind == FileKind.telemetry) {
        resumedPartial = true;
      }
      if (p.op == FileOp.commit) {
        committed.add(p.id);
        if (dropCommit) {
          dropCommit = false;
          return;
        }
      }
      await firmware.write('file_rx', b);
    });
    void attach() {
      firmware.onNotification = (channel, b) {
        if (channel == 'file') relay.fromDevice(b);
      };
    }

    Future<void> connect() async {
      socket = await WebSocket.connect(config['websocket_url'], headers: {
        'authorization': 'Bearer $token',
        'x-client-id': 'necklace'
      });
      socket!.listen((message) {
        if (message is List<int> &&
            message.length >= 4 &&
            message[0] == 0 &&
            message[1] == 0x84) {
          replies = replies
              .then((_) => relay.fromServer(Uint8List.fromList(message)));
        }
      });
    }

    Future<void> advance(int milliseconds) async {
      for (var n = 0; n < milliseconds; n += 100) {
        await firmware.request('advance 100');
        // Let real network I/O progress independently of firmware virtual time.
        await Future<void>.delayed(const Duration(milliseconds: 5));
        await replies;
        await reconnectWork;
      }
    }

    addTearDown(() async {
      await socket?.close();
      await replies;
      await relay.close();
      await firmware.close();
      client.close();
    });
    reconnect = connect;
    attach();
    await advance(1500);
    await firmware.request('call external.simulated_phone.attach_relay');
    await firmware.writeBackgroundAudio(0);
    await advance(3000);
    final commands = NecklaceCommandHandler(firmware);
    for (final key in ['photo', 'audio']) {
      final response = await client.get(
          Uri.parse('${config['http_url']}${config[key]['url']}'),
          headers: headers);
      expect(response.statusCode, 404,
          reason: 'Model reference exists before media');
    }
    await firmware.write('file_rx', Uint8List.fromList(fileHello));
    expect(
        jsonDecode((await commands.handle(1, 'take_photo',
            {'file_id': config['photo']['file_id']}))!)['success'],
        true);
    await advance(3000);
    expect(committed, isEmpty);
    final sd = '${root.path}/firmware/sd';
    expect(File('$sd/${config['photo']['file_id']}.jpg').existsSync(), true);
    // Device reboot + no phone file cache: backend and SD are the durable ends.
    await firmware.close();
    firmware = await FirmwareProcess.start(binary, '${root.path}/restarted',
        restoreSd: sd, seed: seed + 1);
    attach();
    await advance(1500);
    await firmware.request('call external.simulated_phone.attach_relay');
    await firmware.writeBackgroundAudio(0);
    await advance(3000);
    await connect();
    await firmware.write('file_rx', Uint8List.fromList(fileHello));
    final resumedCommands = NecklaceCommandHandler(firmware);
    expect(
        jsonDecode((await resumedCommands.handle(2, 'audio.start',
            {'file_id': config['audio']['file_id']}))!)['success'],
        true);
    await advance(3000);
    expect(
        jsonDecode((await resumedCommands.handle(3, 'audio.new',
            {'file_id': config['audio_new']['file_id']}))!)['success'],
        true);
    await advance(3000);
    await resumedCommands.handle(4, 'audio.stop', {});
    final telemetry =
        File('${root.path}/restarted/sd/telemetry/outbox/demo.jsonl');
    await telemetry.parent.create(recursive: true);
    await telemetry.writeAsString(List.filled(1000, '{"demo":true}\n').join());
    await advance(20000);
    for (final key in ['photo', 'audio', 'audio_new']) {
      final id = config[key]['file_id'];
      expect(committed, contains(id));
      final response = await client.get(
          Uri.parse('${config['http_url']}${config[key]['url']}'),
          headers: headers);
      expect(response.statusCode, 200);
      expect(response.bodyBytes.length, manifests[id]!.size);
      expect(crc32(response.bodyBytes), manifests[id]!.checksum);
      expect(
          File('${root.path}/restarted/sd/${id}${key == 'photo' ? '.jpg' : '.opusraw'}')
              .existsSync(),
          false);
    }
    expect(
        manifests.values.map((m) => m.kind).toSet(), FileKind.values.toSet());
    expect(Directory('${root.path}/phone').existsSync(), false);
    final telemetryManifest =
        manifests.values.singleWhere((m) => m.name == 'demo.jsonl');
    expect(committed, contains(telemetryManifest.id));
    expect(telemetry.existsSync(), false);
    expect(resumedPartial, true,
        reason: 'Backend resumes partial telemetry after WebSocket reconnect');
    print('WebSocket transfer artifacts: ${root.path}');
  },
      skip: binary == null || configPath == null
          ? 'Requires local necklace test stack'
          : false,
      timeout: const Timeout(Duration(minutes: 4)));
}
