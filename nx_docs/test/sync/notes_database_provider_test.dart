import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_docs/account/account_session.dart';
import 'package:nx_docs/account/account_providers.dart';
import 'package:nx_docs/sync/sync_providers.dart';
import 'package:nx_docs/sync/native/drift_local_notes_store.dart';
import 'package:nx_docs/sync/native/notes_database.dart';

void main() {
  test('reuses one database while the same account session rebuilds', () async {
    const session = CachedSession(userId: '1', backendPreset: 'pi_tailscale');
    var databaseCreations = 0;
    final container = ProviderContainer(
      overrides: [
        activeOfflineSessionProvider.overrideWith((ref) async => session),
        notesDatabaseProvider.overrideWith((ref, accountKey) {
          databaseCreations++;
          final database = NotesDatabase(NativeDatabase.memory());
          ref.onDispose(database.close);
          return database;
        }),
      ],
    );
    addTearDown(container.dispose);

    await container.read(activeOfflineSessionProvider.future);
    final first =
        container.read(localNotesStoreProvider) as DriftLocalNotesStore;
    container.invalidate(activeOfflineSessionProvider);
    await container.read(activeOfflineSessionProvider.future);
    final second =
        container.read(localNotesStoreProvider) as DriftLocalNotesStore;

    expect(identical(first.database, second.database), isTrue);
    expect(databaseCreations, 1);
  });

  test('account switching selects an isolated sync database', () async {
    var session = const CachedSession(userId: '1', backendPreset: 'pi_wan');
    var databaseCreations = 0;
    final container = ProviderContainer(
      overrides: [
        activeOfflineSessionProvider.overrideWith((ref) async => session),
        notesDatabaseProvider.overrideWith((ref, accountKey) {
          databaseCreations++;
          final database = NotesDatabase(NativeDatabase.memory());
          ref.onDispose(database.close);
          return database;
        }),
      ],
    );
    addTearDown(container.dispose);

    await container.read(activeOfflineSessionProvider.future);
    final first = container.read(localNotesStoreProvider)!;
    session = const CachedSession(userId: '2', backendPreset: 'pi_wan');
    container.invalidate(activeOfflineSessionProvider);
    await container.read(activeOfflineSessionProvider.future);
    final second = container.read(localNotesStoreProvider)!;

    expect(first.accountKey, 'user:1');
    expect(second.accountKey, 'user:2');
    expect(identical(first, second), isFalse);
    expect(databaseCreations, 2);
  });
}
