import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';

enum PeopleAppSection { people, meetings, pending, logs, funnels }

class PeopleWorkspaceState {
  const PeopleWorkspaceState({
    this.section = PeopleAppSection.people,
    this.activePersonId,
    this.searchText = '',
    this.peopleFilter = 'Recent',
    this.selectedDayOffset = 0,
    this.selectedLogDayOffset = 0,
  });

  final PeopleAppSection section;
  final int? activePersonId;
  final String searchText;
  final String peopleFilter;
  final int selectedDayOffset;
  final int selectedLogDayOffset;

  PeopleWorkspaceState copyWith({
    PeopleAppSection? section,
    int? activePersonId,
    String? searchText,
    String? peopleFilter,
    int? selectedDayOffset,
    int? selectedLogDayOffset,
  }) {
    return PeopleWorkspaceState(
      section: section ?? this.section,
      activePersonId: activePersonId ?? this.activePersonId,
      searchText: searchText ?? this.searchText,
      peopleFilter: peopleFilter ?? this.peopleFilter,
      selectedDayOffset: selectedDayOffset ?? this.selectedDayOffset,
      selectedLogDayOffset: selectedLogDayOffset ?? this.selectedLogDayOffset,
    );
  }
}

class PeopleWorkspaceNotifier extends Notifier<PeopleWorkspaceState> {
  @override
  PeopleWorkspaceState build() {
    ref.watch(
      authProvider.select((auth) {
        final user = auth.value;
        return user?.domainId == null ? null : user!.sessionKey;
      }),
    );
    return const PeopleWorkspaceState();
  }

  void setSection(PeopleAppSection section) {
    state = state.copyWith(section: section);
  }

  void openPerson(int personId) {
    state = state.copyWith(activePersonId: personId);
  }

  void setPeopleFilter(String value) {
    state = state.copyWith(peopleFilter: value);
  }

  void setSearchText(String value) {
    state = state.copyWith(searchText: value);
  }

  void setSelectedDayOffset(int offset) {
    state = state.copyWith(selectedDayOffset: offset);
  }

  void setSelectedLogDayOffset(int offset) {
    state = state.copyWith(selectedLogDayOffset: offset);
  }
}

final peopleWorkspaceProvider =
    NotifierProvider<PeopleWorkspaceNotifier, PeopleWorkspaceState>(
      PeopleWorkspaceNotifier.new,
    );
