import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PeopleAppSection { people, meetings, pending, funnels }

class PeopleWorkspaceState {
  const PeopleWorkspaceState({
    this.section = PeopleAppSection.people,
    this.activePersonId,
    this.searchText = '',
    this.selectedDayOffset = 0,
  });

  final PeopleAppSection section;
  final int? activePersonId;
  final String searchText;
  final int selectedDayOffset;

  PeopleWorkspaceState copyWith({
    PeopleAppSection? section,
    int? activePersonId,
    String? searchText,
    int? selectedDayOffset,
  }) {
    return PeopleWorkspaceState(
      section: section ?? this.section,
      activePersonId: activePersonId ?? this.activePersonId,
      searchText: searchText ?? this.searchText,
      selectedDayOffset: selectedDayOffset ?? this.selectedDayOffset,
    );
  }
}

class PeopleWorkspaceNotifier extends Notifier<PeopleWorkspaceState> {
  @override
  PeopleWorkspaceState build() => const PeopleWorkspaceState();

  void setSection(PeopleAppSection section) {
    state = state.copyWith(section: section);
  }

  void openPerson(int personId) {
    state = state.copyWith(activePersonId: personId);
  }

  void setSearchText(String value) {
    state = state.copyWith(searchText: value);
  }

  void setSelectedDayOffset(int offset) {
    state = state.copyWith(selectedDayOffset: offset);
  }
}

final peopleWorkspaceProvider =
    NotifierProvider<PeopleWorkspaceNotifier, PeopleWorkspaceState>(
      PeopleWorkspaceNotifier.new,
    );
