import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/core/theme/app_theme.dart';
import 'package:nx_cards/composition/cards_composition.dart';
import 'package:nx_cards/domain/scheduling/card_scheduler.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_cards/features/cards/card_details_dialog.dart';
import 'package:nx_cards/features/study/language_audio_controls.dart';
import 'package:nx_cards/features/study/language_examples_page.dart';
import 'package:nx_cards/features/study/recall_recap_page.dart';
import 'package:nx_cards/features/study/script_recall_card.dart';
import 'package:nx_cards/features/study/script_recall_policy.dart';

class StudyScreen extends ConsumerStatefulWidget {
  const StudyScreen({super.key, required this.title, required this.prompts});

  final String title;
  final List<StudyPrompt> prompts;

  @override
  ConsumerState<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends ConsumerState<StudyScreen> {
  int _index = 0;
  bool _revealed = false;
  bool _saving = false;
  bool _ended = false;
  bool _scriptDrawingReady = false;
  int _missCount = 0;
  final Map<int, CardRating> _ratings = <int, CardRating>{};
  Map<CardRating, ScheduledOutcome>? _outcomes;
  late final Map<int, StudyCard> _latestCards;

  StudyPrompt get _prompt {
    final queued = widget.prompts[_index];
    return queued.withCard(_latestCards[queued.cardId] ?? queued.card);
  }

  StudyCard get _card => _prompt.card;
  RecallInteraction get _interaction =>
      ScriptRecallPolicy.interactionFor(_prompt);

  @override
  void initState() {
    super.initState();
    _latestCards = <int, StudyCard>{
      for (final prompt in widget.prompts) prompt.cardId: prompt.card,
    };
  }

  void _reveal() {
    if (_revealed) return;
    setState(() {
      _revealed = true;
      _outcomes = ref
          .read(cardSchedulerProvider)
          .preview(_prompt, DateTime.now().toUtc());
    });
  }

  Future<void> _answer(CardRating rating) async {
    if (_saving || _outcomes == null) return;
    setState(() => _saving = true);
    try {
      final updatedCard = _outcomes![rating]!.card;
      await ref.read(cardsRepositoryProvider).saveSchedule(updatedCard);
      _ratings[_index] = rating;
      _latestCards[updatedCard.id] = updatedCard;
      if (rating == CardRating.again) _missCount++;
      ref.invalidate(cardsDashboardProvider);
      if (!mounted) return;
      if (_index + 1 >= widget.prompts.length) {
        setState(() => _index = widget.prompts.length);
      } else {
        setState(() {
          _index++;
          _revealed = false;
          _scriptDrawingReady = false;
          _outcomes = null;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save review: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _endReview() => setState(() => _ended = true);

  Future<void> _openCardDetails() async {
    final dashboard = ref.read(cardsDashboardProvider).value;
    final deck = dashboard?.decks
        .where((candidate) => candidate.id == _card.deckId)
        .firstOrNull;
    if (deck == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Card details are not available yet')),
        );
      }
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            CardDetailsPage(deck: deck, card: _card, allowEdit: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(cardsDashboardProvider);
    if (widget.prompts.isEmpty) return const _EmptyStudyScreen();
    if (_ended || _index >= widget.prompts.length) {
      return RecallRecapPage(
        reviewedCount: _index,
        totalCount: widget.prompts.length,
        missCount: _missCount,
        entries: [
          for (var index = 0; index < widget.prompts.length; index++)
            RecallRecapEntry(
              card:
                  _latestCards[widget.prompts[index].cardId] ??
                  widget.prompts[index].card,
              rating: _ratings[index],
            ),
        ],
      );
    }
    final audioRepository = ref.watch(cardAudioRepositoryProvider);
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.space): _RevealIntent(),
        SingleActivator(LogicalKeyboardKey.digit1): _RateIntent(
          CardRating.again,
        ),
        SingleActivator(LogicalKeyboardKey.digit2): _RateIntent(
          CardRating.good,
        ),
      },
      child: Actions(
        actions: {
          _RevealIntent: CallbackAction<_RevealIntent>(
            onInvoke: (_) => _reveal(),
          ),
          _RateIntent: CallbackAction<_RateIntent>(
            onInvoke: (intent) {
              if (_revealed) _answer(intent.rating);
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
                    child: Column(
                      children: [
                        _StudyHeader(
                          title: widget.title,
                          current: _index + 1,
                          total: widget.prompts.length,
                          onEnd: _endReview,
                        ),
                        const SizedBox(height: 14),
                        LinearProgressIndicator(
                          value: (_index + 1) / widget.prompts.length,
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(9),
                          color: RecallColors.ink,
                          backgroundColor: RecallColors.line,
                        ),
                        const SizedBox(height: 24),
                        Expanded(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: 680,
                                minHeight: 360,
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap:
                                    _interaction == RecallInteraction.standard
                                    ? _reveal
                                    : null,
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          children: [
                                            _Label(
                                              _card.deckName.toUpperCase(),
                                            ),
                                            const Spacer(),
                                            if (_revealed)
                                              IconButton(
                                                onPressed: _openCardDetails,
                                                tooltip: 'Card stats',
                                                icon: const Icon(
                                                  Icons.style_outlined,
                                                  size: 20,
                                                ),
                                              ),
                                          ],
                                        ),
                                        Expanded(
                                          child:
                                              _interaction ==
                                                  RecallInteraction
                                                      .scriptDrawing
                                              ? SingleChildScrollView(
                                                  physics: _revealed
                                                      ? null
                                                      : const NeverScrollableScrollPhysics(),
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 14,
                                                      ),
                                                  child: ScriptRecallCard(
                                                    key: ValueKey<String>(
                                                      'script-recall-${_prompt.cardId}-${_prompt.cue.storageKey}',
                                                    ),
                                                    prompt: _prompt,
                                                    revealed: _revealed,
                                                    audioRepository:
                                                        audioRepository,
                                                    onDrawingChanged: (ready) {
                                                      if (_scriptDrawingReady !=
                                                          ready) {
                                                        setState(
                                                          () =>
                                                              _scriptDrawingReady =
                                                                  ready,
                                                        );
                                                      }
                                                    },
                                                  ),
                                                )
                                              : LayoutBuilder(
                                                  builder: (context, constraints) => SingleChildScrollView(
                                                    child: ConstrainedBox(
                                                      constraints:
                                                          BoxConstraints(
                                                            minHeight:
                                                                constraints
                                                                    .maxHeight,
                                                          ),
                                                      child: Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Text(
                                                            _prompt.prompt,
                                                            textAlign: TextAlign
                                                                .center,
                                                            style: TextStyle(
                                                              fontSize:
                                                                  _revealed
                                                                  ? 22
                                                                  : 38,
                                                              height: 1.2,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              letterSpacing:
                                                                  -0.8,
                                                            ),
                                                          ),
                                                          if (!_revealed)
                                                            const Padding(
                                                              padding:
                                                                  EdgeInsets.only(
                                                                    top: 14,
                                                                  ),
                                                              child: Text(
                                                                'Tap the card to reveal the answer',
                                                                style: TextStyle(
                                                                  color:
                                                                      RecallColors
                                                                          .faint,
                                                                ),
                                                              ),
                                                            )
                                                          else ...[
                                                            const Padding(
                                                              padding:
                                                                  EdgeInsets.symmetric(
                                                                    vertical:
                                                                        22,
                                                                  ),
                                                              child: SizedBox(
                                                                width: 54,
                                                                child:
                                                                    Divider(),
                                                              ),
                                                            ),
                                                            if (_card.content
                                                                case LanguageCardContent(
                                                                  :final english,
                                                                  :final originalScript,
                                                                  :final transliteration,
                                                                )) ...[
                                                              if (_prompt.cue !=
                                                                  StudyCue
                                                                      .fromLanguage) ...[
                                                                Text(
                                                                  english,
                                                                  textAlign:
                                                                      TextAlign
                                                                          .center,
                                                                  style: const TextStyle(
                                                                    fontSize:
                                                                        21,
                                                                    height:
                                                                        1.45,
                                                                    color:
                                                                        RecallColors
                                                                            .ink,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  height: 8,
                                                                ),
                                                              ],
                                                              if (_prompt.cue !=
                                                                  StudyCue
                                                                      .toLanguage)
                                                                Text(
                                                                  originalScript,
                                                                  textAlign:
                                                                      TextAlign
                                                                          .center,
                                                                  style: const TextStyle(
                                                                    fontSize:
                                                                        24,
                                                                    height:
                                                                        1.45,
                                                                    color:
                                                                        RecallColors
                                                                            .ink,
                                                                  ),
                                                                ),
                                                              if (_prompt.cue !=
                                                                  StudyCue
                                                                      .transliteration) ...[
                                                                const SizedBox(
                                                                  height: 10,
                                                                ),
                                                                Text(
                                                                  transliteration,
                                                                  textAlign:
                                                                      TextAlign
                                                                          .center,
                                                                  style: const TextStyle(
                                                                    fontSize:
                                                                        16,
                                                                    height:
                                                                        1.35,
                                                                    fontStyle:
                                                                        FontStyle
                                                                            .italic,
                                                                    color: RecallColors
                                                                        .faint,
                                                                  ),
                                                                ),
                                                              ],
                                                            ] else
                                                              Text(
                                                                _card.back,
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                                style: const TextStyle(
                                                                  fontSize: 21,
                                                                  height: 1.45,
                                                                  color:
                                                                      RecallColors
                                                                          .muted,
                                                                ),
                                                              ),
                                                            if (_card.content
                                                                case LanguageCardContent(
                                                                  audioUrl: final audioUrl?,
                                                                )
                                                                when audioUrl
                                                                        .isNotEmpty &&
                                                                    audioRepository !=
                                                                        null) ...[
                                                              const SizedBox(
                                                                height: 16,
                                                              ),
                                                              LanguageAudioControls(
                                                                key: ValueKey(
                                                                  '${_card.id}:${_prompt.cue.storageKey}:$audioUrl',
                                                                ),
                                                                audioUrl:
                                                                    audioUrl,
                                                                repository:
                                                                    audioRepository,
                                                              ),
                                                            ],
                                                            if (_card.content
                                                                case LanguageCardContent(
                                                                  examples: final examples,
                                                                )
                                                                when examples
                                                                    .isNotEmpty) ...[
                                                              const SizedBox(
                                                                height: 14,
                                                              ),
                                                              TextButton.icon(
                                                                onPressed: () =>
                                                                    Navigator.of(
                                                                      context,
                                                                    ).push(
                                                                      MaterialPageRoute<
                                                                        void
                                                                      >(
                                                                        builder: (_) => LanguageExamplesPage(
                                                                          card:
                                                                              _card,
                                                                          audioRepository:
                                                                              audioRepository,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                icon: const Icon(
                                                                  Icons
                                                                      .menu_book_outlined,
                                                                  size: 17,
                                                                ),
                                                                label:
                                                                    const Text(
                                                                      'Examples',
                                                                    ),
                                                              ),
                                                            ],
                                                          ],
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                        ),
                                        Text(
                                          _revealed
                                              ? 'Did you recall it?'
                                              : 'Reveal answer',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: RecallColors.faint,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (!_revealed)
                          FilledButton.icon(
                            onPressed:
                                _interaction ==
                                        RecallInteraction.scriptDrawing &&
                                    !_scriptDrawingReady
                                ? null
                                : _reveal,
                            icon: const Icon(
                              Icons.visibility_outlined,
                              size: 18,
                            ),
                            label: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              child: Text(
                                _showsSpaceShortcut
                                    ? 'Show answer   Space'
                                    : 'Show answer',
                              ),
                            ),
                          )
                        else if (_revealed)
                          _RatingBar(enabled: !_saving, onRate: _answer),
                      ],
                    ),
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

bool get _showsSpaceShortcut => switch (defaultTargetPlatform) {
  TargetPlatform.macOS ||
  TargetPlatform.windows ||
  TargetPlatform.linux => true,
  _ => false,
};

class _StudyHeader extends StatelessWidget {
  const _StudyHeader({
    required this.title,
    required this.current,
    required this.total,
    required this.onEnd,
  });
  final String title;
  final int current;
  final int total;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 64),
        Expanded(
          child: Column(
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text('$current of $total', style: monoLabel),
            ],
          ),
        ),
        SizedBox(
          width: 64,
          child: TextButton(onPressed: onEnd, child: const Text('End')),
        ),
      ],
    );
  }
}

class _RatingBar extends StatelessWidget {
  const _RatingBar({required this.enabled, required this.onRate});
  final bool enabled;
  final ValueChanged<CardRating> onRate;

  @override
  Widget build(BuildContext context) {
    const ratings = [CardRating.again, CardRating.good];
    const labels = {CardRating.again: 'No', CardRating.good: 'Yes'};
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: Row(
        children: [
          for (final rating in ratings)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _RecallButton(
                  label: labels[rating]!,
                  primary: rating == CardRating.good,
                  onPressed: enabled ? () => onRate(rating) : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecallButton extends StatelessWidget {
  const _RecallButton({
    required this.label,
    required this.primary,
    required this.onPressed,
  });

  final String label;
  final bool primary;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
    return primary
        ? FilledButton(onPressed: onPressed, child: child)
        : OutlinedButton(onPressed: onPressed, child: child);
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xfff5f3ff),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: RecallColors.violet,
        ),
      ),
    ),
  );
}

class _EmptyStudyScreen extends StatelessWidget {
  const _EmptyStudyScreen();
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 48,
            color: RecallColors.emerald,
          ),
          const SizedBox(height: 14),
          const Text(
            'Nothing due right now',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 18),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to categories'),
          ),
        ],
      ),
    ),
  );
}

class _RevealIntent extends Intent {
  const _RevealIntent();
}

class _RateIntent extends Intent {
  const _RateIntent(this.rating);
  final CardRating rating;
}
