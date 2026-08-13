import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_docs/app.dart';
import 'package:nx_docs/application/native/background_uploader.dart';
import 'package:nx_docs/application/native/native_notes_workspace.dart';
import 'package:nx_docs/application/ports/clock.dart';
import 'package:nx_docs/application/ports/id_generator.dart';
import 'package:nx_docs/application/ports/session_store.dart';
import 'package:nx_docs/application/sync/document_synchronizer.dart';
import 'package:nx_docs/composition/offline_providers.dart';
import 'package:nx_docs/data/local/memory/memory_local_notes_store.dart';
import 'package:nx_docs/data/remote/unavailable/unavailable_notes_remote_api.dart';
import 'package:nx_docs/data/session/preferences_last_opened_document_store.dart';
import 'package:nx_docs/domain/catalog/catalog_query.dart';
import 'package:nx_docs/domain/document/document_identity.dart';
import 'package:nx_docs/domain/document/document_summary.dart';
import 'package:nx_docs/domain/sync/document_revision.dart';
import 'package:nx_docs/domain/sync/remote_document.dart';
import 'package:nx_docs/features/desktop/desktop_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/offline_fixtures.dart';

void main() {
  testWidgets('desktop restart exposes the downloaded library offline', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    tester.platformDispatcher.textScaleFactorTestValue = 0.95;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    const session = CachedSession(
      userId: 'desktop-user',
      backendPreset: 'production',
    );
    final lastOpened = PreferencesLastOpenedDocumentStore(
      await SharedPreferences.getInstance(),
    );
    await lastOpened.save(session.accountKey, 18);

    final store = MemoryLocalNotesStore(accountKey: session.accountKey);
    final uploader = BackgroundUploader(
      localStore: store,
      remoteApi: const UnavailableNotesRemoteApi(),
      clock: const _Clock(),
      workerId: 'desktop-widget-test',
      uploadDelay: const Duration(hours: 1),
    );
    final workspace = NativeNotesWorkspace(
      localStore: store,
      remoteApi: const UnavailableNotesRemoteApi(),
      uploader: uploader,
      synchronizer: DocumentSynchronizer(
        localStore: store,
        remoteApi: const UnavailableNotesRemoteApi(),
        uploader: uploader,
      ),
      clock: const _Clock(),
      idGenerator: _Ids(),
    );
    addTearDown(workspace.close);
    addTearDown(uploader.close);
    addTearDown(store.dispose);
    final first = offlineTestDocument(
      id: 17,
      title: 'Desktop restart offline',
      body: 'This desktop document came from the local database.',
    ).copyWith(jsonDocument: const <String, dynamic>{});
    final second = offlineTestDocument(
      id: 18,
      title: 'Another persistent document',
      body: 'A second document is available without the network.',
      updatedAt: DateTime.utc(2026, 7, 20),
    ).copyWith(jsonDocument: const <String, dynamic>{});
    await store.importRemoteDocuments(<RemoteDocument>[
      RemoteDocument(
        key: const DocumentKey(localId: 'remote-17', remoteId: 17),
        document: first,
        revision: const RemoteRevision('rev-17'),
      ),
      RemoteDocument(
        key: const DocumentKey(localId: 'remote-18', remoteId: 18),
        document: second,
        revision: const RemoteRevision('rev-18'),
      ),
    ]);
    await store.replaceCatalog(const CatalogQuery.recent(), <DocumentSummary>[
      DocumentSummary.fromDocument(first),
      DocumentSummary.fromDocument(second),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(
            () => AuthController(
              initialDelay: Duration.zero,
              skipBackendPing: true,
            ),
          ),
          activeOfflineSessionProvider.overrideWith((ref) async => session),
          notesWorkspaceProvider.overrideWithValue(workspace),
          backgroundUploaderProvider.overrideWithValue(uploader),
        ],
        child: const NexusNotesApp(),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.byType(DesktopShell), findsOneWidget);
    expect(find.text('Desktop restart offline'), findsWidgets);
    expect(find.text('Another persistent document'), findsWidgets);
    await tester.tap(find.text('Another persistent document').first);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(
      find.textContaining('second document', findRichText: true),
      findsOneWidget,
    );
  });
}

class _Clock implements Clock {
  const _Clock();

  @override
  DateTime now() => DateTime.utc(2026, 7, 21);
}

class _Ids implements IdGenerator {
  var value = 0;

  @override
  String nextId() => 'desktop-test-${value++}';
}
