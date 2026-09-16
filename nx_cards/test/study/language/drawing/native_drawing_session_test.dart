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
