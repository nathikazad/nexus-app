import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_canvas/canvas/canvas_controller.dart';
import 'package:nx_canvas/canvas/drawing.dart';
import 'package:nx_canvas/canvas/native_ink_surface.dart';

void main() {
  testWidgets(
    'native ink ACK avoids redraw; undo restores; disposal drains once',
    (tester) async {
      final c = CanvasController(Drawing());
      final messenger = tester.binding.defaultBinaryMessenger;
      final calls = <MethodCall>[];
      late MethodChannel channel;
      final stroke = {
        'id': 'record-1',
        'points': [
          [15.0, 40.0, .6],
          [25.0, 80.0, .8],
        ],
        'color': 0xff000000,
        'width': 3.0,
      };
      final finalStroke = {...stroke, 'id': 'record-2'};
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          final id = (call.arguments as Map)['id'];
          channel = MethodChannel('nx_canvas/native/$id');
          messenger.setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'stop') return [stroke, finalStroke];
            return null;
          });
        }
        return null;
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NativeInkSurface(
              controller: c,
              onUnavailable: (message) => fail(message),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(calls.where((call) => call.method == 'scene'), hasLength(1));
      final ack = Completer<void>();
      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('stroke', stroke),
        ),
        (_) => ack.complete(),
      );
      await ack.future;
      await tester.pump();
      expect(c.strokes, hasLength(1));
      expect(calls.where((call) => call.method == 'scene'), hasLength(1));
      c.color = 0xff168274;
      c.refresh();
      await tester.pump();
      expect(calls.last.method, 'style');
      c.undo();
      await tester.pump();
      expect(calls.last.method, 'scene');
      expect(c.strokes, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1200));
      // Old pending delivery cannot resurrect the undone stroke. The last,
      // previously undelivered stroke is retained despite widget disposal.
      expect(c.strokes, hasLength(1));
      expect(c.revision, 3);
      messenger.setMockMethodCallHandler(channel, null);
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      c.dispose();
    },
  );
}
