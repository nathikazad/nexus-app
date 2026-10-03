import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/data/models/library_summary.dart';
import 'package:nx_cards/scheduling/retention.dart';
import '../study/study_setup_page_test.dart' show sample;

void main() {
  test('overview counts each due card once across supported fronts', () {
    final now = DateTime.now();
    final cards = [
      sample(1, 1).copyWith(
        content: const LanguageCardContent(
          english: 'one',
          originalScript: '一',
          transliteration: 'yi',
          audioUrl: '/audio',
        ),
      ),
      sample(2, 10), // no audio: two text fronts only
      sample(3, 1, due: false),
      sample(4, 1, active: false),
      sample(5, 1).copyWith(suspended: true),
    ];
    final dashboard = CardsDashboard(cards: cards);
    final prompts = retentionPrompts(
      cards,
      RecallComponent.values.toSet(),
    ).where((p) => p.isDueAt(now)).toList();
    expect(prompts.length, 10);
    expect(dashboard.dueCount(now), 2);
    expect(summarizeLibrary(dashboard).single.due, 2);
    expect(summarizeLibrary(dashboard).single.current, 4);
    expect(dashboard.dueCount(now, cue: StudyCue.meaningToScript), 2);
  });
}
