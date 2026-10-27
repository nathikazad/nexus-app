import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/study/current_date_groups.dart';
import 'study_setup_page_test.dart' show sample;

void main() {
  test('entry dates change only on transitions into Current', () {
    final future = sample(1, 0, active: false);
    final first = DateTime(2026, 10, 26, 23, 59);
    expect(
      future.currentDateForStatus(LearningStatus.recall, first),
      '2026-10-26',
    );
    final current = future.copyWith(
      learningStatus: LearningStatus.recall,
      addedToCurrentAt: '2026-10-26',
    );
    expect(
      current.currentDateForStatus(
        LearningStatus.recall,
        DateTime(2026, 10, 27),
      ),
      '2026-10-26',
    );
    expect(
      current
          .copyWith(learningStatus: LearningStatus.practice)
          .currentDateForStatus(LearningStatus.recall, DateTime(2026, 10, 27)),
      '2026-10-27',
    );
    expect(
      sample(2, 0).currentDateForStatus(LearningStatus.recall, first),
      isNull,
    );
  });
  test(
    'recent groups exclude null, invalid, suspended and non-current cards',
    () {
      final card = sample(1, 0).copyWith(addedToCurrentAt: '2026-10-26');
      expect(
        recentCurrentDateGroups([
          card,
          card,
          sample(2, 0),
          sample(3, 0).copyWith(addedToCurrentAt: '2026-02-30'),
          sample(
            4,
            0,
          ).copyWith(addedToCurrentAt: '2026-10-27', suspended: true),
          sample(5, 0, active: false).copyWith(addedToCurrentAt: '2026-10-27'),
          sample(6, 0).copyWith(addedToCurrentAt: '2026-10-25'),
        ]),
        {'2026-10-26': 1, '2026-10-25': 1},
      );
    },
  );
}
