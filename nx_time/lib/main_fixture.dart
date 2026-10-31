import 'package:nx_time/features/schedule/schedule_page.dart';
import 'package:nx_db/account.dart';
// Development-only launcher: real app and live local fixture database.
// flutter run -t lib/main_fixture.dart -d <simulator>
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_time/app.dart';
import 'package:nx_time/data/domains/domain_workspace.dart';
import 'package:nx_time/features/calendar/calendar_providers.dart';
import 'package:nx_time/features/goals/goals_page.dart';

class FixtureAuth extends AuthController {
  @override
  Future<User?> build() async => User(
    userId: '810001',
    preset: BackendPreset.localhost,
    domainId: 43,
    domainName: 'Routine fixture',
  );
}

class FixtureDomains extends TimeDomains {
  @override
  Future<DomainWorkspace> build() async {
    final user = (await ref.watch(authProvider.future))!;
    final client = createClient(
      'http://127.0.0.1:55440/graphql',
      user.userId,
      domainId: 43,
      preset: BackendPreset.localhost,
      auditSourceKind: 'nx_time_fixture',
    );
    final w = DomainWorkspace(
      user: user,
      memberships: const [
        DomainMembership(
          id: 43,
          name: 'Routine fixture',
          role: 'owner',
          kind: 'personal',
        ),
      ],
      personalId: 43,
      selectedIds: {43},
      clients: {43: client},
    );
    ref.onDispose(w.dispose);
    return w;
  }
}

class FixtureWeek extends CurrentWeek {
  @override
  DateTime build() => DateTime(2026, 6, 1);
}

void main() {
  if (!kDebugMode) {
    throw StateError('Fixture launcher is for local debug builds only');
  }
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(FixtureAuth.new),
        timeDomainsProvider.overrideWith(FixtureDomains.new),
        currentWeekProvider.overrideWith(FixtureWeek.new),
        scheduleInitialDateProvider.overrideWithValue(DateTime(2026, 6, 1)),
        goalsInitialMonthProvider.overrideWithValue(DateTime(2026, 6)),
        graphqlClientProvider.overrideWith((ref) {
          final w = ref.watch(timeDomainsProvider).requireValue;
          return w.clients[w.selectedId]!;
        }),
        authenticatedUserProvider.overrideWith(
          (ref) async => (await ref.watch(timeDomainsProvider.future)).user,
        ),
        dbAuditSourceKindProvider.overrideWithValue('nx_time_fixture'),
        nexusClientAppIdProvider.overrideWithValue('nx_time'),
      ],
      child: const NexusTimeApp(initialTabIndex: 3),
    ),
  );
}
