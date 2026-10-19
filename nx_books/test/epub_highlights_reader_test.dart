import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:epub_view/epub_view.dart';
import 'package:epub_view/src/ui/paged_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('select words, highlight, restore, recolor and remove', (
    tester,
  ) async {
    List<EpubHighlight> saved = [];
    var removed = false;
    late StateSetter redraw;
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('reader-pixels'),
        child: MaterialApp(
          theme: ThemeData(scaffoldBackgroundColor: Colors.white),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                redraw = setState;
                return PagedEpubContent(
                  blockCount: 1,
                  chapterStarts: const [0],
                  revision: 1,
                  blockBuilder: (_, i) => const Text(
                    'Alpha beta gamma delta.',
                    style: TextStyle(fontSize: 24, color: Colors.black),
                  ),
                  highlights: saved,
                  onHighlightChanged: (highlight, deleted) {
                    removed = deleted;
                    setState(
                      () => saved = deleted
                          ? []
                          : [
                              EpubHighlight(
                                id: 'saved-id',
                                start: highlight.start,
                                end: highlight.end,
                                text: highlight.text,
                                color: highlight.color,
                              ),
                            ],
                    );
                  },
                  onPosition: (_) {},
                  onPage: (_) {},
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final text = find.text('Alpha beta gamma delta.');
    final point = tester.getTopLeft(text) + const Offset(10, 12);
    final originalPixels = (await tester.runAsync(() => textPixels(tester)))!;
    final gesture = await tester.startGesture(point);
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(point + const Offset(150, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('epub-highlight-Yellow')), findsOneWidget);
    final toolbar = tester.getRect(
      find.byKey(const ValueKey('epub-highlight-toolbar')),
    );
    final passage = tester.getRect(text);
    expect(toolbar.top - passage.bottom, inInclusiveRange(0, 16));
    expect(toolbar.left, greaterThanOrEqualTo(8));
    final selectedPixels = (await tester.runAsync(() => textPixels(tester)))!;
    // Color fills the background while the solid black letter pixels stay black.
    expect(originalPixels.$1, greaterThan(0));
    expect(selectedPixels.$1, originalPixels.$1);
    expect(selectedPixels.$2, greaterThan(originalPixels.$2));
    await tester.tap(find.byKey(const ValueKey('epub-highlight-Yellow')));
    await tester.pumpAndSettle();
    expect(saved, hasLength(1));
    expect(saved.first.text, contains('Alpha beta'));
    final serialized = saved.first.toJson();
    redraw(() => saved = [EpubHighlight.fromJson(serialized)!]);
    await tester.pumpAndSettle();
    await tester.tapAt(point);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('epub-highlight-remove')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('epub-highlight-Pink')));
    await tester.pumpAndSettle();
    expect(saved.first.color, 0xfff48fb1);
    expect(saved.first.id, 'saved-id');
    await tester.tapAt(point);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('epub-highlight-remove')));
    await tester.pumpAndSettle();
    expect(removed, true);
    expect(saved, isEmpty);
  });
}

Future<(int, int)> textPixels(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('reader-pixels')),
  );
  final image = await boundary.toImage(pixelRatio: 1);
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  var black = 0, tinted = 0;
  for (var y = 0; y < 30; y++) {
    for (var x = 0; x < 180; x++) {
      final offset = (y * image.width + x) * 4;
      final r = bytes.getUint8(offset),
          g = bytes.getUint8(offset + 1),
          b = bytes.getUint8(offset + 2);
      if (r == 0 && g == 0 && b == 0) black++;
      if (r != g || g != b) tinted++;
    }
  }
  image.dispose();
  return (black, tinted);
}
