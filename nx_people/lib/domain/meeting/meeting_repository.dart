class MeetingDraft {
  const MeetingDraft({
    required this.title,
    required this.description,
    required this.personId,
    required this.startedAt,
  });

  final String title;
  final String description;
  final int personId;
  final DateTime startedAt;
}

abstract class MeetingRepository {
  Future<int> create(MeetingDraft draft);
}
