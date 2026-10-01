import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/browser_providers.dart';

class BulkCardSelection extends ChangeNotifier {
  int tab = 0;
  bool backlogOnly = false;
  bool practiceOnly = false;
  bool selecting = false;
  bool busy = false;
  final selected = <int>{};
  LearningStatus get source => practiceOnly
      ? LearningStatus.recall
      : tab == 1 && !backlogOnly
      ? LearningStatus.practice
      : LearningStatus.future;
  LearningStatus get destination =>
      backlogOnly || tab == 1 ? LearningStatus.recall : LearningStatus.practice;

  void changeTab(int value) {
    if (tab == value) return;
    tab = value;
    selecting = false;
    selected.clear();
    notifyListeners();
  }

  void setBusy(bool value) {
    busy = value;
    if (!busy && selected.isEmpty) selecting = false;
    notifyListeners();
  }

  void toggleMode() {
    if (busy) return;
    selecting = !selecting;
    selected.clear();
    notifyListeners();
  }

  void toggle(int id) {
    if (busy) return;
    if (!selected.add(id)) selected.remove(id);
    notifyListeners();
  }
}

class _SelectionProvider extends InheritedNotifier<BulkCardSelection> {
  const _SelectionProvider({
    required BulkCardSelection selection,
    required super.child,
  }) : super(notifier: selection);
}

BulkCardSelection? bulkCardSelectionOf(BuildContext context) =>
    context.dependOnInheritedWidgetOfExactType<_SelectionProvider>()?.notifier;

/// One selection per open collection, cleared when changing placement tabs.
class BulkCardSelectionScope extends ConsumerStatefulWidget {
  const BulkCardSelectionScope({
    super.key,
    required this.cards,
    required this.child,
    this.backlogOnly = false,
    this.practiceActionBuilder,
  });
  final bool backlogOnly;
  final Widget Function(List<StudyCard>)? practiceActionBuilder;
  final List<StudyCard> cards;
  final Widget child;
  @override
  ConsumerState<BulkCardSelectionScope> createState() =>
      _BulkCardSelectionScopeState();
}

class _BulkCardSelectionScopeState
    extends ConsumerState<BulkCardSelectionScope> {
  final selection = BulkCardSelection();
  TabController? tabs;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.practiceActionBuilder != null) {
      selection.practiceOnly = true;
      selection.tab = 1;
      return;
    }
    if (widget.backlogOnly) {
      selection.backlogOnly = true;
      selection.tab = 2;
      return;
    }
    final next = DefaultTabController.of(context);
    if (identical(next, tabs)) return;
    tabs?.removeListener(_tabChanged);
    tabs = next;
    selection.tab = next.index;
    next.addListener(_tabChanged);
  }

  void _tabChanged() => selection.changeTab(tabs!.index);

  Future<void> _move() async {
    if (selection.busy || selection.selected.isEmpty) return;
    final source = selection.source;
    final destination = selection.destination;
    final cards = widget.cards
        .where(
          (card) =>
              selection.selected.contains(card.id) &&
              card.learningStatus == source,
        )
        .toList();
    final library = ref.read(cardLibraryProvider);
    selection.setBusy(true);
    var moved = 0;
    final failed = <int>{};
    for (final card in cards) {
      if (!mounted) return;
      // Never continue a batch into a replacement account/domain session.
      if (!identical(library, ref.read(cardLibraryProvider))) break;
      try {
        await library.setLearningStatus(card, destination);
        moved++;
        selection.selected.remove(card.id);
      } catch (_) {
        failed.add(card.id);
      }
    }
    if (!mounted) return;
    selection.setBusy(false);
    ref.read(cardsInvalidationProvider)();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          selection.selecting ? 96 + MediaQuery.paddingOf(context).bottom : 16,
        ),
        content: Text(
          failed.isEmpty
              ? '$moved ${moved == 1 ? 'card' : 'cards'} sent to ${destination.label}.'
              : '$moved moved; ${failed.length} could not be moved. Retry the remaining selection.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    tabs?.removeListener(_tabChanged);
    selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SelectionProvider(
    selection: selection,
    child: AnimatedBuilder(
      animation: selection,
      builder: (context, _) => Column(
        children: [
          Expanded(
            child: AbsorbPointer(
              absorbing: selection.busy,
              child: widget.child,
            ),
          ),
          if (selection.selecting && selection.tab != 0)
            Material(
              elevation: 6,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      if (widget.practiceActionBuilder != null) ...[
                        TextButton(
                          key: const ValueKey('cancel-practice-selection'),
                          onPressed: selection.toggleMode,
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Text('${selection.selected.length} selected'),
                      ),
                      if (widget.practiceActionBuilder != null)
                        widget.practiceActionBuilder!(
                          widget.cards
                              .where(
                                (card) => selection.selected.contains(card.id),
                              )
                              .toList(),
                        )
                      else
                        FilledButton.icon(
                          key: const ValueKey('bulk-move'),
                          onPressed:
                              selection.busy || selection.selected.isEmpty
                              ? null
                              : _move,
                          icon: selection.busy
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.arrow_forward),
                          label: Text('Send to ${selection.destination.label}'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class BulkSelectButton extends StatelessWidget {
  const BulkSelectButton({super.key});
  @override
  Widget build(BuildContext context) {
    final selection = bulkCardSelectionOf(context);
    if (selection == null || selection.tab == 0) return const SizedBox.shrink();
    return TextButton.icon(
      key: const ValueKey('bulk-select'),
      onPressed: selection.busy ? null : selection.toggleMode,
      icon: Icon(
        selection.selecting ? Icons.close : Icons.checklist_rounded,
        size: 18,
      ),
      label: Text(selection.selecting ? 'Cancel' : 'Select'),
    );
  }
}

class SelectableCard extends StatelessWidget {
  const SelectableCard({super.key, required this.card, required this.child});
  final StudyCard card;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final selection = bulkCardSelectionOf(context);
    if (selection == null ||
        !selection.selecting ||
        card.learningStatus != selection.source) {
      return child;
    }
    return Row(
      children: [
        Checkbox(
          key: ValueKey('select-card-${card.id}'),
          value: selection.selected.contains(card.id),
          onChanged: selection.busy ? null : (_) => selection.toggle(card.id),
        ),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: selection.busy ? null : () => selection.toggle(card.id),
            child: IgnorePointer(child: child),
          ),
        ),
      ],
    );
  }
}
