import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nx_expense/core/formatting/format.dart';
import 'package:nx_expense/core/theme/app_theme.dart';
import 'package:nx_expense/domain/teller/teller_expense_review.dart';

Future<List<Map<String, dynamic>>?> showTellerExpenseReviewSheet({
  required BuildContext context,
  required TellerExpenseReview review,
}) {
  return showModalBottomSheet<List<Map<String, dynamic>>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    showDragHandle: true,
    builder: (_) => _TellerExpenseReviewSheet(review: review),
  );
}

class _TellerExpenseReviewSheet extends StatefulWidget {
  const _TellerExpenseReviewSheet({required this.review});

  final TellerExpenseReview review;

  @override
  State<_TellerExpenseReviewSheet> createState() =>
      _TellerExpenseReviewSheetState();
}

class _TellerExpenseReviewSheetState extends State<_TellerExpenseReviewSheet> {
  late final Map<String, _ReviewChoice> _choices;

  @override
  void initState() {
    super.initState();
    _choices = {
      for (final item in widget.review.items)
        item.reviewId: _initialChoice(item),
    };
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 16 + bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Review expenses',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.slate900,
                    ),
                  ),
                ),
                Text(
                  '${widget.review.items.length}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: widget.review.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = widget.review.items[index];
                  return _ReviewItemCard(
                    item: item,
                    choice: _choices[item.reviewId] ?? _initialChoice(item),
                    onChanged: (choice) =>
                        setState(() => _choices[item.reviewId] = choice),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_decisions()),
                    child: const Text('Apply choices'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _decisions() {
    return [
      for (final item in widget.review.items)
        (_choices[item.reviewId] ?? _initialChoice(item)).toDecision(item),
    ];
  }
}

class _ReviewItemCard extends StatelessWidget {
  const _ReviewItemCard({
    required this.item,
    required this.choice,
    required this.onChanged,
  });

  final TellerExpenseReviewItem item;
  final _ReviewChoice choice;
  final ValueChanged<_ReviewChoice> onChanged;

  @override
  Widget build(BuildContext context) {
    final tx = item.transaction;
    final suggestion = item.suggestedExpense;
    final title = (tx.counterpartyName ?? suggestion.name).trim().isEmpty
        ? 'Teller transaction'
        : (tx.counterpartyName ?? suggestion.name).trim();
    final subtitle = [
      if ((tx.date ?? '').isNotEmpty) formatModelDate(tx.date),
      if ((tx.type ?? '').isNotEmpty) tx.type,
    ].join(' - ');
    final tagLine = suggestion.tags.map((tag) => tag.label).join(', ');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slate900,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.slate500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  formatMoney(tx.amount ?? suggestion.cost),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.teal700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _SuggestedExpenseSummary(suggestion: suggestion, tagLine: tagLine),
            if (item.candidateExistingExpenses.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Existing unlinked expenses',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate500,
                ),
              ),
              const SizedBox(height: 6),
              for (final candidate in item.candidateExistingExpenses)
                _CandidateExpenseTile(
                  candidate: candidate,
                  selected:
                      choice.action == _ReviewAction.linkExisting &&
                      choice.existingExpenseId == candidate.modelId,
                  onTap: () =>
                      onChanged(_ReviewChoice.linkExisting(candidate.modelId)),
                ),
            ],
            const SizedBox(height: 10),
            DropdownButtonFormField<_ReviewChoice>(
              initialValue: choice,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Action',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              items: _choiceOptions(item)
                  .map(
                    (option) => DropdownMenuItem<_ReviewChoice>(
                      value: option,
                      child: Text(_choiceLabel(item, option)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) onChanged(value);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestedExpenseSummary extends StatelessWidget {
  const _SuggestedExpenseSummary({
    required this.suggestion,
    required this.tagLine,
  });

  final TellerSuggestedExpense suggestion;
  final String tagLine;

  @override
  Widget build(BuildContext context) {
    final company = suggestion.companyName?.trim();
    final parts = [
      if (company != null && company.isNotEmpty) company,
      if (tagLine.isNotEmpty) tagLine,
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join(' - '),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate600),
    );
  }
}

class _CandidateExpenseTile extends StatelessWidget {
  const _CandidateExpenseTile({
    required this.candidate,
    required this.selected,
    required this.onTap,
  });

  final TellerExistingExpenseCandidate candidate;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final detail = [
      if (candidate.date != null) formatModelDate(candidate.date),
      if (candidate.cost != null) formatMoney(candidate.cost),
    ].join(' - ');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 18,
              color: selected ? AppColors.teal600 : AppColors.slate400,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                detail.isEmpty ? candidate.name : '${candidate.name} - $detail',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: AppColors.slate700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ReviewAction { createExpense, linkExisting, skip }

class _ReviewChoice {
  const _ReviewChoice._(this.action, this.existingExpenseId);

  const _ReviewChoice.createExpense()
    : this._(_ReviewAction.createExpense, null);

  const _ReviewChoice.skip() : this._(_ReviewAction.skip, null);

  const _ReviewChoice.linkExisting(int expenseId)
    : this._(_ReviewAction.linkExisting, expenseId);

  final _ReviewAction action;
  final int? existingExpenseId;

  Map<String, dynamic> toDecision(TellerExpenseReviewItem item) {
    switch (action) {
      case _ReviewAction.createExpense:
        return item.createExpenseDecision();
      case _ReviewAction.linkExisting:
        final id = existingExpenseId;
        if (id == null) return item.skipDecision();
        return item.linkExistingDecision(id);
      case _ReviewAction.skip:
        return item.skipDecision();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is _ReviewChoice &&
      other.action == action &&
      other.existingExpenseId == existingExpenseId;

  @override
  int get hashCode => Object.hash(action, existingExpenseId);
}

_ReviewChoice _initialChoice(TellerExpenseReviewItem item) {
  if (item.recommendedAction == 'link_existing_expense' &&
      item.candidateExistingExpenses.length == 1) {
    return _ReviewChoice.linkExisting(
      item.candidateExistingExpenses.single.modelId,
    );
  }
  if (item.recommendedAction == 'create_expense' ||
      item.candidateExistingExpenses.isEmpty) {
    return const _ReviewChoice.createExpense();
  }
  return const _ReviewChoice.skip();
}

List<_ReviewChoice> _choiceOptions(TellerExpenseReviewItem item) {
  return [
    const _ReviewChoice.createExpense(),
    for (final candidate in item.candidateExistingExpenses)
      _ReviewChoice.linkExisting(candidate.modelId),
    const _ReviewChoice.skip(),
  ];
}

String _choiceLabel(TellerExpenseReviewItem item, _ReviewChoice choice) {
  switch (choice.action) {
    case _ReviewAction.createExpense:
      return 'Create new expense';
    case _ReviewAction.skip:
      return 'Skip';
    case _ReviewAction.linkExisting:
      final candidate = item.candidateExistingExpenses
          .where((c) => c.modelId == choice.existingExpenseId)
          .firstOrNull;
      if (candidate == null) return 'Link existing expense';
      return 'Link ${candidate.name} (${formatMoney(candidate.cost)})';
  }
}
