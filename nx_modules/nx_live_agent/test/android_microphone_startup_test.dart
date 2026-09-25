import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:nx_live_agent/nx_live_agent.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const rtc = MethodChannel('FlutterWebRTC.Method');
  const service = MethodChannel('flutter_foreground_task/methods');
  const audio = MethodChannel('com.ryanheise.audio_session');
  late Completer<Object?> permission;
  late List<String> calls;
  late List<bool> microphoneMutes;
  Map<dynamic, dynamic>? initialization;
  Completer<Object?>? serviceGate;
  late OpenAiRealtimeTransport transport;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    permission = Completer<Object?>();
    WebRTC.initialized = false;
    initialization = null;
    calls = [];
    microphoneMutes = [];
    serviceGate = null;
    transport = OpenAiRealtimeTransport();
    messenger.setMockMethodCallHandler(audio, (call) async => null);
    messenger.setMockMethodCallHandler(rtc, (call) async {
      calls.add(call.method);
      if (call.method == 'initialize') {
        initialization = (call.arguments as Map)['options'] as Map;
      }
      if (call.method == 'setMicrophoneMuted') {
        microphoneMutes.add((call.arguments as Map)['muted'] as bool);
      }
      if (call.method == 'getUserMedia') return permission.future;
      return null;
    });
    messenger.setMockMethodCallHandler(service, (call) async {
      calls.add(call.method);
      if (call.method == 'isRunningService') return false;
      if (call.method == 'checkNotificationPermission') return 0;
      if (call.method == 'startService') {
        if (serviceGate != null) return serviceGate!.future;
        throw PlatformException(
          code: 'service-test-stop',
          message: 'Service reached after permission',
        );
      }
      return null;
    });
  });
  tearDown(() async {
    await transport.dispose();
    for (final channel in [rtc, service, audio]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    debugDefaultTargetPlatformOverride = null;
  });
  Future<void> start() => transport.connect(
    credential: 'test',
    spec: const LiveAgentSpec(instructions: 'Test', allowInterruption: false),
    tools: const [],
  );
  Future<void> waitForPermission() async {
    for (var i = 0; i < 30 && !calls.contains('getUserMedia'); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(calls, contains('getUserMedia'));
    expect(calls, isNot(contains('startService')));
  }

  test(
    'Android playback uses ADM silence and restores input without stopping tracks',
    () async {
      serviceGate = Completer<Object?>();
      final result = expectLater(start(), throwsA(isA<PlatformException>()));
      await waitForPermission();
      expect(initialization?['bypassVoiceProcessing'], true);
      expect(
        (initialization?['androidAudioConfiguration']
            as Map)['androidAudioMode'],
        'normal',
      );
      permission.complete({
        'streamId': 'microphone',
        'audioTracks': [],
        'videoTracks': [],
      });
      for (var i = 0; i < 30 && !calls.contains('startService'); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(microphoneMutes, [false]);
      await transport.handleServerMessage(
        '{"type":"output_audio_buffer.started"}',
      );
      await Future<void>.delayed(Duration.zero);
      expect(microphoneMutes.last, true);
      await transport.handleServerMessage(
        '{"type":"output_audio_buffer.stopped"}',
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(microphoneMutes.last, false);
      await transport.setInputEnabled(false);
      await transport.handleServerMessage(
        '{"type":"output_audio_buffer.started"}',
      );
      await transport.handleServerMessage(
        '{"type":"output_audio_buffer.stopped"}',
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(
        microphoneMutes.last,
        true,
        reason: 'User mute survives playback ending',
      );
      expect(calls, isNot(contains('mediaStreamTrackSetEnable')));
      expect(calls, isNot(contains('mediaStreamTrackStop')));
      serviceGate!.completeError(PlatformException(code: 'test-finished'));
      await result;
    },
  );

  test(
    'waits for microphone grant before service and cleans up a service failure',
    () async {
      final result = expectLater(start(), throwsA(isA<PlatformException>()));
      await waitForPermission();
      permission.complete({
        'streamId': 'microphone',
        'audioTracks': [],
        'videoTracks': [],
      });
      await result;
      expect(
        calls.indexOf('getUserMedia'),
        lessThan(calls.indexOf('startService')),
      );
      expect(calls, contains('streamDispose'));
      expect(calls, isNot(contains('createPeerConnection')));
    },
  );
  test(
    'denial gives instructions without starting service or a peer',
    () async {
      final result = expectLater(
        start(),
        throwsA(
          predicate(
            (e) =>
                e.toString().contains('Microphone access is required') &&
                e.toString().contains('Settings'),
          ),
        ),
      );
      await waitForPermission();
      permission.completeError(
        PlatformException(
          code: 'NotAllowedError',
          message: 'Permission denied',
        ),
      );
      await result;
      expect(calls, isNot(contains('startService')));
      expect(calls, isNot(contains('createPeerConnection')));
    },
  );
  test(
    'closing during permission prompt cannot start a service later',
    () async {
      final result = expectLater(start(), throwsStateError);
      await waitForPermission();
      await transport.close();
      permission.complete({
        'streamId': 'microphone',
        'audioTracks': [],
        'videoTracks': [],
      });
      await result;
      expect(calls, isNot(contains('startService')));
      expect(calls, contains('streamDispose'));
    },
  );
}
