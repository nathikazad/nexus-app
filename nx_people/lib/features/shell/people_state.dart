import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_people/domain/person/person_query.dart';

class PeopleWorkspaceState {
  const PeopleWorkspaceState({
    this.activePersonId = 1,
    this.sidebarTab = PeopleSidebarTab.people,
    this.activeContext,
    this.overlayContext,
    this.createMenuOpen = false,
  });

  final int activePersonId;
  final PeopleSidebarTab sidebarTab;
  final PeopleResultContext? activeContext;
  final PeopleResultContext? overlayContext;
  final bool createMenuOpen;

  bool get hasOverlay => overlayContext != null;

  PeopleWorkspaceState copyWith({
    int? activePersonId,
    PeopleSidebarTab? sidebarTab,
    PeopleResultContext? activeContext,
    PeopleResultContext? overlayContext,
    bool? createMenuOpen,
    bool clearActiveContext = false,
    bool clearOverlay = false,
  }) {
    return PeopleWorkspaceState(
      activePersonId: activePersonId ?? this.activePersonId,
      sidebarTab: sidebarTab ?? this.sidebarTab,
      activeContext: clearActiveContext
          ? null
          : activeContext ?? this.activeContext,
      overlayContext: clearOverlay ? null : overlayContext ?? this.overlayContext,
      createMenuOpen: createMenuOpen ?? this.createMenuOpen,
    );
  }
}

enum PeopleSidebarTab { people, tags }

class PeopleWorkspaceNotifier extends Notifier<PeopleWorkspaceState> {
  @override
  PeopleWorkspaceState build() => const PeopleWorkspaceState();

  void setSidebarTab(PeopleSidebarTab tab) {
    state = state.copyWith(sidebarTab: tab);
  }

  void toggleCreateMenu() {
    state = state.copyWith(createMenuOpen: !state.createMenuOpen);
  }

  void showOverlay(PeopleResultContext context) {
    state = state.copyWith(overlayContext: context, createMenuOpen: false);
  }

  void hideOverlay() {
    state = state.copyWith(clearOverlay: true);
  }

  void openPerson(int personId, {PeopleResultContext? context}) {
    state = state.copyWith(
      activePersonId: personId,
      activeContext: context,
      clearOverlay: true,
      createMenuOpen: false,
    );
  }

  void returnToActiveContext() {
    final context = state.activeContext;
    if (context == null) return;
    state = state.copyWith(overlayContext: context);
  }

  void clearActiveContext() {
    state = state.copyWith(clearActiveContext: true);
  }
}

final peopleWorkspaceProvider =
    NotifierProvider<PeopleWorkspaceNotifier, PeopleWorkspaceState>(
      PeopleWorkspaceNotifier.new,
    );

enum MobilePeopleSection { people, tags, search }

class MobilePeopleState {
  const MobilePeopleState({
    this.section = MobilePeopleSection.people,
    this.searchText = '',
  });

  final MobilePeopleSection section;
  final String searchText;

  MobilePeopleState copyWith({
    MobilePeopleSection? section,
    String? searchText,
  }) {
    return MobilePeopleState(
      section: section ?? this.section,
      searchText: searchText ?? this.searchText,
    );
  }
}

class MobilePeopleNotifier extends Notifier<MobilePeopleState> {
  @override
  MobilePeopleState build() => const MobilePeopleState();

  void setSection(MobilePeopleSection section) {
    state = state.copyWith(section: section);
  }

  void setSearchText(String value) {
    state = state.copyWith(
      section: MobilePeopleSection.search,
      searchText: value,
    );
  }
}

final mobilePeopleProvider =
    NotifierProvider<MobilePeopleNotifier, MobilePeopleState>(
      MobilePeopleNotifier.new,
    );
