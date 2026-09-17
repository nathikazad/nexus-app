import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/study/language/drawing/native_drawing_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final card = StudyCard(
    id: 1,
    content: const LanguageCardContent(
      english: 'a long sentence',
      originalScript: '很长的句子',
      transliteration: 'hěn cháng de jùzi',
      audioUrl: '/audio.mp3',
      examples: [
        LanguageExample(
          text: '这是很长的句子。',
          transliteration: 'zhè shì hěn cháng de jùzi',
          translation: 'This is a long sentence.',
          audioUrl: '/example.mp3',
        ),
        LanguageExample(
          text: '很长的句子',
          transliteration: 'hěn cháng de jùzi',
          translation: 'a long sentence',
        ),
      ],
    ),
    schedules: const {},
    reviewHistory: const {},
    suspended: false,
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(NativeDrawingSession.channel, null);
  });
  test('recall preserves cue direction and optional transliteration', () {
    final from = NativeDrawingSession.recallCard(
      StudyPrompt(
        card: card,
        cue: StudyCue.fromLanguage,
        showEnglishAndTransliteration: true,
      ),
    );
    expect(from['prompt'], 'a long sentence\nhěn cháng de jùzi');
    expect(from['answer'], '很长的句子');
    final to = NativeDrawingSession.recallCard(
      StudyPrompt(card: card, cue: StudyCue.toLanguage),
    );
    expect(to['prompt'], '很长的句子');
    expect(to['answer'], 'a long sentence');
    expect(NativeDrawingSession.practiceCard(card)['audio'], isTrue);
  });
  test('Android opens a native session with its complete queue', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(NativeDrawingSession.channel, (
      call,
    ) async {
      calls.add(call);
      return call.method == 'available' ? true : null;
    });
    expect(
      await NativeDrawingSession.open(
        title: 'Practice',
        cards: [NativeDrawingSession.practiceCard(card)],
        recall: false,
        onAction: (_) async => null,
      ),
      isTrue,
    );
    expect(calls.map((c) => c.method), ['available', 'open']);
    expect(calls.last.arguments['recall'], isFalse);
    expect(calls.last.arguments['cards'], hasLength(1));
  });
  test('practice sends incoming examples and suppresses self examples', () {
    final practice = NativeDrawingSession.practiceCard(card);
    expect(practice['examples'], [
      {
        'text': '这是很长的句子。',
        'transliteration': 'zhè shì hěn cháng de jùzi',
        'translation': 'This is a long sentence.',
        'audio': true,
      },
    ]);
    expect(
      NativeDrawingSession.recallCard(
        StudyPrompt(card: card, cue: StudyCue.toLanguage),
      ).containsKey('examples'),
      isFalse,
    );
  });
  test('character breakdown follows saved links in reading order safely', () {
    StudyCard part(int id, String text, Set<int> links) => StudyCard(
      id: id,
      content: LanguageCardContent(
        originalScript: text,
        transliteration: 'sound $id',
        english: 'meaning $id',
        audioUrl: '/$id.mp3',
      ),
      linkedWordIds: links,
      schedules: const {},
      reviewHistory: const {},
      suspended: false,
    );
    final phrase = part(10, '学生。', {11, 999});
    final word = part(11, '学生', {13, 12, 10});
    final first = part(12, '学', {});
    final second = part(13, '生', {});
    final unlinked = part(14, '学', {});
    final library = {
      for (final item in [phrase, word, first, second, unlinked]) item.id: item,
    };
    final parts = NativeDrawingSession.characterParts(phrase, library);
    expect(parts.map((p) => p.originalScript), ['学', '生']);
    final payload = NativeDrawingSession.practiceCard(
      phrase,
      characters: parts,
    );
    expect(payload['multiCharacter'], isTrue);
    expect((payload['characters'] as List).first, {
      'text': '学',
      'transliteration': 'sound 12',
      'translation': 'meaning 12',
      'audio': true,
    });
    expect(NativeDrawingSession.characterParts(first, library), isEmpty);
    expect(NativeDrawingSession.practiceCard(first)['multiCharacter'], isFalse);
  });
  test(
    'Tamil breakdown preserves combined letters and matches whole letters',
    () {
      StudyCard part(int id, String text, Set<int> links) => StudyCard(
        id: id,
        content: LanguageCardContent(
          originalScript: text,
          transliteration: 'sound $id',
          english: 'meaning $id',
          audioUrl: '/$id.mp3',
        ),
        linkedWordIds: links,
        schedules: const {},
        reviewHistory: const {},
        suspended: false,
      );
      final house = part(1, 'வீடு', {3, 2, 6});
      final vi = part(2, 'வீ', {4, 5});
      final tu = part(3, 'டு', {7, 8});
      final library = {
        for (final card in [
          house,
          vi,
          tu,
          part(4, 'வ்', {}),
          part(5, 'ஈ', {}),
          part(6, 'வ', {}),
          part(7, 'ட்', {}),
          part(8, 'உ', {}),
        ])
          card.id: card,
      };
      final parts = NativeDrawingSession.characterParts(house, library);
      expect(parts.map((p) => p.originalScript), ['வீ', 'டு']);
      expect(parts.map((p) => p.audioUrl), ['/2.mp3', '/3.mp3']);
      expect(
        NativeDrawingSession.practiceCard(house)['multiCharacter'],
        isTrue,
      );
      for (final text in ['வீ', 'க்', 'கொ', 'கொ']) {
        final letter = part(20, text, {4, 5});
        expect(
          NativeDrawingSession.practiceCard(letter)['multiCharacter'],
          isFalse,
        );
        expect(NativeDrawingSession.characterParts(letter, library), isEmpty);
      }
      final eye = part(30, 'கண்', {32, 31});
      final eyeParts = NativeDrawingSession.characterParts(eye, {
        31: part(31, 'க', {}),
        32: part(32, 'ண்', {}),
      });
      expect(eyeParts.map((p) => p.originalScript), ['க', 'ண்']);
    },
  );
  test(
    'iPhone keeps Flutter screens and never opens Android channel',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      messenger.setMockMethodCallHandler(
        NativeDrawingSession.channel,
        (_) async => fail('Android bridge invoked on iOS'),
      );
      expect(
        await NativeDrawingSession.open(
          title: 'Practice',
          cards: [],
          recall: false,
          onAction: (_) async => null,
        ),
        isFalse,
      );
    },
  );
}
