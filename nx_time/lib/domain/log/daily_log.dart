/// Domain entity for a Daily Log entry (a journal/log row).
///
/// Pure Dart — no Flutter / nx_db.
class DailyLog {
  const DailyLog({
    required this.id,
    required this.modelTypeId,
    this.loggedAt,
    this.entry,
    this.tags,
  });

  final int id;
  final int modelTypeId;
  final DateTime? loggedAt;
  final String? entry;

  /// Tag system name -> selected node names.
  final Map<String, List<String>>? tags;

  List<String> get feelings => tags?['Feeling'] ?? const [];

  DailyLog copyWith({
    int? id,
    int? modelTypeId,
    DateTime? loggedAt,
    String? entry,
    Map<String, List<String>>? tags,
  }) {
    return DailyLog(
      id: id ?? this.id,
      modelTypeId: modelTypeId ?? this.modelTypeId,
      loggedAt: loggedAt ?? this.loggedAt,
      entry: entry ?? this.entry,
      tags: tags ?? this.tags,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyLog &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          modelTypeId == other.modelTypeId &&
          loggedAt == other.loggedAt &&
          entry == other.entry &&
          _mapListEq(tags, other.tags);

  @override
  int get hashCode =>
      Object.hash(id, modelTypeId, loggedAt, entry, _mapListHash(tags));
}

bool _listEq(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _mapListEq(Map<String, List<String>>? a, Map<String, List<String>>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return a == null && b == null;
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    final bv = b[e.key];
    if (bv == null || !_listEq(e.value, bv)) return false;
  }
  return true;
}

int _mapListHash(Map<String, List<String>>? tags) {
  if (tags == null || tags.isEmpty) return 0;
  final entries = tags.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  return Object.hashAll([
    for (final e in entries) Object.hash(e.key, Object.hashAll(e.value)),
  ]);
}
