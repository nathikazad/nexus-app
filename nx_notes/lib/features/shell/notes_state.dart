import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_notes/domain/essay/essay.dart';
import 'package:nx_notes/domain/essay/essay_query.dart';
import 'package:nx_notes/domain/essay/essay_result_context.dart';

class EssayTabState {
  const EssayTabState({
    required this.essayId,
    this.context,
    this.dirty = false,
  });

  final int essayId;
  final EssayResultContext? context;
  final bool dirty;

  EssayTabState copyWith({
    EssayResultContext? context,
    bool? dirty,
    bool clearContext = false,
  }) {
    return EssayTabState(
      essayId: essayId,
      context: clearContext ? null : context ?? this.context,
      dirty: dirty ?? this.dirty,
    );
  }
}

class DesktopWorkspaceState {
  const DesktopWorkspaceState({
    required this.openTabs,
    this.activeEssayId,
    this.overlayTitle,
    this.overlayQuery,
    this.overlayResultIds = const <int>[],
    this.overlayResults = const <Essay>[],
    this.sidebarTab = SidebarTab.essays,
    this.inspectorCollapsed = false,
  });

  final List<EssayTabState> openTabs;
  final int? activeEssayId;
  final String? overlayTitle;
  final EssayQuery? overlayQuery;
  final List<int> overlayResultIds;
  final List<Essay> overlayResults;
  final SidebarTab sidebarTab;
  final bool inspectorCollapsed;

  bool get hasOverlay => overlayTitle != null;

  EssayResultContext? get activeContext {
    for (final tab in openTabs) {
      if (tab.essayId == activeEssayId) {
        return tab.context;
      }
    }
    return null;
  }

  DesktopWorkspaceState copyWith({
    List<EssayTabState>? openTabs,
    int? activeEssayId,
    String? overlayTitle,
    EssayQuery? overlayQuery,
    List<int>? overlayResultIds,
    List<Essay>? overlayResults,
    SidebarTab? sidebarTab,
    bool? inspectorCollapsed,
    bool clearOverlay = false,
  }) {
    return DesktopWorkspaceState(
      openTabs: openTabs ?? this.openTabs,
      activeEssayId: activeEssayId ?? this.activeEssayId,
      overlayTitle: clearOverlay ? null : overlayTitle ?? this.overlayTitle,
      overlayQuery: clearOverlay ? null : overlayQuery ?? this.overlayQuery,
      overlayResultIds: clearOverlay
          ? const <int>[]
          : overlayResultIds ?? this.overlayResultIds,
      overlayResults: clearOverlay
          ? const <Essay>[]
          : overlayResults ?? this.overlayResults,
      sidebarTab: sidebarTab ?? this.sidebarTab,
      inspectorCollapsed: inspectorCollapsed ?? this.inspectorCollapsed,
    );
  }
}

enum SidebarTab { essays, tags }

class DesktopWorkspaceNotifier extends Notifier<DesktopWorkspaceState> {
  @override
  DesktopWorkspaceState build() {
    return const DesktopWorkspaceState(openTabs: <EssayTabState>[]);
  }

  void setSidebarTab(SidebarTab tab) {
    state = state.copyWith(sidebarTab: tab);
  }

  void toggleInspector() {
    state = state.copyWith(inspectorCollapsed: !state.inspectorCollapsed);
  }

  void showOverlay({
    required String title,
    required EssayQuery query,
    required List<int> resultIds,
    List<Essay> results = const <Essay>[],
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

  void openEssay(
    int essayId, {
    bool fromOverlay = false,
    EssayResultContext? context,
  }) {
    var tabs = [...state.openTabs];
    final index = tabs.indexWhere((tab) => tab.essayId == essayId);
    EssayResultContext? nextContext = context;
    if (fromOverlay &&
        state.overlayTitle != null &&
        state.overlayQuery != null) {
      nextContext = EssayResultContext(
        title: state.overlayTitle!,
        query: state.overlayQuery!,
        resultIds: state.overlayResultIds,
        results: state.overlayResults,
      );
    }
    if (index == -1) {
      tabs.add(EssayTabState(essayId: essayId, context: nextContext));
    } else if (nextContext != null) {
      tabs[index] = tabs[index].copyWith(context: nextContext);
    }
    state = state.copyWith(
      openTabs: tabs,
      activeEssayId: essayId,
      clearOverlay: true,
    );
  }

  void closeTab(int essayId) {
    if (state.openTabs.length == 1) {
      state = const DesktopWorkspaceState(openTabs: <EssayTabState>[]);
      return;
    }
    final index = state.openTabs.indexWhere((tab) => tab.essayId == essayId);
    if (index == -1) {
      return;
    }
    final tabs = state.openTabs.where((tab) => tab.essayId != essayId).toList();
    final nextActive = state.activeEssayId == essayId
        ? tabs[index.clamp(0, tabs.length - 1)].essayId
        : state.activeEssayId;
    state = state.copyWith(openTabs: tabs, activeEssayId: nextActive);
  }

  void clearActiveContext() {
    final tabs = [
      for (final tab in state.openTabs)
        if (tab.essayId == state.activeEssayId)
          tab.copyWith(clearContext: true)
        else
          tab,
    ];
    state = state.copyWith(openTabs: tabs);
  }
}

final desktopWorkspaceProvider =
    NotifierProvider<DesktopWorkspaceNotifier, DesktopWorkspaceState>(
      DesktopWorkspaceNotifier.new,
    );

enum MobileSection { essays, tags, search }

class MobileNotesState {
  const MobileNotesState({
    this.section = MobileSection.essays,
    this.activeEssayId,
    this.resultContext,
    this.searchText = '',
    this.showResults = false,
  });

  final MobileSection section;
  final int? activeEssayId;
  final EssayResultContext? resultContext;
  final String searchText;
  final bool showResults;

  MobileNotesState copyWith({
    MobileSection? section,
    int? activeEssayId,
    EssayResultContext? resultContext,
    String? searchText,
    bool? showResults,
    bool clearEssay = false,
    bool clearContext = false,
  }) {
    return MobileNotesState(
      section: section ?? this.section,
      activeEssayId: clearEssay ? null : activeEssayId ?? this.activeEssayId,
      resultContext: clearContext ? null : resultContext ?? this.resultContext,
      searchText: searchText ?? this.searchText,
      showResults: showResults ?? this.showResults,
    );
  }
}

class MobileNotesNotifier extends Notifier<MobileNotesState> {
  @override
  MobileNotesState build() => const MobileNotesState();

  void setSection(MobileSection section) {
    state = state.copyWith(
      section: section,
      clearEssay: true,
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

  void showResults(EssayResultContext context) {
    state = state.copyWith(
      resultContext: context,
      showResults: true,
      clearEssay: true,
    );
  }

  void openEssay(int id, {EssayResultContext? context}) {
    state = state.copyWith(
      activeEssayId: id,
      resultContext: context ?? state.resultContext,
      showResults: false,
    );
  }

  void back() {
    if (state.activeEssayId != null && state.resultContext != null) {
      state = state.copyWith(clearEssay: true, showResults: true);
    } else if (state.activeEssayId != null) {
      state = state.copyWith(
        clearEssay: true,
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
