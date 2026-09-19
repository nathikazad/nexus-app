import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/audio/audio_providers.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/browser/card_details_page.dart';

class EditingLibrary implements CardLibrary {
  CardContent? saved;
  int? savedId;
  bool fail = false;
  @override
  Future<void> updateCardContent({
    required int id,
    required CardContent content,
  }) async {
    if (fail) throw StateError('offline');
    saved = content;
    savedId = id;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final card = StudyCard(
    id: 42,
    content: const LanguageCardContent(
      english: 'house',
      originalScript: 'வீடு',
      transliteration: 'vīṭu',
      audioUrl: '/house.mp3',
      examples: [
        LanguageExample(
          text: 'example',
          transliteration: 'sound',
          translation: 'meaning',
        ),
      ],
    ),
    schedules: const {},
    reviewHistory: const {},
    suspended: false,
  );
  Future<void> open(WidgetTester tester, EditingLibrary library) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardAudioRepositoryProvider.overrideWithValue(null),
          cardLibraryProvider.overrideWithValue(library),
          cardsInvalidationProvider.overrideWithValue(() {}),
        ],
        child: MaterialApp(home: CardDetailsPage(card: card)),
      ),
    );
    await tester.tap(find.byTooltip('Edit card'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Edit saves three fields and updates details, preserving audio and examples',
    (tester) async {
      final library = EditingLibrary();
      await open(tester, library);
      expect(find.byType(TextFormField), findsNWidgets(3));
      await tester.enterText(find.byType(TextFormField).at(0), 'home');
      await tester.enterText(find.byType(TextFormField).at(1), 'வீட்டில்');
      await tester.enterText(find.byType(TextFormField).at(2), 'vīṭṭil');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(library.savedId, 42);
      final content = library.saved as LanguageCardContent;
      expect(
        [content.front, content.back, content.transliteration],
        ['home', 'வீட்டில்', 'vīṭṭil'],
      );
      expect(content.audioUrl, '/house.mp3');
      expect(content.examples.single.text, 'example');
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('home'), findsOneWidget);
      expect(find.text('வீட்டில்'), findsOneWidget);
    },
  );
  testWidgets('Cancel does not save and empty front is rejected', (
    tester,
  ) async {
    final library = EditingLibrary();
    await open(tester, library);
    await tester.enterText(find.byType(TextFormField).first, '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the front.'), findsOneWidget);
    expect(library.saved, isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(library.saved, isNull);
  });
  testWidgets('Failed save keeps edits available for retry', (tester) async {
    final library = EditingLibrary()..fail = true;
    await open(tester, library);
    await tester.enterText(find.byType(TextFormField).first, 'home');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not save your changes. Please try again.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextFormField, 'home'), findsOneWidget);
    library.fail = false;
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(library.saved?.front, 'home');
  });
}
