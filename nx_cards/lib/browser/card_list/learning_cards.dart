import 'package:nx_cards/browser/card_list/scroll_position_indicator.dart';
import 'package:nx_cards/browser/card_list/bulk_card_selection.dart';
import 'package:nx_cards/scheduling/retention.dart';
import 'package:nx_cards/scheduling/language_direction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/app/theme.dart';
import 'package:nx_cards/audio/audio_providers.dart';
import 'package:nx_cards/study/language/language_audio_controls.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/browser/card_list/card_schedule_status.dart';
import 'package:nx_cards/browser/card_details_page.dart';
import 'package:nx_cards/scheduling/review_progression.dart';

class LearningCardsTab extends ConsumerWidget {
  const LearningCardsTab({
    super.key,
    required this.cards,
    required this.emptyText,
    required this.dashboard,
    this.priorityScores = const {},
    this.scoreDirections,
    this.showScheduleStatus = false,
    this.showLearningStatus = false,
    this.nextStatus,
    this.actionLabel,
  });

  final List<StudyCard> cards;
  final Map<int, double> priorityScores;
  final Set<StudyCue>? scoreDirections;
  final String emptyText;
  final CardsDashboard dashboard;
  final bool showScheduleStatus;
  final bool showLearningStatus;
  final LearningStatus? nextStatus;
  final String? actionLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) => LayoutBuilder(
    builder: (context, constraints) {
      final width = (constraints.maxWidth - 48).clamp(0.0, 1200.0);
      final scale = (MediaQuery.textScalerOf(context).scale(16) / 16).clamp(
        1.0,
        2.0,
      );
      final columns = ((width + 10) / (430 * scale + 10)).floor().clamp(1, 2);
      final rows = (cards.length / columns).ceil();
      return RefreshIndicator(
        onRefresh: ref.read(cardsLibrarySyncProvider),
        child: ScrollPositionIndicator(
          builder: (controller) => ListView.builder(
            controller: controller,
            primary: false,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            itemCount: cards.isEmpty ? 1 : rows,
            itemBuilder: (context, row) => Center(
              child: SizedBox(
                width: width,
                child: cards.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: RecallPalette.of(context).soft,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: RecallPalette.of(context).line,
                          ),
                        ),
                        child: Text(
                          emptyText,
                          style: const TextStyle(color: RecallColors.muted),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 19),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (
                              var column = 0;
                              column < columns;
                              column++
                            ) ...[
                              if (column > 0) const SizedBox(width: 10),
                              Expanded(
                                child: row * columns + column >= cards.length
                                    ? const SizedBox.shrink()
                                    : SelectableCard(
                                        card: cards[row * columns + column],
                                        child: _LearningStatusRow(
                                          key: ValueKey(
                                            '${cards[row * columns + column].learningStatus.storageValue}:${cards[row * columns + column].id}',
                                          ),
                                          card: cards[row * columns + column],
                                          scoreDirections: scoreDirections,
                                          priorityScore:
                                              priorityScores[cards[row *
                                                          columns +
                                                      column]
                                                  .id],
                                          showScheduleStatus:
                                              showScheduleStatus,
                                          showLearningStatus:
                                              showLearningStatus,
                                          nextStatus: nextStatus,
                                          actionLabel: actionLabel,
                                        ),
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
      );
    },
  );
}

class _LearningStatusRow extends ConsumerStatefulWidget {
  const _LearningStatusRow({
    super.key,
    required this.card,
    this.priorityScore,
    this.scoreDirections,
    required this.showScheduleStatus,
    required this.showLearningStatus,
    this.nextStatus,
    this.actionLabel,
  });

  final StudyCard card;
  final double? priorityScore;
  final Set<StudyCue>? scoreDirections;
  final bool showScheduleStatus;
  final bool showLearningStatus;
  final LearningStatus? nextStatus;
  final String? actionLabel;

  @override
  ConsumerState<_LearningStatusRow> createState() => _LearningStatusRowState();
}

class _LearningStatusRowState extends ConsumerState<_LearningStatusRow> {
  static const _actionWidth = 70.0;
  double _offset = 0;
  bool _dragging = false;
  bool _working = false;

  bool get _canDrag =>
      widget.card.learningStatus != LearningStatus.recall &&
      widget.nextStatus != null;

  void _drag(DragUpdateDetails details) {
    if (!_canDrag) return;
    final minimum = widget.nextStatus == null ? 0.0 : -_actionWidth;
    const maximum = 0.0;
    setState(() {
      _dragging = true;
      _offset = (_offset + details.delta.dx).clamp(minimum, maximum).toDouble();
    });
  }

  void _finishDrag(DragEndDetails details) {
    final reveal = _offset.abs() >= _actionWidth * .42;
    final status = _offset < 0 ? widget.nextStatus : null;
    setState(() {
      _dragging = false;
      _offset = reveal && status != null
          ? (_offset < 0 ? -_actionWidth : _actionWidth)
          : 0;
    });
    if (reveal && status != null) _changeStatus(status);
  }

  Future<void> _changeStatus(LearningStatus status) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await ref
          .read(cardLibraryProvider)
          .setLearningStatus(widget.card, status);
      ref.read(cardsInvalidationProvider)();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update word: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
          _offset = 0;
        });
      }
    }
  }

  Future<void> _showDetails() async {
    if (_offset != 0) {
      setState(() => _offset = 0);
      return;
    }
    final edit = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CardDetailsPage(card: widget.card)),
    );
    if (edit == true && mounted) ref.read(cardsInvalidationProvider)();
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.card.content;
    final transliteration = content is LanguageCardContent
        ? content.transliteration
        : '';
    final audioUrl = content is LanguageCardContent ? content.audioUrl : null;
    final audio = audioUrl?.isNotEmpty == true
        ? ref.watch(cardAudioRepositoryProvider)
        : null;
    final originalStatus = cardScheduleStatus(
      widget.card,
      DateTime.now().toUtc(),
      cue: ref.watch(languageDirectionProvider(widget.card.language)),
      historyWindow:
          ref.watch(reviewProgressionSettingsProvider).value?.historyWindow ??
          10,
    );
    final directions =
        widget.scoreDirections ??
        ref.watch<Set<StudyCue>>(
          selectedDirectionsProvider(widget.card.language),
        );
    final scheduleStatus = originalStatus == null
        ? null
        : CardScheduleStatus(
            label: widget.card.suspended
                ? 'Suspended'
                : widget.card.learningStatus.label,
            isDue: false,
            sortPriority: originalStatus.sortPriority,
            recallPercentage: (averageRetention(widget.card, directions) * 100)
                .round(),
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: Theme.of(context).colorScheme.inverseSurface,
              child: Stack(
                children: [
                  if (widget.nextStatus case final status?)
                    _statusAction(
                      alignment: Alignment.centerRight,
                      status: status,
                      label: widget.actionLabel ?? '',
                    ),
                ],
              ),
            ),
          ),
          AnimatedContainer(
            duration: _dragging
                ? Duration.zero
                : const Duration(milliseconds: 170),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(_offset, 0, 0),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: _working || !_canDrag ? null : _drag,
              onHorizontalDragEnd: _working || !_canDrag ? null : _finishDrag,
              onTap: _working ? null : _showDetails,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 17,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.card.front,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (widget.card.spokenOnly) ...[
                                const SizedBox(width: 6),
                                Tooltip(
                                  message: 'Spoken only',
                                  child: Icon(
                                    Icons.volume_up_rounded,
                                    key: ValueKey(
                                      'spoken-only-${widget.card.id}',
                                    ),
                                    size: 16,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    semanticLabel: 'Spoken only',
                                  ),
                                ),
                              ],
                              if (widget.priorityScore case final score?) ...[
                                const SizedBox(width: 9),
                                Tooltip(
                                  message: 'Priority score out of 100',
                                  child: Text(
                                    score.toStringAsFixed(1),
                                    key: ValueKey(
                                      'future-score-${widget.card.id}',
                                    ),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: RecallColors.muted,
                                    ),
                                  ),
                                ),
                              ],
                              if (widget.showScheduleStatus &&
                                  scheduleStatus != null &&
                                  widget.card.learningStatus ==
                                      LearningStatus.recall) ...[
                                const SizedBox(width: 9),
                                _ScheduleStatePill(status: scheduleStatus),
                              ],
                            ],
                          ),
                          if (widget.showLearningStatus)
                            Text(
                              scheduleStatus?.label ?? '',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              widget.card.back,
                              if (transliteration.isNotEmpty) transliteration,
                            ].join('  ·  '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: RecallColors.muted,
                            ),
                          ),
                          if (scheduleStatus?.isDue == true) ...[
                            const SizedBox(height: 7),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  key: ValueKey('word-schedule-due'),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'DUE',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onInverseSurface,
                                      fontFamily: 'monospace',
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: .7,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (audioUrl?.isNotEmpty == true && audio != null) ...[
                      const SizedBox(width: 8),
                      PronunciationButton(
                        key: ValueKey('card-list-audio-${widget.card.id}'),
                        audioUrl: audioUrl!,
                        repository: audio,
                      ),
                    ],
                    if (_canDrag) ...[
                      const SizedBox(width: 12),
                      Icon(
                        Icons.drag_indicator,
                        size: 17,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusAction({
    required Alignment alignment,
    required LearningStatus status,
    required String label,
  }) => Align(
    alignment: alignment,
    child: SizedBox(
      width: _actionWidth,
      child: InkWell(
        onTap: _working ? null : () => _changeStatus(status),
        child: Center(
          child: _working
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
        ),
      ),
    ),
  );
}

class _ScheduleStatePill extends StatelessWidget {
  const _ScheduleStatePill({required this.status});

  final CardScheduleStatus status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (status.label) {
      'Weak' => (const Color(0xfffff7ed), RecallColors.orange),
      'Future' => (const Color(0xfffff1f2), RecallColors.rose),
      'Strong' => (const Color(0xffecfdf5), RecallColors.emerald),
      'Practice' => (const Color(0xfff0f9ff), RecallColors.sky),
      _ => (RecallColors.soft, RecallColors.muted),
    };
    return Container(
      key: ValueKey<String>('word-state-${status.label.toLowerCase()}'),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        status.label == 'Suspended'
            ? 'SUSPENDED'
            : '${status.recallPercentage}%',
        style: TextStyle(
          color: foreground,
          fontFamily: 'monospace',
          fontSize: 8,
          fontWeight: FontWeight.w700,
          letterSpacing: .55,
        ),
      ),
    );
  }
}
