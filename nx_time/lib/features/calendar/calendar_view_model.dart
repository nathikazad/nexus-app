/// Placeholder for future Riverpod-backed calendar tab state. [CalendarPage]
/// still uses local [State]; this type documents the intended seam.
class CalendarViewModel {
  const CalendarViewModel({required this.focusedDay});

  final DateTime focusedDay;

  CalendarViewModel copyWith({DateTime? focusedDay}) {
    return CalendarViewModel(focusedDay: focusedDay ?? this.focusedDay);
  }
}
