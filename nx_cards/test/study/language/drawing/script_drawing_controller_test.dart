import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/study/language/drawing/script_drawing_controller.dart';

void main() {
  test('undo removes only the last stroke and erase clears the rest', () {
    final controller = ScriptDrawingController();
    controller.startStroke(const Offset(10, 20));
    controller.extendStroke(const Offset(20, 30));
    controller.startStroke(const Offset(30, 40));
    controller.undo();
    expect(controller.strokes.single, [
      const Offset(10, 20),
      const Offset(20, 30),
    ]);
    controller.clear();
    controller.undo();
    expect(controller.hasStrokes, isFalse);
    controller.dispose();
  });
}
