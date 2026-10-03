import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/data/calendar/kgql_calendar_repository.dart';
import 'package:nx_time/domain/calendar/calendar_entry.dart';
import 'package:nx_time/features/calendar/calendar_providers.dart';

final calendarHistoryProvider = NotifierProvider<CalendarHistory, bool>(
  CalendarHistory.new,
);

class CalendarHistory extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}

final calendarRepositoryProvider = FutureProvider<KgqlCalendarRepository>((
  ref,
) async {
  final user = await ref.watch(authenticatedUserProvider.future);
  final domain = user.domainId;
  if (domain == null) {
    throw StateError('Select a domain before loading the calendar');
  }
  return KgqlCalendarRepository(
    ref.watch(graphqlClientProvider),
    domainId: domain,
  );
});
final calendarFeedProvider = FutureProvider.autoDispose<CalendarFeed>((
  ref,
) async {
  final repo = await ref.watch(calendarRepositoryProvider.future);
  final monday = ref.watch(currentWeekProvider);
  final actual = ref.watch(calendarHistoryProvider);
  return repo.load(
    monday,
    DateTime(monday.year, monday.month, monday.day + 7),
    actualHistory: actual,
  );
});

final calendarRefreshProvider = Provider<Object>((ref) => Object());
