import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/study/hydrate_study_queue.dart';
import 'package:nx_cards/study/language/language_study_page.dart';
import 'package:nx_cards/browser/card_list/bulk_card_selection.dart';
import 'package:nx_cards/scheduling/study_scope.dart';
import 'package:flutter/material.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/study/session/study_session_page.dart';
import 'package:nx_cards/study/study_setup_page.dart';

Future<void> openStudy(
  BuildContext context,
  String title,
  List<StudyPrompt> prompts, {
  StudyScope? studyScope,
}) {
  return Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => StudySessionPage(
        title: title,
        prompts: prompts,
        studyScope: studyScope,
      ),
    ),
  );
}

typedef StudyButtonBuilder = Widget Function(VoidCallback? onPressed);

class StudyLauncher extends StatelessWidget {
  const StudyLauncher({
    this.studyScope,
    this.followLearningTab = false,
    this.followPracticeSelection = false,
    this.flow = StudySetupFlow.recall,
    super.key,
    required this.title,
    required this.prompts,
    required this.studyCards,
    required this.preferenceKey,
    required this.builder,
    this.languagePair,
    this.sourceKind = StudySourceKind.language,
  });

  final bool followLearningTab;
  final bool followPracticeSelection;
  final StudySetupFlow flow;
  final StudyScope? studyScope;
  final String title;
  final List<StudyPrompt> prompts;
  final List<StudyCard> studyCards;
  final String preferenceKey;
  final StudyButtonBuilder builder;
  final LanguagePair? languagePair;
  final StudySourceKind sourceKind;

  @override
  Widget build(BuildContext context) {
    final selection = followPracticeSelection
        ? bulkCardSelectionOf(context)
        : null;
    if (selection?.practiceOnly == true && selection!.selecting) {
      final selected = studyCards
          .where((card) => selection.selected.contains(card.id))
          .toList();
      return StudyLauncher(
        flow: StudySetupFlow.practice,
        title: title,
        prompts: [for (final card in selected) ...card.prompts],
        studyCards: selected,
        preferenceKey: 'selected-practice:$title',
        languagePair: languagePair,
        sourceKind: languagePair == null ? StudySourceKind.book : sourceKind,
        builder: (onPressed) => LibraryActionButton(
          key: const ValueKey('top-practice'),
          filled: true,
          label: 'Practice',
          icon: Icons.draw_outlined,
          onPressed: onPressed,
        ),
      );
    }
    if (!followLearningTab) return _build(context, flow);
    final tabs = DefaultTabController.of(context);
    return AnimatedBuilder(
      animation: tabs,
      builder: (context, _) {
        if (tabs.index == 2) return const BulkSelectButton();
        final action = _build(
          context,
          tabs.index == 1 ? StudySetupFlow.practice : StudySetupFlow.recall,
        );
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tabs.index == 1) ...[
              const BulkSelectButton(),
              const SizedBox(width: 8),
            ],
            action,
          ],
        );
      },
    );
  }

  Widget _build(BuildContext context, StudySetupFlow flow) {
    Widget button(VoidCallback? onPressed) => followLearningTab
        ? FilledButton(
            onPressed: onPressed,
            child: Text(
              flow == StudySetupFlow.practice ? 'Practice' : 'Recall',
            ),
          )
        : builder(onPressed);
    if (flow == StudySetupFlow.practice) {
      return Consumer(
        builder: (context, ref, _) => button(
          studyCards.isEmpty
              ? null
              : () async {
                  try {
                    final cards = await hydrateStudyQueue(
                      {
                        for (final card in studyCards) card.id: card,
                      }.values.toList(),
                      (card) => hydrateStudyCard(ref, card),
                    );
                    if (!context.mounted) return;
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) =>
                            LanguageStudyPage(title: title, cards: cards),
                      ),
                    );
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Could not open practice. Please try again.',
                          ),
                        ),
                      );
                    }
                  }
                },
        ),
      );
    }
    final hasLanguageCards = studyCards.any((card) => card.isLanguageCard);
    if (prompts.isEmpty && studyCards.isEmpty) return button(null);
    if (sourceKind == StudySourceKind.language &&
        (languagePair == null || !hasLanguageCards)) {
      if (prompts.isEmpty) return button(null);
      return button(
        () => openStudy(context, title, prompts, studyScope: studyScope),
      );
    }
    return button(
      () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => StudySetupPage(
            studyScope: studyScope,
            flow: flow,
            title: title,
            prompts: prompts,
            studyCards: studyCards,
            fromLanguage: languagePair?.from ?? 'Question',
            toLanguage: languagePair?.to ?? 'Answer',
            sourceKind: sourceKind,
            preferenceKey: sourceKind == StudySourceKind.book
                ? preferenceKey
                : '$preferenceKey:${languagePair!.from}:${languagePair!.to}',
          ),
        ),
      ),
    );
  }
}

LanguagePair? languagesForCards(
  CardsDashboard dashboard,
  Iterable<StudyCard> cards,
) {
  final pairs = cards
      .where((card) => card.isLanguageCard)
      .map(dashboard.languageFor)
      .whereType<String>()
      .map((language) => LanguagePair('Front', language))
      .toSet();
  return pairs.length == 1 ? pairs.single : null;
}

class LanguagePair {
  const LanguagePair(this.from, this.to);
  final String from;
  final String to;

  @override
  bool operator ==(Object other) =>
      other is LanguagePair && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

/// Keep the collection actions compact on tablets and aligned on phones.
class LibraryActions extends StatelessWidget {
  const LibraryActions({
    super.key,
    this.search,
    required this.practice,
    required this.add,
    required this.recall,
  });
  final Widget? search;
  final Widget practice, add, recall;
  @override
  Widget build(BuildContext context) {
    final selection = bulkCardSelectionOf(context);
    final selecting = selection?.practiceOnly == true && selection!.selecting;
    final actions = <Widget>[
      ?search,
      if (selecting) ...[
        recall,
        LibraryActionButton(
          key: const ValueKey('top-cancel-practice'),
          label: 'Cancel',
          icon: Icons.close,
          onPressed: selection.toggleMode,
        ),
      ] else ...[
        practice,
        add,
        recall,
      ],
    ];
    return LayoutBuilder(
      builder: (context, constraints) => _LibraryActionLayout(
        compact: constraints.maxWidth < (selecting ? 320 : 440),
        naturalSpacing: !selecting && constraints.maxWidth >= 440,
        child: Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Row(
              mainAxisSize: selecting || constraints.maxWidth < 440
                  ? MainAxisSize.max
                  : MainAxisSize.min,
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0)
                    SizedBox(
                      width: constraints.maxWidth >= 440 && !selecting ? 24 : 8,
                    ),
                  if (selecting || constraints.maxWidth < 440)
                    Expanded(child: actions[i])
                  else
                    actions[i],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryActionLayout extends InheritedWidget {
  const _LibraryActionLayout({
    required this.compact,
    required this.naturalSpacing,
    required super.child,
  });
  final bool compact;
  final bool naturalSpacing;
  @override
  bool updateShouldNotify(_LibraryActionLayout oldWidget) =>
      compact != oldWidget.compact ||
      naturalSpacing != oldWidget.naturalSpacing;
}

class LibraryActionButton extends StatelessWidget {
  const LibraryActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
    this.tooltip,
  });
  final String label;
  final String? tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool filled;
  @override
  Widget build(BuildContext context) {
    final layout = context
        .dependOnInheritedWidgetOfExactType<_LibraryActionLayout>();
    final compact = layout?.compact ?? false;
    final style = TextButton.styleFrom(
      minimumSize: const Size(48, 48),
      padding: EdgeInsets.symmetric(
        horizontal: !filled && layout?.naturalSpacing == true ? 0 : 12,
      ),
      textStyle: const TextStyle(fontSize: 14),
    );
    return Tooltip(
      message: tooltip ?? label,
      child: compact
          ? SizedBox.square(
              dimension: 48,
              child: (filled
                  ? IconButton.filled(
                      onPressed: onPressed,
                      icon: Icon(icon, size: 20),
                    )
                  : IconButton(
                      onPressed: onPressed,
                      icon: Icon(icon, size: 20),
                    )),
            )
          : (filled
                ? FilledButton.icon(
                    style: style,
                    onPressed: onPressed,
                    icon: Icon(icon, size: 18),
                    label: Text(label),
                  )
                : TextButton.icon(
                    style: style,
                    onPressed: onPressed,
                    icon: Icon(icon, size: 18),
                    label: Text(label),
                  )),
    );
  }
}
