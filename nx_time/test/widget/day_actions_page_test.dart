@Tags(['widget'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/domain/action/action.dart' as domain;
import 'package:nx_time/domain/log/daily_log.dart';
import 'package:nx_time/features/today/day_actions_page.dart';

import '../_support/fake_action_repository.dart';
import '../_support/fake_log_repository.dart';
import '../_support/pump_app.dart';

void main() {
  testWidgets('day actions page renders selected date rows', (tester) async {
    final day = DateTime(2026, 4, 18);
    final action = domain.Action(
      id: 1,
      name: 'Morning run',
      modelTypeId: 10,
      modelTypeName: 'Run',
      startTime: DateTime(2026, 4, 18, 9),
      endTime: DateTime(2026, 4, 18, 10),
    );
    final log = DailyLog(
      id: 2,
      modelTypeId: 20,
      loggedAt: DateTime(2026, 4, 18, 11),
      entry: 'Felt good after the run',
    );

    await pumpAppWith(
      tester,
      child: DayActionsPage(date: day),
      overrides: [
        authenticatedUserProvider.overrideWith(
          (ref) async => User(userId: '1', preset: BackendPreset.localhost),
        ),
        actionRepositoryProvider.overrideWith(
          (ref) => FakeActionRepository(initial: [action]),
        ),
        logRepositoryProvider.overrideWith(
          (ref) => FakeLogRepository(initial: [log]),
        ),
        modelTypeColorsProvider.overrideWith(
          (ref) async => ModelTypeColors.fallback,
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Actions'), findsOneWidget);
    expect(find.text(DateFormat('EEEE, MMM d').format(day)), findsOneWidget);
    expect(find.text('Morning run'), findsOneWidget);
    expect(find.text('Felt good after the run'), findsOneWidget);
  });

  testWidgets('day actions page renders empty state', (tester) async {
    final day = DateTime(2026, 4, 19);

    await pumpAppWith(
      tester,
      child: DayActionsPage(date: day),
      overrides: [
        authenticatedUserProvider.overrideWith(
          (ref) async => User(userId: '1', preset: BackendPreset.localhost),
        ),
        actionRepositoryProvider.overrideWith(
          (ref) => FakeActionRepository(initial: const []),
        ),
        logRepositoryProvider.overrideWith(
          (ref) => FakeLogRepository(initial: const []),
        ),
        modelTypeColorsProvider.overrideWith(
          (ref) async => ModelTypeColors.fallback,
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text(DateFormat('EEEE, MMM d').format(day)), findsOneWidget);
    expect(find.text('No actions or logs'), findsOneWidget);
  });
}
