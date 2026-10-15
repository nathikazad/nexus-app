import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/tutor/voice_tutor.dart';
import 'package:nx_cards/tutor/voice_tutor_page.dart';

class _Controller extends Mock implements VoiceTutorController {}

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(320, 568),
    const Size(844, 390),
  ]) {
    testWidgets('long tutor answer scrolls with controls accessible at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = _Controller();
      when(() => controller.phase).thenReturn(VoiceStudyPhase.listening);
      when(() => controller.muted).thenReturn(false);
      when(() => controller.progress).thenReturn(.1);
      when(() => controller.reviewedCount).thenReturn(1);
      when(() => controller.total).thenReturn(10);
      when(() => controller.displayedPrompt).thenReturn(null);
      when(() => controller.currentCardAssessed).thenReturn(true);
      when(() => controller.userTranscript).thenReturn(
        'I was trying to recall this word, but needed more time. ' * 6,
      );
      when(() => controller.assistantTranscript).thenReturn(
        'Here is a longer explanation of this word and its use. ' * 8,
      );
      when(() => controller.answerReveal).thenReturn(
        VoiceStudyAnswerReveal(
          english: 'at; in; to (formal usage)',
          malayalam: '於',
          transliteration: 'yú',
          rating: CardRating.again,
          feedback:
              'The pronunciation was uncertain. Please listen and try again. ' *
              5,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: VoiceStudySessionView(
            title: 'Chinese · Word',
            controller: controller,
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Pause').hitTestable(), findsOneWidget);
      final scroll = find.byType(SingleChildScrollView).first;
      await tester.drag(scroll, const Offset(0, -500));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Pause').hitTestable(), findsOneWidget);
    });
  }
}
