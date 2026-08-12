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
      builder: (context, _) => PopScope(
        canPop: controller.phase == VoiceStudyPhase.completed,
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text(widget.title),
            actions: [
              if (controller.phase != VoiceStudyPhase.completed)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: TextButton(
                    onPressed: controller.end,
                    child: const Text('End'),
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
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${controller.reviewedCount}/${controller.total}',
                          style: monoLabel.copyWith(color: RecallColors.muted),
                        ),
                      ),
                      if (controller.phase == VoiceStudyPhase.completed)
                        Expanded(child: _SessionBody(controller: controller))
                      else ...[
                        const Spacer(),
                        _SessionBody(controller: controller),
                        const Spacer(),
                        _VoiceControls(controller: controller),
                        const SizedBox(height: 18),
                        const Text(
                          'The voice session keeps running while this app is in the background. End it here when you are done.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: RecallColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
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
      return SingleChildScrollView(
        child: Column(
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
              '${controller.reviewedCount} of ${controller.total} cards reviewed',
              style: const TextStyle(color: RecallColors.muted),
            ),
            const SizedBox(height: 20),
            if (controller.answerReveal case final reveal?) ...[
              _AssessmentResult(
                rating: reveal.rating,
                feedback: reveal.feedback,
              ),
              const SizedBox(height: 12),
              _AnswerReveal(reveal: reveal),
              const SizedBox(height: 20),
            ],
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 24,
              runSpacing: 12,
              children: [
                _SummaryStat(
                  value: '${controller.correctCount}',
                  label: 'Correct',
                  color: RecallColors.emerald,
                ),
                _SummaryStat(
                  value: '${controller.partialCount}',
                  label: 'Partial',
                  color: RecallColors.orange,
                ),
                _SummaryStat(
                  value: '${controller.incorrectCount}',
                  label: 'Incorrect',
                  color: RecallColors.rose,
                ),
              ],
            ),
            const SizedBox(height: 26),
            if (controller.recapEntries.isNotEmpty) ...[
              _WordRecap(entries: controller.recapEntries),
              const SizedBox(height: 18),
            ],
            _UsageRecap(controller: controller),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Return to categories'),
            ),
          ],
        ),
      );
    }

    final prompt = controller.displayedPrompt;
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
        if (controller.answerReveal case final reveal?) ...[
          const SizedBox(height: 22),
          _AssessmentResult(rating: reveal.rating, feedback: reveal.feedback),
          const SizedBox(height: 10),
          _AnswerReveal(reveal: reveal),
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

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
      ),
      Text(label, style: const TextStyle(color: RecallColors.muted)),
    ],
  );
}

class _WordRecap extends StatelessWidget {
  const _WordRecap({required this.entries});

  final List<VoiceStudyRecapEntry> entries;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('WORDS', style: monoLabel),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          border: Border.all(color: RecallColors.ink.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            for (var index = 0; index < entries.length; index += 1) ...[
              if (index > 0)
                Divider(
                  height: 1,
                  color: RecallColors.ink.withValues(alpha: 0.1),
                ),
              _WordRecapRow(entry: entries[index]),
            ],
          ],
        ),
      ),
    ],
  );
}

class _WordRecapRow extends StatelessWidget {
  const _WordRecapRow({required this.entry});

  final VoiceStudyRecapEntry entry;

  @override
  Widget build(BuildContext context) {
    final (result, color) = switch (entry.rating) {
      CardRating.again => ('INCORRECT', RecallColors.rose),
      CardRating.hard => ('PARTLY RIGHT', RecallColors.orange),
      CardRating.good || CardRating.easy => ('CORRECT', RecallColors.emerald),
      null => ('NOT REVIEWED', RecallColors.muted),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.english,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.malayalam,
                  style: const TextStyle(fontSize: 18, height: 1.2),
                ),
                if (entry.transliteration.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.transliteration,
                    style: const TextStyle(
                      color: RecallColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(result, style: monoLabel.copyWith(color: color)),
              const SizedBox(height: 6),
              Text(
                '${entry.tokens} tokens',
                style: monoLabel.copyWith(color: RecallColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UsageRecap extends StatelessWidget {
  const _UsageRecap({required this.controller});

  final VoiceStudyController controller;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: RecallColors.ink.withValues(alpha: 0.045),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('GPT-REALTIME-2.1 MINI USAGE', style: monoLabel),
        const SizedBox(height: 12),
        _UsageRow(
          label: 'Input',
          tokens: controller.usage.billedInputTokens,
          cost: controller.inputCost,
        ),
        const SizedBox(height: 8),
        _UsageRow(
          label: 'Output',
          tokens: controller.usage.billedOutputTokens,
          cost: controller.outputCost,
        ),
        const Divider(height: 22),
        _UsageRow(
          label: 'Total',
          tokens: controller.usage.totalTokens,
          cost: controller.totalCost,
          emphasized: true,
        ),
      ],
    ),
  );
}

class _UsageRow extends StatelessWidget {
  const _UsageRow({
    required this.label,
    required this.tokens,
    required this.cost,
    this.emphasized = false,
  });

  final String label;
  final int tokens;
  final double cost;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: emphasized ? RecallColors.ink : RecallColors.muted,
      fontWeight: emphasized ? FontWeight.w700 : FontWeight.w400,
    );
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text('$tokens tokens', style: style),
        const SizedBox(width: 18),
        SizedBox(
          width: 74,
          child: Text(
            _formatCost(cost),
            textAlign: TextAlign.right,
            style: style,
          ),
        ),
      ],
    );
  }
}

String _formatCost(double cost) {
  if (cost > 0 && cost < 0.0001) return '<\$0.0001';
  return '\$${cost.toStringAsFixed(4)}';
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

class _AnswerReveal extends StatelessWidget {
  const _AnswerReveal({required this.reveal});

  final VoiceStudyAnswerReveal reveal;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: RecallColors.ink.withValues(alpha: 0.045),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        _AnswerValue(label: 'ENGLISH', value: reveal.english),
        const Divider(height: 20),
        _AnswerValue(
          label: 'MALAYALAM',
          value: reveal.malayalam,
          primary: true,
        ),
        const SizedBox(height: 8),
        _AnswerValue(label: 'TRANSLITERATION', value: reveal.transliteration),
      ],
    ),
  );
}

class _AnswerValue extends StatelessWidget {
  const _AnswerValue({
    required this.label,
    required this.value,
    this.primary = false,
  });

  final String label;
  final String value;
  final bool primary;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 118, child: Text(label, style: monoLabel)),
      Expanded(
        child: Text(
          value.isEmpty ? '—' : value,
          textAlign: TextAlign.right,
          style: TextStyle(
            color: value.isEmpty ? RecallColors.muted : RecallColors.ink,
            fontSize: primary ? 21 : 16,
            height: 1.2,
            fontWeight: primary ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    ],
  );
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
