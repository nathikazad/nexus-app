// Local simulator preview. No account, credentials, or production data is used.
// Run: flutter run -t tool/responsive_preview.dart -d <simulator-id>
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_docs/account/account_providers.dart';
import 'package:nx_docs/app/theme.dart';
import 'package:nx_docs/documents/data/fake/fake_document_repository.dart';
import 'package:nx_docs/documents/document_data_providers.dart';
import 'package:nx_docs/documents/editor/document_scroll_store.dart';
import 'package:nx_docs/sync/fake/fake_document_remote_api.dart';
import 'package:nx_docs/sync/remote/repository_document_remote_api.dart';
import 'package:nx_docs/sync/web/web_document_workspace.dart';
import 'package:nx_docs/workspace/workspace_page.dart';
import 'package:nx_docs/workspace/workspace_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppColors.isDark =
      WidgetsBinding.instance.platformDispatcher.platformBrightness ==
      Brightness.dark;
  final repository = FakeDocumentRepository();
  final sample = await repository.create(title: 'A little room to write');
  const body =
      '# Ideas, wherever you are\n\nA thought on your phone. A draft on your tablet. The same document, ready to keep going.\n\n## Try it out\n\nTap the title to rename this document, or tap a paragraph to start writing. Select some text to format it.\n\n- Create a new document from the library\n- Add a heading, image, or linked document with Insert\n- Open the details panel to organize your work\n\n## A quieter workspace\n\nYour writing gets the space it needs. Tools stay within reach, and details open when you need them.\n';
  final document = markdownToDocument(body);
  await repository.updateDraft(
    sample.copyWith(
      document: body,
      jsonDocument: {
        'format': 'appflowy_document',
        'document': document.toJson()['document'],
      },
      wordCount: 99,
    ),
  );
  final remote = RepositoryDocumentRemoteApi(
    repository: repository,
    syncTransport: FakeDocumentRemoteApi(),
  );
  final workspace = WebDocumentWorkspace(remoteApi: remote);
  final router = GoRouter(
    initialLocation: '/docs/${sample.id}',
    routes: [
      GoRoute(
        path: '/docs',
        pageBuilder: (_, _) => const NoTransitionPage<void>(
          key: ValueKey('notes-shell'),
          child: DocsWorkspacePage(),
        ),
      ),
      GoRoute(
        path: '/docs/:id',
        pageBuilder: (_, state) => NoTransitionPage<void>(
          key: const ValueKey('notes-shell'),
          child: DocsWorkspacePage(
            initialDocumentId: int.parse(state.pathParameters['id']!),
          ),
        ),
      ),
    ],
  );
  runApp(
    ProviderScope(
      overrides: [
        documentRepositoryProvider.overrideWithValue(repository),
        documentWorkspaceProvider.overrideWithValue(workspace),
        documentImageAssetServiceProvider.overrideWithValue(null),
        nxDocsStateServiceProvider.overrideWithValue(null),
        activeOfflineSessionProvider.overrideWith((_) async => null),
        documentScrollStoreProvider.overrideWithValue(
          const DocumentScrollStore('responsive-preview'),
        ),
      ],
      child: MaterialApp.router(
        title: 'NX Docs · Local preview',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        localizationsDelegates: const [
          AppFlowyEditorLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppFlowyEditorLocalizations.delegate.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
}
