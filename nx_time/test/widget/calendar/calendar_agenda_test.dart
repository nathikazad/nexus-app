import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/domain/calendar/calendar_entry.dart';
import 'package:nx_time/features/calendar/calendar_agenda.dart';
import 'package:nx_time/features/calendar/calendar_feed_providers.dart';

void main() {
  testWidgets(
    'renders event attendance once, birthdays and unscheduled chores',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final font = Platform.environment['CALENDAR_PREVIEW_FONT'];
      if (font != null) {
        await tester.runAsync(() async {
          final loader = FontLoader('CalendarPreview')
            ..addFont(
              Future.value(ByteData.sublistView(File(font).readAsBytesSync())),
            );
          await loader.load();
          final icons = FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
          await icons.load();
        });
      }
      final key = GlobalKey();
      final feed = CalendarFeed(
        entries: [
          CalendarEntry(
            id: 1,
            kind: 'birthday',
            modelType: 'Person',
            name: 'Alex',
            start: DateTime(2026, 10, 5),
          ),
          CalendarEntry(
            id: 2,
            kind: 'event',
            modelType: 'Event',
            name: 'Neighborhood makers fair',
            description: 'Meet local makers and see their projects.',
            start: DateTime(2026, 10, 5, 9),
            end: DateTime(2026, 10, 5, 17),
            links: [
              {'name': 'Community Hall', 'model_type': 'Place'},
            ],
            attendance: [
              CalendarEntry(
                id: 3,
                kind: 'action',
                modelType: 'Goto',
                name: 'Attend fair',
                attributes: {
                  'planning_status': 'planned',
                  'scheduled_start_time': '2026-10-05T13:00:00',
                },
              ),
            ],
          ),
          CalendarEntry(
            id: 4,
            kind: 'deadline',
            modelType: 'Task',
            name: 'Post bike on Facebook',
            start: DateTime(2026, 10, 5, 18),
            attributes: {'status': 'todo'},
          ),
        ],
        unscheduled: [
          CalendarEntry(
            id: 5,
            kind: 'task',
            modelType: 'Task',
            name: 'Clean the fridge',
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [calendarFeedProvider.overrideWith((ref) async => feed)],
          child: MaterialApp(
            theme: ThemeData(
              fontFamily: font == null ? null : 'CalendarPreview',
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xfff97316),
              ),
              scaffoldBackgroundColor: Colors.white,
            ),
            home: RepaintBoundary(
              key: key,
              child: Scaffold(
                appBar: AppBar(title: const Text('Monday, October 5')),
                body: CalendarAgenda(day: DateTime(2026, 10, 5)),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Neighborhood makers fair'), findsOneWidget);
      expect(find.text('Your attendance: planned'), findsOneWidget);
      expect(find.text('Alex’s birthday'), findsOneWidget);
      expect(find.text('Clean the fridge'), findsOneWidget);
      expect(find.text('Plan to go'), findsNothing);
      expect(tester.takeException(), isNull);
      final path = Platform.environment['CALENDAR_SCREENSHOT_PATH'];
      if (path != null) {
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(path).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    },
  );
}
