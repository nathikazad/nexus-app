import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_documents/nx_documents.dart';

void main() {
  testWidgets(
    'only the heading book icon opens the source after summary scroll',
    (tester) async {
      String? opened;
      var activations = 0;
      var destination = Completer<void>();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DocumentReader(
                headingAction: (_, data) => data['book_source'] == null
                    ? null
                    : (
                        icon: Icons.menu_book_outlined,
                        tooltip: 'Open book source',
                        onPressed: () async {
                          opened = 'structured source';
                          activations++;
                          await destination.future;
                        },
                      ),
                initialPosition: const ReadingPosition(
                  index: 3,
                  alignment: -0.3,
                ),
                content: DocumentContent(
                  identity: const DocumentIdentity(
                    id: 7,
                    modelType: 'Book Chapter',
                  ),
                  title: 'Chapter 1',
                  plainText: '',
                  updatedAt: DateTime.utc(2026),
                  jsonDocument: {
                    'format': 'appflowy_document',
                    'document': {
                      'type': 'page',
                      'children': [
                        for (var i = 0; i < 6; i++)
                          {
                            'type': 'paragraph',
                            'data': {
                              'delta': [
                                {
                                  'insert': List.filled(
                                    30,
                                    'Filler text.',
                                  ).join(' '),
                                },
                              ],
                            },
                          },
                        {
                          'type': 'heading',
                          'data': {
                            'level': 2,
                            'book_source': {'version': 1, 'book_id': 23},
                            'delta': [
                              {'insert': 'Sources of scale'},
                            ],
                          },
                        },
                        {
                          'type': 'paragraph',
                          'data': {
                            'delta': [
                              {
                                'insert': List.filled(
                                  200,
                                  'More text.',
                                ).join(' '),
                              },
                            ],
                          },
                        },
                      ],
                    },
                  },
                ),
                onChanged: (_) async {},
                onOpenLink: (href) async {
                  opened = href;
                  activations++;
                  await destination.future;
                  return true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final target = find.text('Sources of scale', findRichText: true);
      for (var i = 0; i < 12 && target.hitTestable().evaluate().isEmpty; i++) {
        await tester.sendEventToBinding(
          const PointerScrollEvent(
            position: Offset(400, 300),
            scrollDelta: Offset(0, 300),
            kind: PointerDeviceKind.mouse,
          ),
        );
        await tester.pumpAndSettle();
      }
      expect(target.hitTestable(), findsOneWidget);
      await tester.tap(target.hitTestable(), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(opened, isNull, reason: 'The heading itself is not a link');
      final icon = find.byTooltip('Open book source');
      expect(icon, findsOneWidget);
      expect(
        tester
            .getCenter(find.descendant(of: icon, matching: find.byType(Icon)))
            .dy,
        closeTo(tester.getCenter(target).dy, 1),
        reason: 'The icon glyph is vertically centered on the heading',
      );
      expect(
        tester.getCenter(icon).dx,
        greaterThan(tester.getCenter(target).dx),
      );
      final mouse = await tester.startGesture(
        tester.getCenter(icon),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 150));
      await mouse.moveBy(const Offset(1, 0));
      await tester.pump(const Duration(milliseconds: 50));
      await mouse.up();
      await tester.pumpAndSettle();
      expect(opened, 'structured source');
      await tester.tap(icon, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(activations, 1, reason: 'Repeated clicks cannot stack readers');
      destination.complete();
      await tester.pumpAndSettle();
      destination = Completer<void>();
      await tester.tap(icon, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(activations, 2, reason: 'Returning permits the next reference');
      destination.complete();
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant({
      TargetPlatform.macOS,
      TargetPlatform.android,
    }),
  );
}
