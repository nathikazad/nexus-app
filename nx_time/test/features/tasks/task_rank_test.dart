import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/features/tasks/task_participants.dart';

void main() {
  test('fractional ranks retain strict order through repeated insertions', () {
    final ranks = <String>[rankBetween(null, null)];
    for (var i = 0; i < 500; i++) {
      final index = (i * 37) % (ranks.length + 1);
      final lower = index == 0 ? null : ranks[index - 1];
      final upper = index == ranks.length ? null : ranks[index];
      final rank = rankBetween(lower, upper);
      expect(lower == null || lower.compareTo(rank) < 0, isTrue);
      expect(upper == null || rank.compareTo(upper) < 0, isTrue);
      expect(rank.endsWith('0'), isFalse);
      ranks.insert(index, rank);
    }
  });
  test('equal neighbor ranks cannot silently corrupt order', () {
    expect(() => rankBetween('U', 'U'), throwsStateError);
  });
}
