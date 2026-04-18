import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/features/calendar/calendar_view_model.dart';

void main() {
  test('CalendarViewModel holds focused day', () {
    final d = DateTime(2026, 4, 18);
    final vm = CalendarViewModel(focusedDay: d);
    expect(vm.focusedDay, d);
    expect(vm.copyWith(focusedDay: DateTime(2026, 5, 1)).focusedDay, DateTime(2026, 5, 1));
  });
}
