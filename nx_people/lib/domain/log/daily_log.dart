class DailyLog {
  const DailyLog({
    required this.id,
    required this.loggedAt,
    this.entry,
    this.imageUrl,
  });

  final int id;
  final DateTime loggedAt;
  final String? entry;
  final String? imageUrl;
}

class DailyLogDraft {
  const DailyLogDraft({required this.loggedAt, this.entry, this.imageUrl});

  final DateTime loggedAt;
  final String? entry;
  final String? imageUrl;

  bool get hasContent =>
      (entry?.trim().isNotEmpty ?? false) ||
      (imageUrl?.trim().isNotEmpty ?? false);
}
