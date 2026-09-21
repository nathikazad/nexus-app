import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/study/language/drawing/native_drawing_session.dart';

LanguageExample example(int id, String text) => LanguageExample(
  cardId: id,
  text: text,
  transliteration: 'sound $id',
  translation: 'meaning $id',
  audioUrl: '/$id.mp3',
);
StudyCard card(int id, String text, List<LanguageExample> examples) =>
    StudyCard(
      id: id,
      content: LanguageCardContent(
        english: 'meaning $id',
        originalScript: text,
        transliteration: 'sound $id',
        examples: examples,
      ),
      schedules: const {},
      reviewHistory: const {},
      suspended: false,
    );
void main() {
  test(
    'offline summaries hydrate direct parents once without loading grandchildren',
    () async {
      final root = card(1, '知', [example(2, '知道')]);
      final parent = card(2, '知道', [example(3, '我不知道。')]);
      final library = {
        2: card(2, '知道', []).copyWith(isSummary: true),
        3: card(3, '我不知道。', []).copyWith(isSummary: true),
      };
      final reads = <int>[];
      await NativeDrawingSession.hydrateExampleParents([root, root], library, (
        summary,
      ) async {
        reads.add(summary.id);
        return parent;
      });
      expect(reads, [2]);
      expect(
        NativeDrawingSession.derivedExamples(root, library).single.example.text,
        '我不知道。',
      );
      expect(library[3]!.isSummary, isTrue);
    },
  );

  test(
    'one extra level deduplicates, labels parents and excludes cycles/direct examples',
    () {
      final root = card(1, '学', [
        example(2, '学生'),
        example(3, '学校'),
        example(9, 'missing'),
      ]);
      final library = {
        2: card(2, '学生', [
          example(4, '我是学生。'),
          example(1, '学'),
          example(3, '学校'),
        ]),
        3: card(3, '学校', [example(4, '我是学生。'), example(5, '他在学校。')]),
        4: card(4, '我是学生。', [example(6, 'deeper example')]),
      };
      final derived = NativeDrawingSession.derivedExamples(root, library);
      expect(derived.map((e) => e.example.cardId), [4, 5]);
      expect(derived.first.via, ['学生', '学校']);
      expect(derived.last.via, ['学校']);
      final practice = NativeDrawingSession.practiceCard(
        root,
        derived: derived,
      );
      final recall = NativeDrawingSession.recallCard(
        StudyPrompt(card: root, cue: StudyCue.fromLanguage),
        derived: derived,
      );
      expect(recall['derivedExamples'], practice['derivedExamples']);
      final payload = (practice['derivedExamples'] as List).first as Map;
      expect(payload['via'], '学生, 学校');
      expect(payload['audio'], isTrue);
      expect(derived.first.example.audioUrl, '/4.mp3');
    },
  );
  test('unlinked legacy examples are not guessed by spelling', () {
    final root = card(1, '学', [
      const LanguageExample(
        text: '学生',
        transliteration: 'xuésheng',
        translation: 'student',
      ),
    ]);
    expect(
      NativeDrawingSession.derivedExamples(root, {
        2: card(2, '学生', [example(4, 'sentence')]),
      }),
      isEmpty,
    );
  });
}
