import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/composition/cards_composition.dart';
import 'package:nx_cards/core/theme/app_theme.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_cards/features/voice_study/openai_api_key.dart';
import 'package:nx_cards/features/voice_study/voice_study_controller.dart';
import 'package:nx_live_agent/nx_live_agent.dart';

class VoiceStudyScreen extends ConsumerStatefulWidget {
  const VoiceStudyScreen({
    super.key,
    required this.title,
    required this.prompts,
    required this.deckLanguages,
  });

  final String title;
  final List<StudyPrompt> prompts;
  final Map<int, VoiceStudyDeckLanguages> deckLanguages;

  @override
  ConsumerState<VoiceStudyScreen> createState() => _VoiceStudyScreenState();
}

class _VoiceStudyScreenState extends ConsumerState<VoiceStudyScreen> {
  late final VoiceStudyController controller;

  @override
  void initState() {
    super.initState();
    controller = VoiceStudyController(
      session: LiveAgentSession(transport: OpenAiRealtimeTransport()),
      repository: ref.read(cardsRepositoryProvider),
      scheduler: ref.read(cardSchedulerProvider),
      prompts: widget.prompts,
      deckLanguages: widget.deckLanguages,
      onScheduleSaved: () => ref.invalidate(cardsDashboardProvider),
    );
    unawaited(
      controller.start(StaticLiveAgentCredentialProvider(openAiApiKey)),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 18),
              child: Center(
                child: Text(
                  '${controller.reviewedCount}/${controller.total}',
                  style: const TextStyle(color: RecallColors.muted),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LinearProgressIndicator(
                      value: controller.progress,
                      minHeight: 3,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    const Spacer(),
                    _SessionBody(controller: controller),
                    const Spacer(),
                    _VoiceControls(controller: controller),
                    const SizedBox(height: 18),
                    const Text(
                      'The voice session keeps running while this app is in the background. End it here when you are done.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: RecallColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionBody extends StatelessWidget {
  const _SessionBody({required this.controller});

  final VoiceStudyController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.phase == VoiceStudyPhase.error) {
      return Column(
        children: [
          const Icon(Icons.error_outline, size: 54, color: RecallColors.orange),
          const SizedBox(height: 18),
          const Text(
            'Voice tutor could not start',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Text(
            controller.error ?? 'Unknown error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: RecallColors.muted),
          ),
        ],
      );
    }
    if (controller.phase == VoiceStudyPhase.completed) {
      return Column(
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 62,
            color: RecallColors.emerald,
          ),
          const SizedBox(height: 18),
          const Text(
            'Session complete',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '${controller.reviewedCount} cards reviewed',
            style: const TextStyle(color: RecallColors.muted),
          ),
        ],
      );
    }

    final prompt = controller.currentPrompt;
    return Column(
      children: [
        _StatusOrb(phase: controller.phase),
        const SizedBox(height: 20),
        Text(_phaseLabel(controller.phase), style: monoLabel),
        const SizedBox(height: 18),
        if (prompt != null)
          Text(
            prompt.prompt,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 31,
              height: 1.2,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
        if (controller.assessmentRating != null) ...[
          const SizedBox(height: 22),
          _AssessmentResult(
            rating: controller.assessmentRating!,
            feedback: controller.feedback,
          ),
        ],
        if (controller.currentCardAssessed) ...[
          const SizedBox(height: 14),
          Text(
            'ANSWER SAVED · ASK A FOLLOW-UP OR SAY “NEXT”',
            textAlign: TextAlign.center,
            style: monoLabel,
          ),
        ],
        if (controller.userTranscript.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          _LatestTurn(label: 'YOU', text: controller.userTranscript.trim()),
        ],
        if (controller.assistantTranscript.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          _LatestTurn(
            label: 'AI',
            text: controller.assistantTranscript.trim(),
            scrollable: true,
          ),
        ],
      ],
    );
  }
}

class _LatestTurn extends StatelessWidget {
  const _LatestTurn({
    required this.label,
    required this.text,
    this.scrollable = false,
  });

  final String label;
  final String text;
  final bool scrollable;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: RecallColors.ink.withValues(alpha: 0.045),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 34, child: Text(label, style: monoLabel)),
        const SizedBox(width: 8),
        Expanded(
          child: scrollable
              ? ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 132),
                  child: Scrollbar(
                    child: SingleChildScrollView(
                      child: Text(
                        text,
                        style: const TextStyle(
                          fontSize: 13,
                          color: RecallColors.muted,
                        ),
                      ),
                    ),
                  ),
                )
              : Text(
                  text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: RecallColors.muted,
                  ),
                ),
        ),
      ],
    ),
  );
}

class _AssessmentResult extends StatelessWidget {
  const _AssessmentResult({required this.rating, required this.feedback});

  final CardRating rating;
  final String feedback;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (rating) {
      CardRating.again => (
        'INCORRECT',
        Icons.cancel_outlined,
        RecallColors.rose,
      ),
      CardRating.hard => (
        'PARTLY RIGHT',
        Icons.adjust_rounded,
        RecallColors.orange,
      ),
      CardRating.good || CardRating.easy => (
        'CORRECT',
        Icons.check_circle_outline,
        RecallColors.emerald,
      ),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: monoLabel.copyWith(color: color)),
                if (feedback.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    feedback,
                    style: const TextStyle(
                      fontSize: 14,
                      color: RecallColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusOrb extends StatelessWidget {
  const _StatusOrb({required this.phase});

  final VoiceStudyPhase phase;

  @override
  Widget build(BuildContext context) {
    final active =
        phase == VoiceStudyPhase.listening || phase == VoiceStudyPhase.speaking;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: active ? 92 : 76,
      height: active ? 92 : 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: phase == VoiceStudyPhase.listening
            ? RecallColors.emerald
            : RecallColors.violet,
        boxShadow: active
            ? [
                BoxShadow(
                  color:
                      (phase == VoiceStudyPhase.listening
                              ? RecallColors.emerald
                              : RecallColors.violet)
                          .withValues(alpha: 0.24),
                  blurRadius: 28,
                  spreadRadius: 8,
                ),
              ]
            : null,
      ),
      child: Icon(
        phase == VoiceStudyPhase.listening
            ? Icons.mic
            : phase == VoiceStudyPhase.paused
            ? Icons.pause
            : Icons.graphic_eq,
        color: Colors.white,
        size: 34,
      ),
    );
  }
}

class _VoiceControls extends StatelessWidget {
  const _VoiceControls({required this.controller});

  final VoiceStudyController controller;

  @override
  Widget build(BuildContext context) {
    final unavailable =
        controller.phase == VoiceStudyPhase.connecting ||
        controller.phase == VoiceStudyPhase.error ||
        controller.phase == VoiceStudyPhase.completed;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton.filledTonal(
          tooltip: controller.muted ? 'Unmute' : 'Mute',
          onPressed: unavailable ? null : controller.toggleMuted,
          icon: Icon(controller.muted ? Icons.mic_off : Icons.mic),
        ),
        const SizedBox(width: 14),
        FilledButton.icon(
          onPressed: unavailable ? null : controller.togglePaused,
          icon: Icon(
            controller.phase == VoiceStudyPhase.paused
                ? Icons.play_arrow
                : Icons.pause,
          ),
          label: Text(
            controller.phase == VoiceStudyPhase.paused ? 'Resume' : 'Pause',
          ),
        ),
        const SizedBox(width: 14),
        IconButton.filledTonal(
          tooltip: 'Repeat question',
          onPressed: unavailable ? null : controller.repeat,
          icon: const Icon(Icons.replay),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Skip card',
          onPressed: unavailable ? null : controller.skip,
          icon: const Icon(Icons.skip_next),
        ),
      ],
    );
  }
}

String _phaseLabel(VoiceStudyPhase phase) => switch (phase) {
  VoiceStudyPhase.idle => 'READY',
  VoiceStudyPhase.connecting => 'CONNECTING',
  VoiceStudyPhase.listening => 'LISTENING',
  VoiceStudyPhase.thinking => 'THINKING',
  VoiceStudyPhase.speaking => 'SPEAKING',
  VoiceStudyPhase.paused => 'PAUSED',
  VoiceStudyPhase.completed => 'COMPLETE',
  VoiceStudyPhase.error => 'ERROR',
};
