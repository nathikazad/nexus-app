import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nx_canvas/main.dart';
import 'package:nx_canvas/storage/canvas_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Mac drawing, erase, undo, navigation and durable restart', (
    tester,
  ) async {
    final dir = await Directory.systemTemp.createTemp('nx-canvas-integration-');
    final path = '${dir.path}/canvas.sqlite';
    var store = await CanvasStore.open(path: path);
    await tester.pumpWidget(MaterialApp(home: CanvasPage(store: store)));
    await tester.pumpAndSettle();
    final origin = tester.getTopLeft(
      find.byKey(const ValueKey('canvas-surface')),
    );
    final pen = await tester.startGesture(
      origin + const Offset(160, 240),
      kind: PointerDeviceKind.mouse,
    );
    await pen.moveTo(origin + const Offset(460, 240));
    await pen.up();
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect((await store.load()).strokes.length, 1);
    await tester.tap(find.byTooltip('Erase parts (E)'));
    final eraser = await tester.startGesture(
      origin + const Offset(310, 220),
      kind: PointerDeviceKind.mouse,
    );
    await eraser.moveTo(origin + const Offset(310, 260));
    await eraser.up();
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect((await store.load()).strokes.length, 2);
    await tester.tap(find.byTooltip('Undo drawing'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect((await store.load()).strokes.length, 1);
    await tester.tap(find.byTooltip('Redo drawing'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect((await store.load()).strokes.length, 2);
    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    final expected = await store.load();
    expect(expected.view.scale, 1.25);
    final rows = await store.database.query('canvases');
    expect((rows.single['preview_png'] as List<int>).take(4), [
      137,
      80,
      78,
      71,
    ]);
    await tester.pumpWidget(const SizedBox());
    await store.close();
    store = await CanvasStore.open(path: path);
    await tester.pumpWidget(MaterialApp(home: CanvasPage(store: store)));
    await tester.pumpAndSettle();
    expect((await store.load()).toJson(), expected.toJson());
    expect(find.text('125%'), findsOneWidget);
    expect(find.text('Saved on this device'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await store.close();
    await dir.delete(recursive: true);
  });
}
