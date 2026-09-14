import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_canvas/main.dart';
import 'package:nx_canvas/canvas/drawing.dart';
import 'package:nx_canvas/storage/canvas_store.dart';
import 'package:sqflite/sqflite.dart';

class MemoryStore implements CanvasStore {
  @override
  Database get database => throw UnimplementedError();
  @override
  Future<Drawing> load() async => Drawing();
  @override
  Future<void> save(Drawing drawing, Uint8List preview) async {}
  @override
  Future<void> close() async {}
}

void main() {
  testWidgets(
    'Android pen stays embedded after erasing and offers black ink',
    (tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      final nativeChannels = <MethodChannel>[];
      final editorCalls = <String>[];
      const editor = MethodChannel('nx_canvas/editor');
      messenger.setMockMethodCallHandler(editor, (call) async {
        editorCalls.add(call.method);
        if (call.method == 'recover') return [];
        return null;
      });
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          final channel = MethodChannel(
            'nx_canvas/native/${(call.arguments as Map)['id']}',
          );
          nativeChannels.add(channel);
          messenger.setMockMethodCallHandler(
            channel,
            (call) async => call.method == 'stop' ? [] : null,
          );
        }
        return null;
      });
      await tester.pumpWidget(
        MaterialApp(home: CanvasPage(store: MemoryStore())),
      );
      await tester.pumpAndSettle();
      expect(nativeChannels, hasLength(1));
      expect(find.byTooltip('Black'), findsOneWidget);
      expect(find.byTooltip('Teal'), findsNothing);
      await tester.tap(find.byTooltip('Rub eraser (E)'));
      await tester.pumpAndSettle();
      expect(
        find.text('Rub eraser · Rub over the ink to erase it'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Pen (P)'));
      await tester.pumpAndSettle();
      expect(nativeChannels, hasLength(2));
      expect(editorCalls, ['recover', 'ack']);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1300));
      for (final channel in nativeChannels) {
        messenger.setMockMethodCallHandler(channel, null);
      }
      messenger.setMockMethodCallHandler(editor, null);
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
