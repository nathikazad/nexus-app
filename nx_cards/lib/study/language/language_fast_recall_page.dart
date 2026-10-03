import 'package:nx_cards/audio/audio_providers.dart';
import 'package:nx_cards/study/language/language_audio_controls.dart';
import 'package:nx_cards/scheduling/study_scope.dart';
import 'package:nx_cards/study/language/tablet_recall_context.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/scheduling/scheduling.dart';
import 'package:nx_cards/app/theme.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/card_details_page.dart';
import 'package:nx_cards/study/session/recall_recap_page.dart';

class LanguageFastRecallPage extends ConsumerStatefulWidget {
  const LanguageFastRecallPage({
    this.studyScope,
    super.key,
    required this.title,
    required this.prompts,
  });

  final StudyScope? studyScope;
  final String title;
  final List<StudyPrompt> prompts;

  @override
  ConsumerState<LanguageFastRecallPage> createState() =>
      _LanguageFastRecallPageState();
}

class _LanguageFastRecallPageState
    extends ConsumerState<LanguageFastRecallPage> {
  final Map<int, StudyCard> _latestCards = <int, StudyCard>{};
  final Map<(int, StudyCue), CardRating> _ratings = {};
  final Set<int> _saving = <int>{};

  late List<StudyPrompt> _prompts;

  void _repeatIncorrect() {
    final missed = retryRecallPrompts(_prompts, {
      for (var i = 0; i < _prompts.length; i++)
        i: ?_ratings[(_prompts[i].cardId, _prompts[i].cue)],
    }, _latestCards);
    if (missed.isEmpty) return;
    setState(() {
      _prompts = missed;
      _ratings.clear();
    });
  }

  @override
  void initState() {
    super.initState();
    _prompts = List.of(widget.prompts);
    for (final prompt in _prompts) {
      _latestCards[prompt.cardId] = prompt.card;
    }
  }

  StudyPrompt _latestPrompt(StudyPrompt queued) =>
      queued.withCard(_latestCards[queued.cardId] ?? queued.card);

  Future<void> _rate(StudyPrompt queued, CardRating rating) async {
    if (_saving.contains(queued.cardId) ||
        _ratings.containsKey((queued.cardId, queued.cue))) {
      return;
    }
    final prompt = _latestPrompt(queued);
    final previousCard = prompt.card;
    final outcome = ref
        .read(cardSchedulerProvider)
        .preview(prompt, DateTime.now().toUtc())[rating]!;
    setState(() {
      _saving.add(queued.cardId);
      _latestCards[queued.cardId] = outcome.card;
      _ratings[(queued.cardId, queued.cue)] = rating;
    });
    try {
      await ref
          .read(cardLibraryProvider)
          .saveSchedule(outcome.card)
          .timeout(const Duration(seconds: 20));
      ref.read(cardsInvalidationProvider)();
    } catch (error) {
      if (mounted) {
        setState(() {
          _latestCards[queued.cardId] = previousCard;
          _ratings.remove((queued.cardId, queued.cue));
        });
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Could not save the review. The card was restored.',
              ),
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _saving.remove(queued.cardId));
    }
  }

  Future<void> _openCard(StudyCard card) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CardDetailsPage(
          card: card,
          allowEdit: false,
          initialTab: CardDetailsTab.examples,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(cardsDashboardProvider);
    if (_ratings.length == _prompts.length && _saving.isEmpty) {
      final missCount = _ratings.values
          .where((rating) => rating == CardRating.again)
          .length;
      return RecallRecapPage(
        studyScope: widget.studyScope,
        onRepeatIncorrect: _repeatIncorrect,
        reviewedCount: _ratings.length,
        totalCount: _prompts.length,
        missCount: missCount,
        entries: [
          for (final prompt in _prompts)
            RecallRecapEntry(
              card: _latestCards[prompt.cardId] ?? prompt.card,
              rating: _ratings[(prompt.cardId, prompt.cue)],
            ),
        ],
      );
    }
    final prompts = _prompts;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.title} · Fast recall')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
            itemCount: prompts.length + 1,
            separatorBuilder: (_, index) => index == 0
                ? const SizedBox(height: 10)
                : const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _FastRecallHeader(
                  total: _prompts.length,
                  reviewed: _ratings.length,
                );
              }
              final queued = prompts[index - 1];
              final prompt = _latestPrompt(queued);
              final content = prompt.card.content;
              if (content is! LanguageCardContent) {
                return const SizedBox.shrink();
              }
              return _FastRecallRow(
                key: ValueKey<String>(
                  'fast-row-${prompt.cardId}-${prompt.cue.storageKey}',
                ),
                number: index,
                prompt: prompt,
                content: content,
                rating: _ratings[(prompt.cardId, prompt.cue)],
                saving: _saving.contains(prompt.cardId),
                onNo: () => _rate(queued, CardRating.again),
                onYes: () => _rate(queued, CardRating.good),
                onOpenCard: () => _openCard(prompt.card),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FastRecallHeader extends StatelessWidget {
  const _FastRecallHeader({required this.total, required this.reviewed});

  final int total;
  final int reviewed;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('FAST RECALL', style: monoLabel),
      const SizedBox(height: 7),
      Text(
        '$reviewed of $total recalled',
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.6,
        ),
      ),
      const SizedBox(height: 12),
    ],
  );
}

class _FastRecallRow extends ConsumerStatefulWidget {
  const _FastRecallRow({
    super.key,
    required this.number,
    required this.prompt,
    required this.content,
    required this.rating,
    required this.saving,
    required this.onNo,
    required this.onYes,
    required this.onOpenCard,
  });

  final int number;
  final StudyPrompt prompt;
  final LanguageCardContent content;
  final CardRating? rating;
  final bool saving;
  final VoidCallback onNo;
  final VoidCallback onYes;
  final VoidCallback onOpenCard;

  @override
  ConsumerState<_FastRecallRow> createState() => _FastRecallRowState();
}

class _FastRecallRowState extends ConsumerState<_FastRecallRow> {
  static const _swipeThreshold = 72.0;
  static const _maximumDrag = 104.0;

  bool _revealed = false;
  bool _hidden = false;
  bool _revealedBeforeDrag = false;
  bool _thresholdHapticSent = false;
  bool _swipeCommitted = false;
  bool _swipeRecalled = false;
  double _dragOffset = 0;

  @override
  void didUpdateWidget(covariant _FastRecallRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rating == null && widget.rating != null) {
      setState(() => _hidden = true);
    } else if (oldWidget.rating != null && widget.rating == null) {
      setState(() {
        _hidden = false;
        _swipeCommitted = false;
        _swipeRecalled = false;
      });
    }
  }

  bool get _canSwipe =>
      !widget.saving && widget.rating == null && !_swipeCommitted;

  void _startSwipe(DragStartDetails details) {
    if (!_canSwipe) return;
    setState(() {
      _revealedBeforeDrag = _revealed;
      _revealed = true;
      _thresholdHapticSent = false;
      _dragOffset = 0;
    });
  }

  void _updateSwipe(DragUpdateDetails details) {
    if (!_canSwipe) return;
    final next = (_dragOffset + details.delta.dx).clamp(
      -_maximumDrag,
      _maximumDrag,
    );
    final crossed = next.abs() >= _swipeThreshold;
    if (crossed && !_thresholdHapticSent) {
      _thresholdHapticSent = true;
      HapticFeedback.selectionClick();
    } else if (!crossed) {
      _thresholdHapticSent = false;
    }
    setState(() => _dragOffset = next.toDouble());
  }

  void _endSwipe(DragEndDetails details) {
    if (!_canSwipe) return;
    if (_dragOffset.abs() < _swipeThreshold) {
      setState(() {
        _dragOffset = 0;
        _revealed = _revealedBeforeDrag;
      });
      return;
    }
    final recalled = _dragOffset > 0;
    setState(() {
      _dragOffset = 0;
      _swipeCommitted = true;
      _swipeRecalled = recalled;
    });
    if (recalled) {
      widget.onYes();
    } else {
      widget.onNo();
    }
  }

  void _cancelSwipe() {
    if (!_canSwipe) return;
    setState(() {
      _dragOffset = 0;
      _revealed = _revealedBeforeDrag;
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
    alignment: Alignment.topCenter,
    child: _hidden
        ? const SizedBox.shrink()
        : Column(
            children: [
              ClipRect(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _FastSwipeBackground(offset: _dragOffset),
                    ),
                    AnimatedContainer(
                      duration: _dragOffset == 0
                          ? const Duration(milliseconds: 170)
                          : Duration.zero,
                      curve: Curves.easeOutCubic,
                      transform: Matrix4.translationValues(_dragOffset, 0, 0),
                      color: RecallPalette.of(context).surface,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragStart: _canSwipe ? _startSwipe : null,
                        onHorizontalDragUpdate: _canSwipe ? _updateSwipe : null,
                        onHorizontalDragEnd: _canSwipe ? _endSwipe : null,
                        onHorizontalDragCancel: _canSwipe ? _cancelSwipe : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 30,
                                child: Text(
                                  widget.number.toString().padLeft(2, '0'),
                                  style: monoLabel,
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            onTap: _revealed
                                                ? widget.onOpenCard
                                                : null,
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                top: 4,
                                              ),
                                              child: Text(
                                                widget.prompt.prompt,
                                                key: ValueKey<String>(
                                                  'fast-prompt-${widget.prompt.cardId}',
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  height: 1.35,
                                                  color: RecallColors.muted,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        if ((_revealed ||
                                                widget.prompt.isListening) &&
                                            widget
                                                    .content
                                                    .audioUrl
                                                    ?.isNotEmpty ==
                                                true &&
                                            ref.watch(
                                                  cardAudioRepositoryProvider,
                                                ) !=
                                                null)
                                          PronunciationButton(
                                            key: ValueKey(
                                              'pronunciation:$_revealed',
                                            ),
                                            audioUrl: widget.content.audioUrl!,
                                            repository: ref.watch(
                                              cardAudioRepositoryProvider,
                                            )!,
                                            // Fast recall shows multiple rows; play only the row requested.
                                            autoPlay: _revealed,
                                          ),

                                        if (!_revealed) ...[
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: InkWell(
                                              key: ValueKey<String>(
                                                'fast-hidden-${widget.prompt.cardId}',
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              onTap: () => setState(
                                                () => _revealed = true,
                                              ),
                                              child: const Padding(
                                                padding: EdgeInsets.symmetric(
                                                  vertical: 3,
                                                ),
                                                child: Text(
                                                  'Tap to reveal',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: RecallColors.faint,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (_revealed) ...[
                                      const SizedBox(height: 10),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: InkWell(
                                              key: ValueKey<String>(
                                                'fast-answer-${widget.prompt.cardId}',
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              onTap: widget.onOpenCard,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                      vertical: 2,
                                                    ),
                                                child: _FastAnswer(
                                                  prompt: widget.prompt,
                                                  content: widget.content,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          SizedBox(
                                            width: 84,
                                            child: _swipeCommitted
                                                ? Icon(
                                                    _swipeRecalled
                                                        ? Icons
                                                              .thumb_up_alt_outlined
                                                        : Icons
                                                              .thumb_down_alt_outlined,
                                                    size: 18,
                                                    color: RecallColors.muted,
                                                  )
                                                : widget.saving
                                                ? const Center(
                                                    child: SizedBox.square(
                                                      dimension: 18,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                    ),
                                                  )
                                                : widget.rating != null
                                                ? Icon(
                                                    widget.rating ==
                                                            CardRating.good
                                                        ? Icons
                                                              .thumb_up_alt_outlined
                                                        : Icons
                                                              .thumb_down_alt_outlined,
                                                    size: 18,
                                                    color: RecallColors.muted,
                                                  )
                                                : Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.end,
                                                    children: [
                                                      IconButton(
                                                        key: ValueKey<String>(
                                                          'fast-yes-${widget.prompt.cardId}',
                                                        ),
                                                        tooltip: 'Recalled',
                                                        visualDensity:
                                                            VisualDensity
                                                                .compact,
                                                        constraints:
                                                            const BoxConstraints.tightFor(
                                                              width: 36,
                                                              height: 36,
                                                            ),
                                                        padding:
                                                            const EdgeInsets.all(
                                                              7,
                                                            ),
                                                        onPressed: widget.onYes,
                                                        icon: const Icon(
                                                          Icons
                                                              .thumb_up_alt_outlined,
                                                          size: 19,
                                                        ),
                                                      ),
                                                      IconButton(
                                                        key: ValueKey<String>(
                                                          'fast-no-${widget.prompt.cardId}',
                                                        ),
                                                        tooltip:
                                                            'Did not recall',
                                                        visualDensity:
                                                            VisualDensity
                                                                .compact,
                                                        constraints:
                                                            const BoxConstraints.tightFor(
                                                              width: 36,
                                                              height: 36,
                                                            ),
                                                        padding:
                                                            const EdgeInsets.all(
                                                              7,
                                                            ),
                                                        onPressed: widget.onNo,
                                                        icon: const Icon(
                                                          Icons
                                                              .thumb_down_alt_outlined,
                                                          size: 19,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_revealed && TabletRecallContext.visibleOn(context))
                TabletRecallContext(
                  key: ValueKey('fast-context-${widget.prompt.cardId}'),
                  card: widget.prompt.card,
                ),
            ],
          ),
  );
}

class _FastSwipeBackground extends StatelessWidget {
  const _FastSwipeBackground({required this.offset});

  final double offset;

  @override
  Widget build(BuildContext context) {
    final recalled = offset >= 0;
    return ColoredBox(
      color: recalled ? const Color(0xffecfdf5) : const Color(0xfffff1f2),
      child: Align(
        alignment: recalled ? Alignment.centerLeft : Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Icon(
            recalled
                ? Icons.thumb_up_alt_outlined
                : Icons.thumb_down_alt_outlined,
            color: recalled ? RecallColors.emerald : RecallColors.rose,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _FastAnswer extends StatelessWidget {
  const _FastAnswer({required this.prompt, required this.content});

  final StudyPrompt prompt;
  final LanguageCardContent content;

  @override
  Widget build(BuildContext context) {
    final primary = content.spokenOnly
        ? (prompt.isListening ? content.english : content.transliteration)
        : content.originalScript;
    final secondary = content.spokenOnly && prompt.isListening
        ? content.transliteration
        : content.english;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          primary,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 20,
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          secondary,
          style: const TextStyle(
            fontSize: 14,
            height: 1.35,
            fontStyle: FontStyle.italic,
            color: RecallColors.faint,
          ),
        ),
        if (!content.spokenOnly && content.transliteration.isNotEmpty)
          Text(
            content.transliteration,
            style: const TextStyle(fontSize: 14, color: RecallColors.faint),
          ),
      ],
    );
  }
}
