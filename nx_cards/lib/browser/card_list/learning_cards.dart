import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/app/theme.dart';
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
    this.showScheduleStatus = false,
    this.previousStatus,
    this.previousActionLabel,
    this.nextStatus,
    this.actionLabel,
  });

  final List<StudyCard> cards;
  final String emptyText;
  final CardsDashboard dashboard;
  final bool showScheduleStatus;
  final LearningStatus? previousStatus;
  final String? previousActionLabel;
  final LearningStatus? nextStatus;
  final String? actionLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) => RefreshIndicator(
    onRefresh: ref.read(cardsLibrarySyncProvider),
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: cards.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: RecallColors.soft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: RecallColors.line),
                    ),
                    child: Text(
                      emptyText,
                      style: const TextStyle(color: RecallColors.muted),
                    ),
                  )
                : Column(
                    children: [
                      for (final card in cards)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: _LearningStatusRow(
                            key: ValueKey(
                              '${card.learningStatus.storageValue}:${card.id}',
                            ),
                            card: card,
                            showScheduleStatus: showScheduleStatus,
                            previousStatus: previousStatus,
                            previousActionLabel: previousActionLabel,
                            nextStatus: nextStatus,
                            actionLabel: actionLabel,
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    ),
  );
}

class _LearningStatusRow extends ConsumerStatefulWidget {
  const _LearningStatusRow({
    super.key,
    required this.card,
    required this.showScheduleStatus,
    this.previousStatus,
    this.previousActionLabel,
    this.nextStatus,
    this.actionLabel,
  });

  final StudyCard card;
  final bool showScheduleStatus;
  final LearningStatus? previousStatus;
  final String? previousActionLabel;
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
      widget.previousStatus != null || widget.nextStatus != null;

  void _drag(DragUpdateDetails details) {
    if (!_canDrag) return;
    final minimum = widget.nextStatus == null ? 0.0 : -_actionWidth;
    final maximum = widget.previousStatus == null ? 0.0 : _actionWidth;
    setState(() {
      _dragging = true;
      _offset = (_offset + details.delta.dx).clamp(minimum, maximum).toDouble();
    });
  }

  void _finishDrag(DragEndDetails details) {
    final reveal = _offset.abs() >= _actionWidth * .42;
    final status = _offset < 0 ? widget.nextStatus : widget.previousStatus;
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
      ref.invalidate(cardsDashboardProvider);
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
    if (edit == true && mounted) ref.invalidate(cardsDashboardProvider);
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.card.content;
    final transliteration = content is LanguageCardContent
        ? content.transliteration
        : '';
    final scheduleStatus = cardScheduleStatus(
      widget.card,
      DateTime.now().toUtc(),
      historyWindow:
          ref.watch(reviewProgressionSettingsProvider).value?.historyWindow ??
          5,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: RecallColors.ink,
              child: Stack(
                children: [
                  if (widget.previousStatus case final status?)
                    _statusAction(
                      alignment: Alignment.centerLeft,
                      status: status,
                      label: widget.previousActionLabel ?? '',
                    ),
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
                  color: Colors.white,
                  border: Border.all(color: RecallColors.line),
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
                              if (widget.showScheduleStatus &&
                                  scheduleStatus != null) ...[
                                const SizedBox(width: 9),
                                _ScheduleStatePill(status: scheduleStatus),
                              ],
                            ],
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
                                    color: RecallColors.ink,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'DUE',
                                    style: TextStyle(
                                      color: Colors.white,
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
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.drag_indicator,
                      size: 17,
                      color: RecallColors.faint,
                    ),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
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
      'Learning' => (const Color(0xfffff7ed), RecallColors.orange),
      'Relearning' => (const Color(0xfffff1f2), RecallColors.rose),
      'Retained' => (const Color(0xffecfdf5), RecallColors.emerald),
      'New' => (const Color(0xfff0f9ff), RecallColors.sky),
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
        status.label == 'New'
            ? 'NEW'
            : '${status.label.toUpperCase()}  ${status.recallPercentage}%',
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
