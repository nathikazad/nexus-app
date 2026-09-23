import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/language/language_groups.dart';

void main() {
  for (final type in ['Word', 'Verb']) {
    test(
      'Script grouping preserves $type category, cohort and review data',
      () {
        final schedule = CardSchedule.initial(enabled: true);
        final card = StudyCard(
          id: 1,
          modelTypeName: type,
          content: const LanguageCardContent(
            english: 'test',
            originalScript: '字',
            transliteration: 'zì',
          ),
          schedules: {StudyCue.fromLanguage: schedule},
          reviewHistory: const {},
          suspended: false,
          learningStatus: LearningStatus.learning,
          tags: {
            'Language': ['Chinese'],
            'Word Category': [if (type == 'Word') 'Noun'],
            'Study Category': ['Script', 'Script'],
          },
        );
        final primary = type == 'Word' ? 'Noun' : 'Verb';
        expect(card.studyCategories, [primary, 'Script']);
        final scriptGroups = languageGroups([
          card,
        ]).where((group) => group.name == 'Script').toList();
        expect(scriptGroups, hasLength(1));
        expect(scriptGroups.single.tagSystem, isNull);
        expect(scriptGroups.single.contains(card), isTrue);
        expect(card.progressionCohort, 'language:Chinese:$primary');
        expect(card.belongsToStudyCategory('Script'), isTrue);
        expect(card.scheduleFor(StudyCue.fromLanguage), same(schedule));
        expect(card.prompts.length, 1);
      },
    );
  }
}
