import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_people/app.dart';
import 'package:nx_people/data/auth/people_auth_controller.dart';
import 'package:nx_people/data/providers.dart';
import 'package:nx_people/data/fake_people_repository.dart';
import 'package:nx_people/features/shell/people_state.dart';

class TestAuth extends PeopleAuthController {
  TestAuth(this.ready);
  final Completer<User?> ready;
  @override
  Future<User?> build() => ready.future;
  void useDomain(int? id) => state = AsyncData(
    User(userId: '1', preset: BackendPreset.hosted, domainId: id),
  );
  @override
  Future<void> selectDomain(int id) async => useDomain(id);
}

void main() {
  testWidgets('no data access during restoration or before domain selection', (
    tester,
  ) async {
    final ready = Completer<User?>();
    final auth = TestAuth(ready);
    var repositoryBuilds = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => auth),
          domainLoaderProvider.overrideWithValue(
            (_) async => [
              const DomainMembership(id: 1, name: 'Personal', role: 'owner'),
              const DomainMembership(id: 2, name: 'Home', role: 'member'),
            ],
          ),
          peopleRepositoryProvider.overrideWith((ref) {
            repositoryBuilds++;
            return FakePeopleRepository();
          }),
        ],
        child: const NexusPeopleApp(),
      ),
    );
    await tester.pump();
    expect(repositoryBuilds, 0);
    ready.complete(User(userId: '1', preset: BackendPreset.hosted));
    await tester.pumpAndSettle();
    expect(find.text('Choose a domain'), findsOneWidget);
    expect(repositoryBuilds, 0);
    await tester.tap(find.text('Personal'));
    await tester.pumpAndSettle();
    expect(repositoryBuilds, 1);
    expect(find.text('Choose a domain'), findsNothing);
    auth.useDomain(null);
    await tester.pumpAndSettle();
    expect(find.text('Choose a domain'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('workspace selection and search reset when domain changes', () async {
    final ready = Completer<User?>();
    final auth = TestAuth(ready);
    final container = ProviderContainer(
      overrides: [authProvider.overrideWith(() => auth)],
    );
    addTearDown(container.dispose);
    ready.complete(
      User(userId: '1', preset: BackendPreset.hosted, domainId: 1),
    );
    await container.read(authProvider.future);
    final workspace = container.read(peopleWorkspaceProvider.notifier);
    workspace.openPerson(123);
    workspace.setSearchText('private contact');
    auth.useDomain(2);
    expect(container.read(peopleWorkspaceProvider).activePersonId, isNull);
    expect(container.read(peopleWorkspaceProvider).searchText, isEmpty);
  });
}
