import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_time/core/time/week_calendar.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/domain/action/action.dart';
import 'package:nx_time/features/calendar/calendar_providers.dart';

import '../../_support/fake_action_repository.dart';
import '../../_support/riverpod_helpers.dart';

class _ListForWeekCounter extends FakeActionRepository {
  _ListForWeekCounter() : super(initial: const []);

  int listForWeekCount = 0;

  @override
  Future<List<Action>> listForWeek(DateTime mondayLocal) async {
    listForWeekCount++;
    return super.listForWeek(mondayLocal);
  }
}

void main() {
  test('currentWeekProvider starts at this week\'s Monday (local date)', () {
    final c = makeContainer();
    addTearDown(c.dispose);
    final mon = c.read(currentWeekProvider);
    final expected = mondayOfWeek(DateTime.now());
    expect(
      DateTime(mon.year, mon.month, mon.day),
      DateTime(expected.year, expected.month, expected.day),
    );
  });

  test('weekActionsProvider refetches on invalidateActionsAfterMutation', () async {
    final counter = _ListForWeekCounter();
    final c = makeContainer(
      overrides: [
        authenticatedUserProvider.overrideWith(
          (ref) async => User(
            userId: '1',
            preset: BackendPreset.localhost,
          ),
        ),
        modelTypeColorsProvider.overrideWith(
          (ref) async => ModelTypeColors.fallback,
        ),
        actionRepositoryProvider.overrideWith((ref) => counter),
      ],
    );
    addTearDown(c.dispose);
    expect(counter.listForWeekCount, 0);
    final mon = c.read(currentWeekProvider);
    final m0 = DateTime(mon.year, mon.month, mon.day);
    await c.read(weekActionsProvider(m0).future);
    expect(counter.listForWeekCount, 1);
    c.invalidate(weekActionsProvider);
    c.invalidate(actionGoalsWeekProvider);
    await c.read(weekActionsProvider(m0).future);
    expect(counter.listForWeekCount, 2);
  });

  test('weekActionsProvider refetches when currentWeekProvider changes', () async {
    final counter = _ListForWeekCounter();
    final c = makeContainer(
      overrides: [
        authenticatedUserProvider.overrideWith(
          (ref) async => User(
            userId: '1',
            preset: BackendPreset.localhost,
          ),
        ),
        modelTypeColorsProvider.overrideWith(
          (ref) async => ModelTypeColors.fallback,
        ),
        actionRepositoryProvider.overrideWith((ref) => counter),
      ],
    );
    addTearDown(c.dispose);
    var mon = c.read(currentWeekProvider);
    var m0 = DateTime(mon.year, mon.month, mon.day);
    await c.read(weekActionsProvider(m0).future);
    expect(counter.listForWeekCount, 1);
    mon = c.read(currentWeekProvider);
    m0 = DateTime(mon.year, mon.month, mon.day);
    c.read(currentWeekProvider.notifier).setLocalWeekMonday(
          m0.subtract(const Duration(days: 7)),
        );
    mon = c.read(currentWeekProvider);
    m0 = DateTime(mon.year, mon.month, mon.day);
    await c.read(weekActionsProvider(m0).future);
    expect(counter.listForWeekCount, 2);
  });
}
