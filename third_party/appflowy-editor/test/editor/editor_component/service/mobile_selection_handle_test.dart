import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/render/selection/mobile_basic_handle.dart';
import 'package:appflowy_editor/src/render/selection/mobile_selection_handle.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('iOS range handles retain their position and claim drags early', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final layerLink = LayerLink();
    final editorState = EditorState(document: Document.blank());
    addTearDown(editorState.dispose);

    await tester.pumpWidget(
      Provider.value(
        value: editorState,
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: <Widget>[
                CompositedTransformTarget(
                  link: layerLink,
                  child: const SizedBox(width: 200, height: 200),
                ),
                MobileSelectionHandle(
                  layerLink: layerLink,
                  rect: const Rect.fromLTWH(80, 40, 2, 24),
                  handleType: HandleType.left,
                  handleColor: Colors.blue,
                  handleWidth: 2,
                  handleBallWidth: 8,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(DragHandle)).width,
      11,
    );
    expect(
      find.descendant(
        of: find.byType(DragHandle),
        matching: find.byType(RawGestureDetector),
      ),
      findsOneWidget,
    );
    expect(DragHandle.iOSRangeHandleTouchSlop, 2);
    debugDefaultTargetPlatformOverride = null;
  });
}
