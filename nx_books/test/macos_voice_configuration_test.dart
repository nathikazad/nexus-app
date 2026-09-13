import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_voice/nx_voice.dart';
import 'package:opus_dart/opus_dart.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Mac recorder uses its native permission API, including denial',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const channel = MethodChannel('com.llfbandit.record/messages');
      final calls = <String>[];
      var allowed = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            return call.method == 'hasPermission' ? allowed : null;
          });
      final mic = NxMicrophoneOpusStreamer();
      expect(await mic.ensurePermission(), isTrue);
      allowed = false;
      expect(await mic.ensurePermission(), isFalse);
      expect(calls.where((method) => method == 'hasPermission'), hasLength(2));
      await mic.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    },
  );

  test('Mac app declares microphone privacy and sandbox capabilities', () {
    expect(
      File('macos/Runner/Info.plist').readAsStringSync(),
      contains('NSMicrophoneUsageDescription'),
    );
    for (final mode in ['Release', 'DebugProfile']) {
      expect(
        File('macos/Runner/$mode.entitlements').readAsStringSync(),
        contains('<key>com.apple.security.device.audio-input</key>\n\t<true/>'),
      );
    }
  });

  test(
    'bundled macOS Opus performs a native encode/decode round trip',
    () {
      final library = DynamicLibrary.open(
        '../nx_modules/nx_opus_macos/macos/nx_opus_macos/opus.xcframework/macos-arm64_x86_64/opus.framework/opus',
      );
      initOpus(library);
      final encoder = SimpleOpusEncoder(
        sampleRate: 16000,
        channels: 1,
        application: Application.voip,
      );
      final decoder = SimpleOpusDecoder(sampleRate: 16000, channels: 1);
      try {
        final packet = encoder.encode(input: Int16List(960));
        expect(packet, isNotEmpty);
        expect(decoder.decode(input: packet), hasLength(960));
      } finally {
        encoder.destroy();
        decoder.destroy();
      }
    },
    skip: !Platform.isMacOS,
  );
}
