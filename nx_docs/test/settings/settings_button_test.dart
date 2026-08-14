import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_docs/app/version_provider.dart';
import 'package:nx_docs/sync/sync_providers.dart';
import 'package:nx_docs/app/theme.dart';
import 'package:nx_docs/app/version_info.dart';
import 'package:nx_docs/documents/data/fake/fake_document_repository.dart';
import 'package:nx_docs/documents/document_data_providers.dart';
import 'package:nx_docs/sync/remote/repository_document_remote_api.dart';
import 'package:nx_docs/sync/fake/fake_document_remote_api.dart';
import 'package:nx_docs/documents/document_models.dart';
import 'package:nx_docs/documents/editor/document_text_scale.dart';
import 'package:nx_docs/settings/settings_button.dart';
import 'package:nx_offline/nx_offline.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('settings dialog changes theme and synchronizes the library', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      AppDarkModeNotifier.preferenceKey: false,
    });
    var refetches = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appVersionInfoProvider.overrideWith(
            (ref) async =>
                const AppVersionInfo(shorebirdAvailable: true, patchNumber: 7),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: _SettingsHarness(
              onSyncNow: () async {
                refetches++;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('light'), findsOneWidget);
    await tester.tap(find.byKey(const Key('notes-settings-button')));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('Document text'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Sync now'), findsOneWidget);
    expect(find.text('Version 0.1.0 (3)'), findsOneWidget);
    expect(find.text('Shorebird patch 7'), findsOneWidget);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(find.text('dark'), findsOneWidget);

    await tester.tap(find.byKey(const Key('document-text-larger')));
    await tester.pumpAndSettle();
    expect(find.text('110%'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getDouble(DocumentTextScaleNotifier.preferenceKey), 1.1);

    await tester.ensureVisible(find.byKey(const Key('sync-now-button')));
    await tester.tap(find.byKey(const Key('sync-now-button')));
    await tester.pumpAndSettle();

    expect(refetches, 1);
    expect(find.text('Library synchronized.'), findsOneWidget);
  });

  testWidgets('web settings presents a server library refresh', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      AppDarkModeNotifier.preferenceKey: false,
    });
    var refreshes = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          offlineEnabledProvider.overrideWithValue(false),
          appVersionInfoProvider.overrideWith(
            (ref) async => const AppVersionInfo(shorebirdAvailable: false),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: _SettingsHarness(
              onSyncNow: () async {
                refreshes++;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('notes-settings-button')));
    await tester.pumpAndSettle();

    expect(find.text('Offline library'), findsNothing);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Refresh library'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('sync-now-button')));
    await tester.tap(find.byKey(const Key('sync-now-button')));
    await tester.pumpAndSettle();

    expect(refreshes, 1);
    expect(find.text('Library refreshed.'), findsOneWidget);
  });

  testWidgets('sync button is disabled while another sync is running', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      AppDarkModeNotifier.preferenceKey: false,
    });
    final statuses = StreamController<SyncStatus>(sync: true);
    addTearDown(statuses.close);
    var refetches = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentSyncStatusProvider.overrideWith((ref) => statuses.stream),
          appVersionInfoProvider.overrideWith(
            (ref) async => const AppVersionInfo(shorebirdAvailable: false),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: _SettingsHarness(onSyncNow: () async => refetches++),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('notes-settings-button')));
    await tester.pumpAndSettle();
    statuses.add(
      const SyncStatus(activity: SyncActivity.syncing, pendingCount: 1),
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('sync-now-button')));

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('sync-now-button')),
    );
    expect(button.onPressed, isNull);
    expect(find.text('Synchronizing…'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sync-now-button')));
    await tester.pump();
    expect(refetches, 0);
  });

  testWidgets('default web refresh reads the server repository', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      AppDarkModeNotifier.preferenceKey: false,
    });
    final repository = _TrackingDocumentRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          offlineEnabledProvider.overrideWithValue(false),
          appVersionInfoProvider.overrideWith(
            (ref) async => const AppVersionInfo(shorebirdAvailable: false),
          ),
          documentRepositoryProvider.overrideWithValue(repository),
          documentRemoteApiProvider.overrideWithValue(
            RepositoryDocumentRemoteApi(
              repository: repository,
              syncTransport: FakeDocumentRemoteApi(),
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: DocsSettingsButton())),
      ),
    );
    await tester.tap(find.byKey(const Key('notes-settings-button')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('sync-now-button')));
    await tester.tap(find.byKey(const Key('sync-now-button')));
    await tester.pumpAndSettle();

    expect(repository.listAllCalls, 1);
    expect(find.text('Library refreshed.'), findsOneWidget);
  });
}

class _SettingsHarness extends ConsumerWidget {
  const _SettingsHarness({required this.onSyncNow});

  final LibrarySyncCallback onSyncNow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(appDarkModeProvider);
    return Column(
      children: <Widget>[
        Text(isDark ? 'dark' : 'light'),
        DocsSettingsButton(onSyncNow: onSyncNow),
      ],
    );
  }
}

class _TrackingDocumentRepository extends FakeDocumentRepository {
  var listAllCalls = 0;

  @override
  Future<List<NxDocument>> listAll() {
    listAllCalls++;
    return super.listAll();
  }
}
