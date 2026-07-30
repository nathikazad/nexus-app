import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_notes/composition/app_version_provider.dart';
import 'package:nx_notes/composition/offline_providers.dart';
import 'package:nx_notes/core/theme/app_theme.dart';
import 'package:nx_notes/core/version/app_version_info.dart';
import 'package:nx_notes/data/document/fake_document_repository.dart';
import 'package:nx_notes/data/providers.dart';
import 'package:nx_notes/data/remote/repository_notes_remote_api.dart';
import 'package:nx_notes/data/remote/fake/fake_notes_remote_api.dart';
import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/features/settings/notes_settings_button.dart';
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
    expect(find.text('Sync now'), findsOneWidget);
    expect(find.text('Version 0.1.0 (2)'), findsOneWidget);
    expect(find.text('Shorebird patch 7'), findsOneWidget);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(find.text('dark'), findsOneWidget);

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

    await tester.tap(find.byKey(const Key('sync-now-button')));
    await tester.pumpAndSettle();

    expect(refreshes, 1);
    expect(find.text('Library refreshed.'), findsOneWidget);
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
          notesRemoteApiProvider.overrideWithValue(
            RepositoryNotesRemoteApi(
              repository: repository,
              syncTransport: FakeNotesRemoteApi(),
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: NotesSettingsButton())),
      ),
    );
    await tester.tap(find.byKey(const Key('notes-settings-button')));
    await tester.pumpAndSettle();
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
        NotesSettingsButton(onSyncNow: onSyncNow),
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
