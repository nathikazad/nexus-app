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
      MaterialApp(
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
                  style: TextStyle(fontSize: 24),
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
    );
    await tester.pumpAndSettle();
    final text = find.text('Alpha beta gamma delta.');
    final point = tester.getTopLeft(text) + const Offset(10, 12);
    final gesture = await tester.startGesture(point);
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(point + const Offset(150, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('epub-highlight-Yellow')), findsOneWidget);
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
