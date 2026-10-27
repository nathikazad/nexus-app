import 'package:nx_cards/browser/browser.dart';

/// ISO calendar dates sort chronologically without a timezone conversion.
Map<String, int> recentCurrentDateGroups(Iterable<StudyCard> cards) {
  final groups = <String, Set<int>>{};
  for (final card in cards) {
    final date = card.addedToCurrentAt;
    if (card.learningStatus != LearningStatus.recall ||
        card.suspended ||
        date == null ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
      continue;
    }
    final parsed = DateTime.tryParse(date);
    if (parsed == null || calendarDate(parsed) != date) continue;
    (groups[date] ??= {}).add(card.id);
  }
  final dates = groups.keys.toList()..sort((a, b) => b.compareTo(a));
  return {for (final date in dates.take(5)) date: groups[date]!.length};
}
