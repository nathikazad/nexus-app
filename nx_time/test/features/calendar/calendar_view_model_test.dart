import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/features/calendar/calendar_view_model.dart';

void main() {
  test('calendarWeekProvider is a Riverpod provider', () {
    expect(
      calendarWeekProvider,
      isA<Provider<AsyncValue<List<CalendarDayData>>>>(),
    );
  });
}
