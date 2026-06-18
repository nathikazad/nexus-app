import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/domain/document/document_query.dart';
import 'package:nx_notes/domain/document/document_result_context.dart';

class DocumentTabState {
  const DocumentTabState({
    required this.documentId,
    this.context,
    this.dirty = false,
    this.history = const <int>[],
  });

  final int documentId;
  final DocumentResultContext? context;
  final bool dirty;
  final List<int> history;

  List<int> get editorStack => <int>[...history, documentId];

  DocumentTabState copyWith({
    int? documentId,
    DocumentResultContext? context,
    bool? dirty,
    List<int>? history,
    bool clearContext = false,
  }) {
    return DocumentTabState(
      documentId: documentId ?? this.documentId,
      context: clearContext ? null : context ?? this.context,
      dirty: dirty ?? this.dirty,
      history: history ?? this.history,
    );
  }
}

class DesktopWorkspaceState {
  const DesktopWorkspaceState({
    required this.openTabs,
    this.activeDocumentId,
    this.overlayTitle,
    this.overlayQuery,
    this.overlayResultIds = const <int>[],
    this.overlayResults = const <NxDocument>[],
    this.sidebarTab = SidebarTab.documents,
    this.sidebarCollapsed = false,
    this.inspectorCollapsed = false,
  });

  final List<DocumentTabState> openTabs;
  final int? activeDocumentId;
  final String? overlayTitle;
  final DocumentQuery? overlayQuery;
  final List<int> overlayResultIds;
  final List<NxDocument> overlayResults;
  final SidebarTab sidebarTab;
  final bool sidebarCollapsed;
  final bool inspectorCollapsed;

  bool get hasOverlay => overlayTitle != null;

  DocumentTabState? get activeTab {
    for (final tab in openTabs) {
      if (tab.documentId == activeDocumentId) {
        return tab;
      }
    }
    return null;
  }

  DocumentResultContext? get activeContext {
    return activeTab?.context;
  }

  bool get canNavigateActiveTabBack {
    return activeTab?.history.isNotEmpty ?? false;
  }

  DesktopWorkspaceState copyWith({
    List<DocumentTabState>? openTabs,
    int? activeDocumentId,
    String? overlayTitle,
    DocumentQuery? overlayQuery,
    List<int>? overlayResultIds,
    List<NxDocument>? overlayResults,
    SidebarTab? sidebarTab,
    bool? sidebarCollapsed,
    bool? inspectorCollapsed,
    bool clearOverlay = false,
  }) {
    return DesktopWorkspaceState(
      openTabs: openTabs ?? this.openTabs,
      activeDocumentId: activeDocumentId ?? this.activeDocumentId,
      overlayTitle: clearOverlay ? null : overlayTitle ?? this.overlayTitle,
      overlayQuery: clearOverlay ? null : overlayQuery ?? this.overlayQuery,
      overlayResultIds: clearOverlay
          ? const <int>[]
          : overlayResultIds ?? this.overlayResultIds,
      overlayResults: clearOverlay
          ? const <NxDocument>[]
          : overlayResults ?? this.overlayResults,
      sidebarTab: sidebarTab ?? this.sidebarTab,
      sidebarCollapsed: sidebarCollapsed ?? this.sidebarCollapsed,
      inspectorCollapsed: inspectorCollapsed ?? this.inspectorCollapsed,
    );
  }
}

enum SidebarTab { documents, books, tags }

class DesktopWorkspaceNotifier extends Notifier<DesktopWorkspaceState> {
  static const int _maxMountedEditorsPerTab = 5;

  @override
  DesktopWorkspaceState build() {
    return const DesktopWorkspaceState(openTabs: <DocumentTabState>[]);
  }

  void setSidebarTab(SidebarTab tab) {
    state = state.copyWith(sidebarTab: tab);
  }

  void toggleSidebar() {
    state = state.copyWith(sidebarCollapsed: !state.sidebarCollapsed);
  }

  void toggleInspector() {
    state = state.copyWith(inspectorCollapsed: !state.inspectorCollapsed);
  }

  void showOverlay({
    required String title,
    required DocumentQuery query,
    required List<int> resultIds,
    List<NxDocument> results = const <NxDocument>[],
  }) {
    state = state.copyWith(
      overlayTitle: title,
      overlayQuery: query,
      overlayResultIds: resultIds,
      overlayResults: results,
    );
  }

  void hideOverlay() {
    state = state.copyWith(clearOverlay: true);
  }

  void openDocument(
    int documentId, {
    bool fromOverlay = false,
    DocumentResultContext? context,
  }) {
    var tabs = [...state.openTabs];
    final index = tabs.indexWhere((tab) => tab.documentId == documentId);
    DocumentResultContext? nextContext = context;
    if (fromOverlay &&
        state.overlayTitle != null &&
        state.overlayQuery != null) {
      nextContext = DocumentResultContext(
        title: state.overlayTitle!,
        query: state.overlayQuery!,
        resultIds: state.overlayResultIds,
        results: state.overlayResults,
      );
    }
    if (index == -1) {
      tabs.add(DocumentTabState(documentId: documentId, context: nextContext));
    } else if (nextContext != null) {
      tabs[index] = tabs[index].copyWith(context: nextContext);
    }
    state = state.copyWith(
      openTabs: tabs,
      activeDocumentId: documentId,
      clearOverlay: true,
    );
  }

  void openDocumentInActiveTab(int documentId) {
    final activeDocumentId = state.activeDocumentId;
    if (activeDocumentId == null || activeDocumentId == documentId) {
      return;
    }
    final tabs = [
      for (final tab in state.openTabs)
        if (tab.documentId == documentId)
          // Keep navigation within the active tab. If the target document is
          // already open in another tab, remove that tab to avoid duplicate
          // document ids confusing active-tab history lookup.
          ...const <DocumentTabState>[]
        else if (tab.documentId == activeDocumentId)
          _tabAfterInTabNavigation(tab, documentId)
        else
          tab,
    ];
    state = state.copyWith(openTabs: tabs, activeDocumentId: documentId);
  }

  void backInActiveTab() {
    final activeDocumentId = state.activeDocumentId;
    if (activeDocumentId == null) return;
    final tabs = <DocumentTabState>[];
    int? nextActiveDocumentId;
    for (final tab in state.openTabs) {
      if (tab.documentId != activeDocumentId || tab.history.isEmpty) {
        tabs.add(tab);
        continue;
      }
      final history = [...tab.history];
      nextActiveDocumentId = history.removeLast();
      tabs.add(
        tab.copyWith(documentId: nextActiveDocumentId, history: history),
      );
    }
    if (nextActiveDocumentId == null) return;
    state = state.copyWith(
      openTabs: tabs,
      activeDocumentId: nextActiveDocumentId,
    );
  }

  void closeTab(int documentId) {
    if (state.openTabs.length == 1) {
      state = const DesktopWorkspaceState(openTabs: <DocumentTabState>[]);
      return;
    }
    final index = state.openTabs.indexWhere(
      (tab) => tab.documentId == documentId,
    );
    if (index == -1) {
      return;
    }
    final tabs = state.openTabs
        .where((tab) => tab.documentId != documentId)
        .toList();
    final nextActive = state.activeDocumentId == documentId
        ? tabs[index.clamp(0, tabs.length - 1)].documentId
        : state.activeDocumentId;
    state = state.copyWith(openTabs: tabs, activeDocumentId: nextActive);
  }

  void clearActiveContext() {
    final tabs = [
      for (final tab in state.openTabs)
        if (tab.documentId == state.activeDocumentId)
          tab.copyWith(clearContext: true)
        else
          tab,
    ];
    state = state.copyWith(openTabs: tabs);
  }

  List<int> _boundedHistoryForPush(List<int> history, int documentId) {
    final next = <int>[...history, documentId];
    final maxHistory = _maxMountedEditorsPerTab - 1;
    if (next.length <= maxHistory) {
      return next;
    }
    return next.sublist(next.length - maxHistory);
  }

  DocumentTabState _tabAfterInTabNavigation(
    DocumentTabState tab,
    int documentId,
  ) {
    final existingIndex = tab.editorStack.indexOf(documentId);
    if (existingIndex != -1) {
      final stack = tab.editorStack.sublist(0, existingIndex + 1);
      return tab.copyWith(
        documentId: documentId,
        history: stack.sublist(0, stack.length - 1),
      );
    }
    return tab.copyWith(
      documentId: documentId,
      history: _boundedHistoryForPush(tab.history, tab.documentId),
    );
  }
}

final desktopWorkspaceProvider =
    NotifierProvider<DesktopWorkspaceNotifier, DesktopWorkspaceState>(
      DesktopWorkspaceNotifier.new,
    );

enum MobileSection { documents, books, tags, search }

class MobileNotesState {
  const MobileNotesState({
    this.section = MobileSection.documents,
    this.activeDocumentId,
    this.resultContext,
    this.searchText = '',
    this.showResults = false,
    this.history = const <int>[],
  });

  final MobileSection section;
  final int? activeDocumentId;
  final DocumentResultContext? resultContext;
  final String searchText;
  final bool showResults;
  final List<int> history;

  MobileNotesState copyWith({
    MobileSection? section,
    int? activeDocumentId,
    DocumentResultContext? resultContext,
    String? searchText,
    bool? showResults,
    List<int>? history,
    bool clearDocument = false,
    bool clearContext = false,
  }) {
    return MobileNotesState(
      section: section ?? this.section,
      activeDocumentId: clearDocument
          ? null
          : activeDocumentId ?? this.activeDocumentId,
      resultContext: clearContext ? null : resultContext ?? this.resultContext,
      searchText: searchText ?? this.searchText,
      showResults: showResults ?? this.showResults,
      history: clearDocument ? const <int>[] : history ?? this.history,
    );
  }
}

class MobileNotesNotifier extends Notifier<MobileNotesState> {
  @override
  MobileNotesState build() => const MobileNotesState();

  void setSection(MobileSection section) {
    state = state.copyWith(
      section: section,
      clearDocument: true,
      showResults: false,
    );
  }

  void setSearchText(String value) {
    state = state.copyWith(
      section: MobileSection.search,
      searchText: value,
      showResults: false,
    );
  }

  void showResults(DocumentResultContext context) {
    state = state.copyWith(
      resultContext: context,
      showResults: true,
      clearDocument: true,
    );
  }

  void openDocument(int id, {DocumentResultContext? context}) {
    state = state.copyWith(
      activeDocumentId: id,
      resultContext: context ?? state.resultContext,
      showResults: false,
    );
  }

  void openDocumentFromLink(int id) {
    final activeDocumentId = state.activeDocumentId;
    if (activeDocumentId == null || activeDocumentId == id) return;
    state = state.copyWith(
      activeDocumentId: id,
      history: [...state.history, activeDocumentId],
      showResults: false,
    );
  }

  void back() {
    if (state.activeDocumentId != null && state.history.isNotEmpty) {
      final history = [...state.history];
      final previousDocumentId = history.removeLast();
      state = state.copyWith(
        activeDocumentId: previousDocumentId,
        history: history,
      );
    } else if (state.activeDocumentId != null && state.resultContext != null) {
      state = state.copyWith(clearDocument: true, showResults: true);
    } else if (state.activeDocumentId != null) {
      state = state.copyWith(
        clearDocument: true,
        clearContext: true,
        showResults: false,
      );
    } else if (state.showResults) {
      state = state.copyWith(showResults: false, clearContext: true);
    }
  }
}

final mobileNotesProvider =
    NotifierProvider<MobileNotesNotifier, MobileNotesState>(
      MobileNotesNotifier.new,
    );
