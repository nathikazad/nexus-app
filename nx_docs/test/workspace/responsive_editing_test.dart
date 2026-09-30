import 'package:nx_db/auth.dart';
import 'package:nx_docs/documents/browser/document_browser_session.dart';
import 'package:nx_docs/documents/browser/document_browser.dart';
import 'package:nx_docs/documents/editor/document_editor_view.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/editor/editor_component/service/ime/delta_input_on_insert_impl.dart'
    as ime;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final width in [1100.0, 1440.0]) {
    testWidgets('browser hides inspector at width $width', (tester) async {
      await _pumpWorkspace(tester, width);
      if (width < 1280) {
        await tester.tap(find.byTooltip('Expand inspector'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Contents'), findsOneWidget);
      final host = find.byType(DocumentEditorView);
      final documentId = tester.widget<DocumentEditorView>(host).documentId;
      final container = ProviderScope.containerOf(tester.element(host));
      final browser = container.read(
        documentBrowserSessionProvider(documentId).notifier,
      );
      final before = tester.getSize(host).width;
      browser.open(Uri.parse('https://example.org/article'));
      await tester.pumpAndSettle();
      expect(find.text('Contents'), findsNothing);
      expect(find.byTooltip('Expand inspector'), findsNothing);
      expect(tester.getSize(host).width, greaterThan(before));
      browser.close();
      await tester.pumpAndSettle();
      expect(find.text('Contents'), findsOneWidget);
      expect(tester.getSize(host).width, before);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }

  testWidgets('compact inspector overlays without resizing the document', (
    tester,
  ) async {
    await _pumpWorkspace(tester, 1100);
    expect(find.byTooltip('Expand inspector'), findsOneWidget);
    expect(find.text('Contents'), findsNothing);
    final editor = find.byType(AppFlowyEditor);
    final before = tester.getRect(editor);
    await tester.tap(find.byTooltip('Expand inspector'));
    await tester.pumpAndSettle();
    expect(find.text('Contents'), findsOneWidget);
    expect(tester.getRect(editor), before);
    await tester.tap(find.byTooltip('Collapse inspector'));
    await tester.pumpAndSettle();
    expect(find.text('Contents'), findsNothing);
    expect(tester.getRect(editor), before);
    tester.view.physicalSize = const Size(1440, 1000);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Collapse inspector'), findsOneWidget);
    final dockedWidth = tester.getSize(editor).width;
    await tester.tap(find.byTooltip('Collapse inspector'));
    await tester.pumpAndSettle();
    expect(tester.getSize(editor).width, greaterThan(dockedWidth));
    tester.view.physicalSize = const Size(1100, 1000);
    await tester.pumpAndSettle();
    expect(find.text('Contents'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('wide layout has no Books tab and creates documents directly', (
    tester,
  ) async {
    await _pumpWorkspace(tester, 1440);
    expect(find.text('Books'), findsNothing);
    expect(find.text('Book'), findsNothing);
    await tester.tap(find.byTooltip('New document'));
    await tester.pumpAndSettle();
    expect(find.text('New book'), findsNothing);
    expect(find.byKey(const ValueKey('title-display-100')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('unified search retains text and combines with tag filters', (
    tester,
  ) async {
    await _pumpWorkspace(tester, 390);
    expect(find.text('Books'), findsNothing);
    expect(find.text('Tags'), findsNothing);
    await tester.enterText(find.byType(TextField), 'API');
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'API',
    );
    expect(find.text('Draft: API design notes'), findsOneWidget);
    await tester.tap(find.byTooltip('Filter documents'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Infrastructure'));
    await tester.pumpAndSettle();
    expect(find.text('Area: Infrastructure'), findsOneWidget);
    expect(find.text('Draft: API design notes'), findsOneWidget);
    await tester.tap(find.text('Draft: API design notes'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Undo'), findsNothing);
    expect(find.byTooltip('Redo'), findsNothing);
    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'API',
    );
    expect(find.text('Area: Infrastructure'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'no matching document');
    await tester.pumpAndSettle();
    expect(find.text('No documents match'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'mobile document title scrolls while mode switch stays floating',
    (tester) async {
      await _pumpWorkspace(tester, 390);
      await tester.tap(find.text('Draft: API design notes').first);
      await tester.pumpAndSettle();
      final editor = tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor));
      final transaction = editor.editorState.transaction;
      transaction.insertNodes(
        [1],
        List.generate(
          30,
          (i) => paragraphNode(
            text: 'Paragraph $i: room to keep writing and scrolling.',
          ),
        ),
      );
      await editor.editorState.apply(transaction);
      await tester.pumpAndSettle();
      final title = find.byKey(const ValueKey('title-display-1'));
      final toggle = find.byKey(const ValueKey('floating-mode-toggle'));
      expect(title.hitTestable(), findsOneWidget);
      final togglePosition = tester.getTopLeft(toggle);
      await tester.drag(find.byType(AppFlowyEditor), const Offset(0, -650));
      await tester.pumpAndSettle();
      expect(title.hitTestable(), findsNothing);
      expect(tester.getTopLeft(toggle), togglePosition);
      await tester.tap(find.byTooltip('Read'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor)).editable,
        isFalse,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  for (final width in [320.0, 390.0, 744.0]) {
    testWidgets('create, rename, edit and reopen at width $width', (
      tester,
    ) async {
      final repo = await _pumpWorkspace(tester, width);
      await tester.tap(find.byTooltip('New document'));
      await tester.pumpAndSettle();
      final editor = tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor));
      expect(editor.editable, isTrue);
      expect(find.text('Insert'), findsNothing);
      expect(find.byKey(const ValueKey('title-display-100')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('floating-mode-toggle')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey<String>('title-display-100')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).last,
        'Written on a small screen',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      editor.editorState.selection = Selection.collapsed(
        Position(path: [0], offset: 0),
      );
      await editor.editorState.insertTextAtPosition(
        'Saved before leaving',
        position: Position(path: [0], offset: 0),
      );
      // Leave before the 450 ms typing debounce completes.
      await tester.tap(find.byIcon(Icons.arrow_back).first);
      await tester.pumpAndSettle();
      final created = (await repo.listAll()).firstWhere(
        (d) => d.title == 'Written on a small screen',
      );
      expect(created.document, contains('Saved before leaving'));
      await tester.tap(find.text('Written on a small screen').first);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AppFlowyEditor>(find.byType(AppFlowyEditor))
            .editorState
            .document
            .root
            .children
            .first
            .delta!
            .toPlainText(),
        contains('Saved before leaving'),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }

  testWidgets('insert sheet works with the software keyboard at phone width', (
    tester,
  ) async {
    await _pumpWorkspace(tester, 390);
    await tester.tap(find.byTooltip('New document'));
    await tester.pumpAndSettle();
    final editor = tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor));
    editor.editorState.selection = Selection.collapsed(
      Position(path: [0], offset: 0),
    );
    await tester.pumpAndSettle();
    // Use the docked toolbar, whose callback context belongs to a sliver.
    await tester.tap(
      find.descendant(
        of: find.byType(MobileToolbarWidget),
        matching: find.byTooltip('Insert block'),
      ),
    );
    await tester.pumpAndSettle();
    final search = find.widgetWithText(TextField, 'Search blocks or links');
    await tester.enterText(search, 'heading');
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('H1').first);
    await tester.pumpAndSettle();
    final state = tester
        .widget<AppFlowyEditor>(find.byType(AppFlowyEditor))
        .editorState;
    expect(
      state.document.root.children.map((node) => node.type),
      contains(HeadingBlockKeys.type),
    );
    expect(find.text('Search blocks or links'), findsNothing);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  for (final dark in [false, true]) {
    testWidgets('phone colors apply to selection and typing in dark=$dark', (
      tester,
    ) async {
      final previousDark = AppColors.isDark;
      AppColors.isDark = dark;
      addTearDown(() => AppColors.isDark = previousDark);
      await _pumpWorkspace(tester, 390);
      await tester.tap(find.byTooltip('New document'));
      await tester.pumpAndSettle();
      final state = tester
          .widget<AppFlowyEditor>(find.byType(AppFlowyEditor))
          .editorState;
      state.selection = Selection.collapsed(Position(path: [0], offset: 0));
      await state.insertTextAtPosition(
        'Hello',
        position: Position(path: [0], offset: 0),
      );
      state.selection = Selection(
        start: Position(path: [0], offset: 0),
        end: Position(path: [0], offset: 5),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is AFMobileIcon && w.afMobileIcons == AFMobileIcons.color,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Red'));
      await tester.pumpAndSettle();
      expect(
        state.document.root.children.first.delta!.everyAttributes(
          (a) => a[AppFlowyRichTextKeys.textColor] == Colors.red.toHex(),
        ),
        isTrue,
      );
      state.selection = Selection.collapsed(Position(path: [0], offset: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blue'));
      await tester.pumpAndSettle();
      expect(
        state.toggledStyle[AppFlowyRichTextKeys.textColor],
        Colors.blue.toHex(),
      );
      await ime.onInsert(
        const TextEditingDeltaInsertion(
          oldText: 'Hello',
          textInserted: '!',
          insertionOffset: 5,
          selection: TextSelection.collapsed(offset: 6),
          composing: TextRange.empty,
        ),
        state,
        [],
      );
      await tester.pumpAndSettle();
      expect(
        state.document.root.children.first.delta!
            .slice(5, 6)
            .everyAttributes(
              (a) => a[AppFlowyRichTextKeys.textColor] == Colors.blue.toHex(),
            ),
        isTrue,
      );
      // Clearing must override the inherited blue for subsequent typing.
      await tester.tap(find.text('Default'));
      await tester.pumpAndSettle();
      expect(
        state.toggledStyle.containsKey(AppFlowyRichTextKeys.textColor),
        isTrue,
      );
      expect(state.toggledStyle[AppFlowyRichTextKeys.textColor], isNull);
      state.selection = Selection(
        start: Position(path: [0], offset: 0),
        end: Position(path: [0], offset: 5),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Highlight'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yellow'));
      await tester.pumpAndSettle();
      expect(
        state.document.root.children.first.delta!
            .slice(0, 5)
            .everyAttributes(
              (a) =>
                  a[AppFlowyRichTextKeys.backgroundColor] ==
                  Colors.yellow.withValues(alpha: .3).toHex(),
            ),
        isTrue,
      );
      await tester.tap(find.text('Default'));
      await tester.pumpAndSettle();
      expect(
        state.document.root.children.first.delta!
            .slice(0, 5)
            .everyAttributes(
              (a) => a[AppFlowyRichTextKeys.backgroundColor] == null,
            ),
        isTrue,
      );
      final tab = tester.widget<TextButton>(
        find.byKey(const ValueKey('mobile-highlight-tab')),
      );
      final foreground = tab.style!.foregroundColor!.resolve({})!;
      final background = tab.style!.backgroundColor!.resolve({})!;
      final a = foreground.computeLuminance();
      final b = background.computeLuminance();
      final contrast = a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
      expect(contrast, greaterThanOrEqualTo(4.5));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }

  testWidgets('pending text survives a tablet layout change', (tester) async {
    final repo = await _pumpWorkspace(tester, 744);

    await tester.tap(find.text('Draft: API design notes').first);
    await tester.pumpAndSettle();
    var state = tester
        .widget<AppFlowyEditor>(find.byType(AppFlowyEditor))
        .editorState;
    state.selection = Selection.collapsed(Position(path: [0], offset: 0));
    await state.insertTextAtPosition(
      'Before rotation ',
      position: Position(path: [0], offset: 0),
    );
    tester.view.physicalSize = const Size(1133, 744);
    await tester.pumpAndSettle();
    expect((await repo.getById(1))!.document, contains('Before rotation'));
    state = tester
        .widget<AppFlowyEditor>(find.byType(AppFlowyEditor))
        .editorState;
    expect(
      state.document.root.children.first.delta!.toPlainText(),
      contains('Before rotation'),
    );
    tester.view.physicalSize = const Size(744, 1133);
    await tester.pumpAndSettle();
    expect(
      tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor)).editable,
      isTrue,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('phone landscape keeps formatting above the keyboard', (
    tester,
  ) async {
    await _pumpWorkspace(tester, 700);
    await tester.tap(find.text('Draft: API design notes').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Read'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor)).editable,
      isFalse,
    );
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    final state = tester
        .widget<AppFlowyEditor>(find.byType(AppFlowyEditor))
        .editorState;
    state.selection = Selection.collapsed(Position(path: [0], offset: 0));
    tester.view.physicalSize = const Size(700, 390);
    tester.view.viewInsets = const FakeViewPadding(bottom: 210);
    await tester.pumpAndSettle();
    expect(find.byType(MobileToolbarWidget), findsOneWidget);
    expect(
      tester.getBottomLeft(find.byType(MobileToolbarWidget)).dy,
      lessThanOrEqualTo(180),
    );
    // Let delayed keyboard/caret scrolling run while the short viewport exists.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('details sheet exposes editing actions on a small tablet', (
    tester,
  ) async {
    await _pumpWorkspace(tester, 744);
    await tester.tap(find.text('Draft: API design notes').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Document details'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Details').first).dx,
      lessThan(tester.getTopLeft(find.text('Contents')).dx),
    );
    expect(find.byType(Switch), findsWidgets);
    await tester.tap(find.text('Details').first);
    await tester.pumpAndSettle();
    expect(find.byType(Switch), findsWidgets);
    expect(find.text('Save now'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}

Future<FakeDocumentRepository> _pumpWorkspace(
  WidgetTester tester,
  double width,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetViewInsets);
  SharedPreferences.setMockInitialValues({});
  final repo = FakeDocumentRepository();
  final workspace = WebDocumentWorkspace(
    remoteApi: RepositoryDocumentRemoteApi(
      repository: repo,
      syncTransport: FakeDocumentRemoteApi(),
    ),
  );
  addTearDown(workspace.close);
  final router = GoRouter(
    initialLocation: '/docs',
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
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userIdProvider.overrideWithValue(null),
        sockWsUrlProvider.overrideWithValue(null),
        imageBaseUrlProvider.overrideWithValue(null),
        documentBrowserBuilderProvider.overrideWithValue(
          (_) => const SizedBox.expand(),
        ),
        documentRepositoryProvider.overrideWithValue(repo),
        documentWorkspaceProvider.overrideWithValue(workspace),
        documentImageAssetServiceProvider.overrideWithValue(null),
        nxDocsStateServiceProvider.overrideWithValue(null),
        activeOfflineSessionProvider.overrideWith((_) async => null),
        documentScrollStoreProvider.overrideWithValue(
          const DocumentScrollStore('responsive-test'),
        ),
      ],
      child: MaterialApp.router(
        theme: buildAppTheme(),
        routerConfig: router,
        localizationsDelegates: const [
          AppFlowyEditorLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppFlowyEditorLocalizations.delegate.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}
