import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/browser/data/kgql/kgql_card_mapper.dart';
import 'package:nx_cards/browser/language/language_groups.dart';
import 'package:nx_cards/browser/language/language_page.dart';
import 'package:nx_cards/scheduling/study_scope.dart';
import 'package:nx_cards/scheduling/future_card_rank.dart';
import 'package:nx_cards/sync/native/cards_database.dart';
import 'package:nx_cards/sync/native/drift_cards_mapper.dart';
import 'package:nx_db/kgql.dart';

StudyCard card(
  int id,
  List<List<String>> paths, {
  String language = 'Spanish',
  List<String> collections = const [],
  Set<int> links = const {},
}) => StudyCard(
  id: id,
  modelTypeName: 'LanguageFlashcard',
  content: LanguageCardContent(
    english: 'item $id',
    originalScript: 'texto $id',
    transliteration: '',
  ),
  schedules: const {},
  reviewHistory: const {},
  suspended: false,
  tags: {
    'Language': [language],
    'Category': paths.map((p) => p.last).toList(),
    'Collection': collections,
  },
  categoryPaths: paths,
  linkedWordIds: links,
);

void main() {
  testWidgets(
    'category rows remain one column and counts fit in priority order',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final data = CardsDashboard(
        cards: [
          card(
            1,
            [
              ['Word', 'Noun'],
            ],
            collections: ['A collection with a long title'],
          ),
          card(2, [
            ['Phrase'],
          ]),
        ],
      );
      Future<void> show(double width, double scale) async {
        await tester.binding.setSurfaceSize(Size(width, 1000));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cardsCollectionProvider.overrideWith(
                (ref, source) => Stream.value(data),
              ),
            ],
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const LanguagePage(language: 'Spanish'),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      const priority = [
        'total',
        'current',
        'due',
        'practice',
        'past',
        'future',
      ];
      int visible() {
        var count = 0;
        for (final label in priority) {
          if (find
              .byKey(ValueKey('language-category-word-$label'))
              .evaluate()
              .isNotEmpty) {
            expect(
              priority[count],
              label,
            ); // Never skip a higher priority count.
            count++;
          }
        }
        return count;
      }

      await show(1500, 1);
      expect(visible(), 6);
      expect(
        tester.getTopLeft(find.text('Words')).dx,
        tester.getTopLeft(find.text('Phrases')).dx,
      );
      expect(
        tester.getTopLeft(find.text('Phrases')).dy,
        greaterThan(tester.getBottomLeft(find.text('Words')).dy),
      );
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      await show(390, 1);
      final phoneCount = visible();
      expect(phoneCount, inInclusiveRange(1, 3));
      await show(280, 1);
      expect(visible(), inInclusiveRange(1, phoneCount));
      await show(390, 2);
      expect(visible(), inInclusiveRange(1, phoneCount));
      expect(
        find.byKey(const ValueKey('expand-category-Word')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  test('paths preserve distinct branches, descendants and phrase ranking', () {
    final noun = card(1, [
      ['Word', 'Noun'],
      ['Word', 'Verb'],
    ]);
    final question = card(
      2,
      [
        ['Phrase', 'Question'],
      ],
      links: {1},
    );
    final different = card(3, [
      ['Custom', 'Noun'],
    ]);
    final cards = [noun, question, different];
    final word = languageGroups(cards).singleWhere((g) => g.name == 'Word');
    expect(cards.where(word.contains).map((c) => c.id), [1]);
    expect(languageGroups(cards, parent: ['Word']).map((g) => g.name), [
      'Noun',
      'Verb',
    ]);
    expect(const StudyScope(tag: 'Word').contains(noun), true);
    expect(
      const StudyScope(
        tag: 'Noun',
        categoryPath: ['Word', 'Noun'],
      ).contains(different),
      false,
    );
    expect(question.isPhraseCard, true);
    final scores = futureCardScores(
      cards,
      cue: StudyCue.fromLanguage,
      historyWindow: 10,
    );
    expect(scores[1], greaterThan(0));
    expect(
      question.copyWith(suspended: true).categoryPaths,
      question.categoryPaths,
    );
  });

  test(
    'KGQL and offline round trip preserve paths and legacy cache remains readable',
    () async {
      final model = Model.fromJson({
        'id': 9,
        'name': 'hola',
        'model_type': {'id': 1, 'name': 'LanguageFlashcard'},
        'attributes': {
          'card_details': {'front': 'hello', 'back': 'hola'},
          'language_details': {'transliteration': '', 'examples': []},
        },
        'tags': {
          'Language': ['Spanish'],
          'Category': ['Greeting'],
        },
        'tag_paths': {
          'Category': [
            ['Phrase', 'Greeting'],
          ],
        },
      });
      expect(Model.fromJson(model.toJson()).tagPaths, model.tagPaths);
      expect(model.attributes?.containsKey('tag_paths'), false);
      final mapped = studyCardFromModel(model)!;
      expect(mapped.isPhraseCard, true);
      final db = CardsDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      const mapper = DriftCardsMapper();
      await db
          .into(db.localStudyCards)
          .insert(
            mapper.cardToCompanion(
              mapped,
              accountKey: 'test',
              syncState: CardLocalSyncState.synced,
            ),
          );
      final row = await db.select(db.localStudyCards).getSingle();
      expect(mapper.cardFromRow(row).categoryPaths, [
        ['Phrase', 'Greeting'],
      ]);
      final legacy = mapper.cardFromRow(
        row.copyWith(
          tagsJson: jsonEncode({
            'Category': ['Noun'],
          }),
        ),
      );
      expect(legacy.categoryPaths, [
        ['Word', 'Noun'],
      ]);
    },
  );

  testWidgets(
    'only populated roots, separate expansion, collections and language isolation',
    (tester) async {
      final data = CardsDashboard(
        cards: [
          card(1, [
            ['Word', 'Noun'],
            ['Word', 'Verb'],
          ]),
          card(2, [
            ['Phrase'],
          ]),
          card(
            3,
            [
              ['Script'],
            ],
            language: 'Chinese',
            collections: ['Hidden'],
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cardsCollectionProvider.overrideWith(
              (ref, source) => Stream.value(data),
            ),
          ],
          child: const MaterialApp(home: LanguagePage(language: 'Spanish')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('All'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('All')).dy,
        lessThan(tester.getTopLeft(find.text('Words')).dy),
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('language-category-all-total')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('expand-category-All')), findsNothing);
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<LanguageCategoryPage>(find.byType(LanguageCategoryPage))
            .allCards,
        isTrue,
      );
      expect(find.text('Future  2'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Words'), findsOneWidget);
      expect(find.text('Phrases'), findsOneWidget);
      expect(find.text('Script'), findsNothing);
      expect(find.text('Collections'), findsNothing);
      expect(
        find.byKey(const ValueKey('expand-category-Phrase')),
        findsNothing,
      );
      expect(find.text('Noun'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('language-category-word-total')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('expand-category-Word')));
      await tester.pumpAndSettle();
      expect(find.text('Noun'), findsOneWidget);
      expect(find.byType(LanguageCategoryPage), findsNothing);
      await tester.tap(find.text('Words'));
      await tester.pumpAndSettle();
      expect(find.byType(LanguageCategoryPage), findsOneWidget);
      expect(find.text('Future  1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
