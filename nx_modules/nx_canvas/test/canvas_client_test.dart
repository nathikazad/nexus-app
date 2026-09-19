import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_canvas_core/canvas_client.dart';
import 'package:nx_canvas_core/drawing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('canvas-contract-test');
  const client = MethodChannelCanvasClient(channel: channel);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test('shared Kotlin/Dart format fixture round trips without losing ink', () {
    final json =
        jsonDecode(
              File(
                '../nx_canvas_model/test/fixtures/drawing-v1.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect(Drawing.fromJson(json).toJson(), json);
  });
  test('typed host contract preserves identity, token and drawing', () async {
    final drawing = Drawing();
    final methods = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      if (call.method == 'available' || call.method == 'ackDocument')
        return true;
      if (call.method == 'openDocument') {
        final args = call.arguments as Map;
        expect(args['documentId'], 'session');
        expect(args['format'], 'nx-canvas');
      }
      return {
        'documentId': 'session',
        'saveToken': 'revision',
        'drawing': drawing.toJson(),
      };
    });
    expect(await client.available(), isTrue);
    final result = await client.open(
      CanvasOpenRequest(
        sessionId: 'session',
        title: 'Canvas',
        drawing: drawing,
      ),
    );
    expect(result!.sessionId, 'session');
    expect(result.token, 'revision');
    expect((await client.recover())!.drawing.toJson(), drawing.toJson());
    expect((await client.peek('old'))!.token, 'revision');
    expect(await client.acknowledge(result.token), isTrue);
    expect(methods, [
      'available',
      'openDocument',
      'recoverDocument',
      'peekDocument',
      'ackDocument',
    ]);
  });
  test('invalid recovery cannot silently become an empty drawing', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => {'documentId': 'session'},
    );
    await expectLater(client.recover(), throwsFormatException);
  });
  test('transport failures propagate so host retains recovery', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => throw PlatformException(code: 'disk'),
    );
    await expectLater(
      client.acknowledge('token'),
      throwsA(isA<PlatformException>()),
    );
  });
}
