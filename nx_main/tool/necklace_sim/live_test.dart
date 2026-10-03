// Desktop entry point: flutter test tool/necklace_sim/live_test.dart --reporter expanded
// Configuration is passed by path in NEXUS_SIM_CONFIG, never token CLI arguments.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/data/devices/necklace_identity.dart';
import 'package:nexus_voice_assistant/data/necklace/phone_relay_runtime.dart';
import 'package:nexus_voice_assistant/data/simulator/firmware_process.dart';
import 'package:nexus_voice_assistant/data/simulator/control_panel.dart';
import 'package:nexus_voice_assistant/data/simulator/software_identity.dart';
import 'package:nexus_voice_assistant/data/socket/bg_socket_client.dart';

void main() {
  final configPath = Platform.environment['NEXUS_SIM_CONFIG'];
  test('desktop phone relay to live Nexus server', () async {
    final config = jsonDecode(await File(configPath!).readAsString())
        as Map<String, dynamic>;
    final identity = await SoftwareIdentity.start(
        config['python'] as String,
        config['identity_script'] as String,
        config['identity_state'] as String);
    addTearDown(identity.close);
    if (config['pairing_setup_file'] != null) {
      final setup = jsonDecode(
              await File(config['pairing_setup_file'] as String).readAsString())
          as Map<String, dynamic>;
      if (await NecklaceIdentity(identity.exchange).inspect() == null) {
        await NecklaceIdentity(identity.exchange).provision(setup);
      }
    }
    final deviceId = await NecklaceIdentity(identity.exchange).inspect();
    if (deviceId == null)
      throw StateError(
          'Enroll Simulated Necklace and supply pairing_setup_file first');
    final socket = SocketClient();
    final firmware = await FirmwareProcess.start(
        config['binary'] as String, config['output'] as String);
    final relay = PhoneRelayRuntime(device: firmware, socket: socket);
    addTearDown(() async {
      firmware.onNotification = null;
      await relay.close();
      await firmware.close();
    });
    SimulatorPanel? panelObserver;
    firmware.onNotification = (channel, bytes) {
      relay.onNotification(channel, bytes);
      if (channel == 'file') panelObserver?.onFilePacket(bytes);
    };
    await firmware.request('advance 1000');
    await firmware.request('call external.simulated_phone.attach_relay');
    // The initial interactive fixture is idle. The firmware's default is ON.
    await firmware.writeBackgroundAudio(0);
    await firmware.request('advance 1000');
    final connected = await relay.connect(PhoneRelaySession(
        httpUrl: config['http_url'] as String,
        socketUrl: config['socket_url'] as String,
        deviceId: deviceId,
        exchangeIdentity: identity.exchange,
        isCurrent: () => firmware.failure == null,
        domainId: config['domain_id'] as int?));
    expect(connected, isTrue,
        reason: 'Authenticated necklace WebSocket handshake');
    if (config['live_microphone'] == true) {
      await firmware
          .request('call hardware.esp.simulated_microphone.stream_pcm16');
    }
    if (config['microphone_wav'] != null)
      await firmware.request('mic_wav ${config['microphone_wav']}');
    final duration = (config['duration_seconds'] as num? ?? 60).toDouble();
    final pressMs = config['press_ms'] as int?;
    final holdMs = config['hold_ms'] as int? ?? 3000;
    bool pressed = false, released = false;
    final panel = SimulatorPanel(
        firmware,
        relay,
        Directory('tool/necklace_sim/panel'),
        Directory(config['output'] as String));
    panelObserver = panel;
    await panel.start(config['control_port'] as int? ?? 0);
    addTearDown(panel.close);
    print(
        'Phone relay connected. Control panel: http://127.0.0.1:${panel.port}');
    final clock = Stopwatch()..start();
    var advanced = 0;
    while (!panel.stopped && clock.elapsedMilliseconds < duration * 1000) {
      final now = clock.elapsedMilliseconds;
      if (pressMs != null && !pressed && now >= pressMs) {
        await firmware.request('input button 1');
        pressed = true;
      }
      if (pressed && !released && now >= pressMs! + holdMs) {
        await firmware.request('input button 0');
        released = true;
      }
      final delta = now - advanced;
      if (delta > 0) {
        await firmware.request('advance $delta');
        advanced = now;
      }
      if (firmware.failure != null) throw StateError('Firmware IPC failed');
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await firmware.request('input button 0');
    await firmware.request('observe');
    final minimum = config['min_speaker_samples'] as int? ?? 0;
    expect(firmware.state['speaker_samples'] as int,
        greaterThanOrEqualTo(minimum));
    print(
        'Relay finished; speaker samples: ${firmware.state['speaker_samples']}');
  },
      skip: configPath == null
          ? 'Set NEXUS_SIM_CONFIG to opt into the live server'
          : false,
      timeout: const Timeout(Duration(hours: 13)));
}
