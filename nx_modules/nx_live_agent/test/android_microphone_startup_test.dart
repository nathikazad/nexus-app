import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
  late OpenAiRealtimeTransport transport;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    permission = Completer<Object?>();
    calls = [];
    transport = OpenAiRealtimeTransport();
    messenger.setMockMethodCallHandler(audio, (call) async => null);
    messenger.setMockMethodCallHandler(rtc, (call) async {
      calls.add(call.method);
      if (call.method == 'getUserMedia') return permission.future;
      return null;
    });
    messenger.setMockMethodCallHandler(service, (call) async {
      calls.add(call.method);
      if (call.method == 'isRunningService') return false;
      if (call.method == 'checkNotificationPermission') return 0;
      if (call.method == 'startService') {
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
    spec: const LiveAgentSpec(instructions: 'Test'),
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
