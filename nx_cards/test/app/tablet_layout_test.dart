import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/app/adaptive_card_grid.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/study/language/drawing/script_draw_practice_page.dart';

void main() {
  testWidgets('card columns adapt to window size and larger text', (
    tester,
  ) async {
    for (final (width, scale, columns) in [
      (390.0, 1.0, 1),
      (990.0, 1.0, 2),
      (1280.0, 1.0, 3),
      (990.0, 2.0, 1),
    ]) {
      await tester.binding.setSurfaceSize(Size(width, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: AdaptiveCardGrid(
                children: [
                  for (var i = 0; i < 4; i++)
                    SizedBox(
                      key: ValueKey('card-$i'),
                      height: 60,
                      child: Text('Card $i'),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      final first = tester.getTopLeft(find.byKey(const ValueKey('card-0')));
      final nextRow = tester.getTopLeft(find.byKey(ValueKey('card-$columns')));
      expect(nextRow.dy, greaterThan(first.dy));
      if (columns > 1) {
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('card-1'))).dy,
          first.dy,
        );
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('drawing resizes between tablet, phone and landscape', (
    tester,
  ) async {
    final card = StudyCard(
      id: 1,
      content: const LanguageCardContent(
        english: 'afternoon',
        originalScript: '下午',
        transliteration: 'xiàwǔ',
      ),
      schedules: const {},
      reviewHistory: const {},
      suspended: false,
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in [
      const Size(990, 1320),
      const Size(1320, 990),
      const Size(390, 844),
      const Size(740, 360),
      const Size(600, 900),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          home: ScriptDrawPracticePage(title: 'Chinese', cards: [card]),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final canvas = find.byKey(const ValueKey('script-drawing-canvas'));
      final letter = find.byKey(const ValueKey('draw-practice-letter'));
      final canvasRect = tester.getRect(canvas);
      final letterRect = tester.getRect(letter);
      expect(canvasRect.height, greaterThan(150));
      expect(canvasRect.top, greaterThan(letterRect.bottom));
      final frameRect = tester.getRect(
        find.byKey(const ValueKey('script-drawing-frame')),
      );
      for (final label in ['Undo', 'Erase']) {
        final button = tester.getRect(find.byTooltip(label));
        expect(frameRect.contains(button.center), isTrue);
        expect(button.bottom, lessThanOrEqualTo(canvasRect.top));
      }
      expect(
        tester.getRect(find.byTooltip('Hide character')).top,
        greaterThan(frameRect.bottom),
      );

      await tester.ensureVisible(find.byTooltip('Hide character'));
      await tester.tap(find.byTooltip('Hide character'));
      await tester.pump();
      expect(letter.hitTestable(), findsNothing);
      await tester.tap(find.byTooltip('Show character'));
      await tester.ensureVisible(canvas);
      await tester.drag(canvas, const Offset(50, 50));
      await tester.pump();
      final erase = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.delete_outline),
      );
      expect(erase.onPressed, isNotNull);
      await tester.ensureVisible(find.byTooltip('Erase'));
      await tester.tap(find.byTooltip('Erase'));
      await tester.pump();
    }
  });
}
