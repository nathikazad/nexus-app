import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:nx_time/features/today/today_view_model.dart';

import '../../_support/test_actions.dart';

void main() {
  setUpAll(() {
    Intl.defaultLocale = 'en_US';
  });

  test('buildTodaySnapshot maps actions to rows and title', () {
    final day = DateTime(2026, 4, 18);
    final actions = [
      sampleAction(
        id: 1,
        name: 'Meet',
        start: DateTime(day.year, day.month, day.day, 9, 0),
        end: DateTime(day.year, day.month, day.day, 10, 0),
      ),
    ];
    final snap = buildTodaySnapshot(actions, day);
    expect(snap.titleLine, 'Actions');
    expect(snap.dayDateLabel, 'Sat, Apr 18');
    expect(snap.actions.length, 1);
    expect(snap.sourceActions.length, 1);
    expect(snap.activityBlockCount, 1);
    expect(snap.timeMapSegments.length, 1);
  });

  test(
    'buildTodaySnapshot emits TodayUmbrellaActivity and one segment per umbrella',
    () {
      final day = DateTime(2026, 4, 18);
      final parent = sampleAction(
        id: 1,
        name: 'Day out',
        modelTypeId: 3,
        modelTypeName: 'Goto',
        start: DateTime(day.year, day.month, day.day, 8, 0),
        end: DateTime(day.year, day.month, day.day, 18, 0),
        childActionIds: const [2, 3],
      );
      final c1 = sampleAction(
        id: 2,
        name: 'Coffee',
        modelTypeId: 4,
        start: DateTime(day.year, day.month, day.day, 9, 0),
        end: DateTime(day.year, day.month, day.day, 9, 30),
      );
      final c2 = sampleAction(
        id: 3,
        name: 'Lunch',
        modelTypeId: 4,
        start: DateTime(day.year, day.month, day.day, 12, 0),
        end: DateTime(day.year, day.month, day.day, 13, 0),
      );
      final snap = buildTodaySnapshot([parent, c1, c2], day);
      expect(snap.actions.length, 1);
      expect(snap.actions.single, isA<TodayUmbrellaActivity>());
      final u = snap.actions.single as TodayUmbrellaActivity;
      expect(u.title, 'Day out');
      expect(u.children.length, 2);
      expect(snap.sourceActions.single.name, 'Day out');
      expect(snap.activityBlockCount, 1);
      expect(snap.timeMapSegments.length, 1);
      expect(snap.umbrellaRows.single.umbrella.id, 1);
    },
  );
}
