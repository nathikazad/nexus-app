import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/features/today/action_fold.dart';

import '../../_support/test_actions.dart';

void main() {
  final day = DateTime(2026, 4, 18);

  test('flat list with no edges → one row per action, sorted by start', () {
    final a = sampleAction(
      id: 2,
      name: 'B',
      start: DateTime(day.year, day.month, day.day, 10, 0),
      end: DateTime(day.year, day.month, day.day, 11, 0),
    );
    final b = sampleAction(
      id: 1,
      name: 'A',
      start: DateTime(day.year, day.month, day.day, 9, 0),
      end: DateTime(day.year, day.month, day.day, 10, 0),
    );
    final rows = foldDayActions([a, b]);
    expect(rows.length, 2);
    expect(rows.map((r) => r.umbrella.id).toList(), [1, 2]);
    expect(rows.every((r) => r.children.isEmpty), isTrue);
  });

  test('parent with two children → one umbrella row; children sorted by start', () {
    final p = sampleAction(
      id: 1,
      name: 'Trip',
      start: DateTime(day.year, day.month, day.day, 8, 0),
      end: DateTime(day.year, day.month, day.day, 18, 0),
      childActionIds: const [3, 2],
    );
    final c1 = sampleAction(
      id: 2,
      name: 'First',
      start: DateTime(day.year, day.month, day.day, 9, 0),
      end: DateTime(day.year, day.month, day.day, 10, 0),
    );
    final c2 = sampleAction(
      id: 3,
      name: 'Second',
      start: DateTime(day.year, day.month, day.day, 11, 0),
      end: DateTime(day.year, day.month, day.day, 12, 0),
    );
    final rows = foldDayActions([p, c1, c2]);
    expect(rows.length, 1);
    expect(rows.single.umbrella.id, 1);
    expect(rows.single.children.map((c) => c.id).toList(), [2, 3]);
  });

  test('child claimed by two parents → smallest parent id wins', () {
    final p10 = sampleAction(
      id: 10,
      name: 'P10',
      start: DateTime(day.year, day.month, day.day, 8, 0),
      end: DateTime(day.year, day.month, day.day, 12, 0),
      childActionIds: const [5],
    );
    final p20 = sampleAction(
      id: 20,
      name: 'P20',
      start: DateTime(day.year, day.month, day.day, 8, 0),
      end: DateTime(day.year, day.month, day.day, 12, 0),
      childActionIds: const [5],
    );
    final child = sampleAction(
      id: 5,
      name: 'Shared',
      start: DateTime(day.year, day.month, day.day, 9, 0),
      end: DateTime(day.year, day.month, day.day, 10, 0),
    );
    final rows = foldDayActions([p10, p20, child]);
    final row10 = rows.firstWhere((r) => r.umbrella.id == 10);
    final row20 = rows.firstWhere((r) => r.umbrella.id == 20);
    expect(row10.children.map((c) => c.id).toList(), [5]);
    expect(row20.children, isEmpty);
  });

  test('children in day without parent in day → each child is its own top-level row', () {
    final c1 = sampleAction(
      id: 2,
      name: 'Orphan A',
      start: DateTime(day.year, day.month, day.day, 9, 0),
      end: DateTime(day.year, day.month, day.day, 10, 0),
    );
    final c2 = sampleAction(
      id: 3,
      name: 'Orphan B',
      start: DateTime(day.year, day.month, day.day, 11, 0),
      end: DateTime(day.year, day.month, day.day, 12, 0),
    );
    final rows = foldDayActions([c1, c2]);
    expect(rows.length, 2);
    expect(rows.every((r) => r.children.isEmpty), isTrue);
  });

  test('mutual links collapse to one directed umbrella by time/type tie-break', () {
    final goto = sampleAction(
      id: 72,
      name: 'Goto Starbucks (demo)',
      modelTypeName: 'Goto',
      start: DateTime(day.year, day.month, day.day, 15, 0),
      end: DateTime(day.year, day.month, day.day, 15, 45),
      childActionIds: const [73],
    );
    final meet = sampleAction(
      id: 73,
      name: 'Coffee with Sarah (demo)',
      modelTypeName: 'Meet',
      start: DateTime(day.year, day.month, day.day, 15, 0),
      end: DateTime(day.year, day.month, day.day, 15, 45),
      childActionIds: const [72],
    );

    final rows = foldDayActions([goto, meet]);
    expect(rows.length, 1);
    expect(rows.single.umbrella.id, 72);
    expect(rows.single.children.map((c) => c.id).toList(), [73]);
  });
}
