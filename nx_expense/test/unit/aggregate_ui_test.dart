import 'package:flutter_test/flutter_test.dart';
import 'package:nx_expense/util/expense_schema.dart';

void main() {
  test('parseDaySpendEntries reads backend "key" bucket (group by day)', () {
    final raw = <String, dynamic>{
      'grouped': [
        {'key': '2025-01-01T00:00:00', 'aggregated_value': 163},
        {'key': '2025-01-02T00:00:00', 'aggregated_value': 299},
      ],
    };
    final entries = parseDaySpendEntries(raw);
    expect(entries.length, 2);
    expect(entries[0].key, '2025-01-01T00:00:00');
    expect(entries[0].value, 163);
    expect(entries[1].value, 299);
  });

  test('parseDaySpendEntries reads grouped "date" key (Expense date attribute)', () {
    final raw = <String, dynamic>{
      'grouped': [
        {'key': '2026-04-01', 'aggregated_value': 42},
        {'key': '2026-04-02', 'aggregated_value': 10},
      ],
    };
    final entries = parseDaySpendEntries(raw);
    expect(entries.length, 2);
    expect(entries[0].key, '2026-04-01');
    expect(entries[0].value, 42);
  });
}
