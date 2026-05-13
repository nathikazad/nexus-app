import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/nx_db.dart';
import 'package:nx_expense/core/formatting/format.dart';
import 'package:nx_expense/domain/transfer/transfer.dart';
import 'package:nx_expense/data/schema/kgql_schema_helpers.dart';

void main() {
  group('formatModelDate', () {
    test(
      'UTC Z midnight formats same calendar day as plain YMD (no local shift)',
      () {
        expect(
          formatModelDate('2026-04-01T00:00:00.000Z'),
          formatModelDate('2026-04-01'),
          reason:
              'regression: April 1 UTC must not display as March 31 in western zones',
        );
      },
    );

    test('plain YYYY-MM-DD is stable', () {
      expect(formatModelDate('2026-03-31'), isNot('—'));
      expect(formatModelDate('2026-03-31'), contains('2026'));
    });
  });

  group('normalizeDateAttributeSortKey', () {
    test('passes through plain YMD', () {
      expect(normalizeDateAttributeSortKey('2026-04-15'), '2026-04-15');
    });

    test('Z ISO maps to UTC calendar YMD', () {
      expect(
        normalizeDateAttributeSortKey('2026-04-01T00:00:00.000Z'),
        '2026-04-01',
      );
    });
  });

  group('formatDisplayAttributeValue', () {
    test('datetime uses date-only path', () {
      expect(
        formatDisplayAttributeValue('2026-04-01T00:00:00.000Z', 'datetime'),
        formatModelDate('2026-04-01T00:00:00.000Z'),
      );
    });

    test('boolean', () {
      expect(formatDisplayAttributeValue(true, 'boolean'), 'Yes');
      expect(formatDisplayAttributeValue(false, 'boolean'), 'No');
    });
  });

  group('initialDateForYmdOrIso', () {
    test('Z midnight uses UTC calendar for picker seed', () {
      final d = initialDateForYmdOrIso('2026-04-01T00:00:00.000Z');
      expect(d.year, 2026);
      expect(d.month, 4);
      expect(d.day, 1);
    });
  });

  group('modelDateCellLabel / modelDateSortKey', () {
    test('prefers date attribute over createdAt', () {
      final m = Model.fromJson({
        'id': 1,
        'name': 'E',
        'model_type_id': 1,
        'created_at': '2020-01-01T12:00:00Z',
        'attributes': {'date': '2026-03-15'},
      });
      expect(modelDateCellLabel(m), formatModelDate('2026-03-15'));
      expect(modelDateSortKey(m), '2026-03-15');
    });

    test('falls back to createdAt when no date', () {
      final m = Model.fromJson({
        'id': 1,
        'name': 'E',
        'model_type_id': 1,
        'created_at': '2026-02-01T00:00:00Z',
      });
      expect(modelDateSortKey(m), '2026-02-01T00:00:00Z');
    });
  });

  group('sortModelsByDateDesc', () {
    test('orders by date attribute when present', () {
      final a = Model.fromJson({
        'id': 1,
        'name': 'a',
        'model_type_id': 1,
        'attributes': {'date': '2026-01-01'},
      });
      final b = Model.fromJson({
        'id': 2,
        'name': 'b',
        'model_type_id': 1,
        'attributes': {'date': '2026-06-01'},
      });
      final out = sortModelsByDateDesc([a, b]);
      expect(out.map((m) => m.id), [2, 1]);
    });
  });

  group('transferCellDateLabel', () {
    test('matches modelDateCellLabel for same date attrs', () {
      const t = Transfer(
        id: 1,
        name: 'T',
        modelTypeId: 1,
        attributes: {'date': '2026-05-01'},
      );
      expect(transferCellDateLabel(t), modelDateCellLabel(t));
    });
  });
}
