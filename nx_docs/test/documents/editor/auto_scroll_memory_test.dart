import 'package:appflowy_editor/src/editor/editor_component/service/scroll/auto_scroller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('short editor viewport cannot spin between frames', (
    tester,
  ) async {
    final controller = ScrollController(initialScrollOffset: 500);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 300,
            height: 60,
            child: SingleChildScrollView(
              controller: controller,
              child: const SizedBox(height: 2000),
            ),
          ),
        ),
      ),
    );
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    final bounds = tester.getRect(find.byType(SingleChildScrollView));
    var ticks = 0;
    late AutoScroller scroller;
    scroller = AutoScroller(
      scrollable,
      velocityScalar: .15,
      minimumAutoScrollDelta: .07,
      maxAutoScrollDelta: 3.5,
      onScrollViewScrolled: () {
        ticks++;
        // Bound the broken implementation so this test fails, not hangs/OOMs.
        if (ticks == 100) scroller.stopAutoScroll();
      },
    );
    scroller.startAutoScroll(
      bounds.center,
      edgeOffset: 200,
      duration: Duration.zero,
    );
    await tester.pump();
    expect(ticks, lessThan(100), reason: 'scroll must yield to UI frames');
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(
      scroller.scrolling,
      isFalse,
      reason: 'an oversized cursor margin must settle in a short viewport',
    );
    scroller.stopAutoScroll();
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  testWidgets('instant auto scroll yields and can be cancelled', (
    tester,
  ) async {
    final controller = ScrollController(initialScrollOffset: 500);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 300,
            height: 300,
            child: SingleChildScrollView(
              controller: controller,
              child: const SizedBox(height: 2000),
            ),
          ),
        ),
      ),
    );
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    final bounds = tester.getRect(find.byType(SingleChildScrollView));
    var ticks = 0;
    final scroller = AutoScroller(
      scrollable,
      onScrollViewScrolled: () => ticks++,
    );
    scroller.startAutoScroll(
      bounds.bottomCenter + const Offset(0, 100),
      edgeOffset: 50,
      duration: Duration.zero,
    );
    await tester.pump();
    expect(ticks, inInclusiveRange(1, 2));
    expect(controller.offset, greaterThan(500));
    scroller.stopAutoScroll();
    final stoppedAt = controller.offset;
    await tester.pump(const Duration(milliseconds: 16));
    expect(controller.offset, stoppedAt);
    expect(scroller.scrolling, isFalse);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
