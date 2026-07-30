import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_notes/app.dart';
import 'package:nx_notes/application/native/background_uploader.dart';
import 'package:nx_notes/application/native/native_notes_workspace.dart';
import 'package:nx_notes/application/ports/clock.dart';
import 'package:nx_notes/application/ports/id_generator.dart';
import 'package:nx_notes/application/ports/session_store.dart';
import 'package:nx_notes/composition/offline_providers.dart';
import 'package:nx_notes/data/local/memory/memory_local_notes_store.dart';
import 'package:nx_notes/data/remote/unavailable/unavailable_notes_remote_api.dart';
import 'package:nx_notes/data/session/preferences_last_opened_document_store.dart';
import 'package:nx_notes/domain/catalog/catalog_query.dart';
import 'package:nx_notes/domain/document/document_identity.dart';
import 'package:nx_notes/domain/document/document_summary.dart';
import 'package:nx_notes/domain/sync/document_revision.dart';
import 'package:nx_notes/domain/sync/remote_document.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/offline_fixtures.dart';

void main() {
  testWidgets('mobile offline restart shows the cached document library', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    const session = CachedSession(
      userId: 'user-1',
      backendPreset: 'production',
    );
    final lastOpened = PreferencesLastOpenedDocumentStore(
      await SharedPreferences.getInstance(),
    );
    await lastOpened.save(session.accountKey, 7);

    final store = MemoryLocalNotesStore(accountKey: session.accountKey);
    final uploader = BackgroundUploader(
      localStore: store,
      remoteApi: const UnavailableNotesRemoteApi(),
      clock: const _Clock(),
      workerId: 'widget-test',
      uploadDelay: const Duration(hours: 1),
    );
    final workspace = NativeNotesWorkspace(
      localStore: store,
      remoteApi: const UnavailableNotesRemoteApi(),
      uploader: uploader,
      clock: const _Clock(),
      idGenerator: _Ids(),
    );
    addTearDown(workspace.close);
    addTearDown(uploader.close);
    addTearDown(store.dispose);
    final cached = offlineTestDocument(
      id: 7,
      title: 'Restarted offline',
      body: 'This document came from the local database.',
    ).copyWith(jsonDocument: const <String, dynamic>{});
    await store.importRemoteDocuments(<RemoteDocument>[
      RemoteDocument(
        key: const DocumentKey(localId: 'remote-7', remoteId: 7),
        document: cached,
        revision: const RemoteRevision('rev-7'),
      ),
    ]);
    await store.replaceCatalog(const CatalogQuery.recent(), <DocumentSummary>[
      DocumentSummary.fromDocument(cached),
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

    expect(find.text('nx_notes'), findsOneWidget);
    expect(find.text('Docs'), findsOneWidget);
    expect(find.text('Search documents...'), findsOneWidget);
    expect(find.text('Restarted offline'), findsOneWidget);
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
  String nextId() => 'test-${value++}';
}
