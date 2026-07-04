@Tags(['widget'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/features/shell/app_shell.dart';
import 'package:nx_time/features/today/today_view_model.dart';

import '../_support/fake_action_repository.dart';
import '../_support/fake_log_repository.dart';
import '../_support/pump_app.dart';

class _AuthLoggedIn extends AuthController {
  _AuthLoggedIn() : super(initialDelay: Duration.zero, skipBackendPing: true);

  @override
  Future<User?> build() async =>
      User(userId: '1', preset: BackendPreset.localhost);
}

void main() {
  testWidgets('calendar tab is labeled Weekly', (tester) async {
    await pumpAppWith(
      tester,
      child: const AppShell(initialTabIndex: 3),
      overrides: [
        authProvider.overrideWith(_AuthLoggedIn.new),
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
        todaySnapshotProvider.overrideWith(
          (ref) =>
              AsyncValue.data(buildTodaySnapshot(const [], DateTime.now())),
        ),
      ],
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Weekly'), findsAtLeastNWidgets(2));
    expect(find.text('Calendar'), findsNothing);
  });
}
