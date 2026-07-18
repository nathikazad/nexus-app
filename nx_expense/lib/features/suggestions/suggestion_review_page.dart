import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:nx_db/auth.dart';

import 'package:nx_expense/core/formatting/format.dart';
import 'package:nx_expense/core/layout/layout.dart';
import 'package:nx_expense/core/theme/app_theme.dart';
import 'package:nx_expense/data/providers.dart';
import 'package:nx_expense/data/suggestion/suggestion_api.dart';
import 'package:nx_expense/domain/suggestion/expense_suggestion.dart';
import 'package:nx_expense/features/shell/expense_app_end_drawer.dart';

import 'suggestion_state.dart';

class ExternalModeControl extends ConsumerWidget {
  const ExternalModeControl({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(externalWorkspaceModeProvider);
    final count = ref
        .watch(openExpenseSuggestionsProvider)
        .maybeWhen(data: (items) => items.length, orElse: () => null);
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<ExternalWorkspaceMode>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
            value: ExternalWorkspaceMode.review,
            icon: const Icon(Icons.fact_check_outlined, size: 17),
            label: Text(count == null ? 'Review' : 'Review $count'),
          ),
          const ButtonSegment(
            value: ExternalWorkspaceMode.transactions,
            icon: Icon(Icons.receipt_long_outlined, size: 17),
            label: Text('Transactions'),
          ),
        ],
        selected: {mode},
        onSelectionChanged: (selection) {
          ref.read(externalWorkspaceModeProvider.notifier).state =
              selection.first;
        },
        style: ButtonStyle(
          visualDensity: compact
              ? VisualDensity.compact
              : VisualDensity.standard,
          textStyle: WidgetStatePropertyAll(
            GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: AppColors.slate200),
          ),
        ),
      ),
    );
  }
}

class SuggestionReviewScreen extends ConsumerWidget {
  const SuggestionReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedExpenseSuggestionIdProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      endDrawer: const ExpenseAppEndDrawer(),
      body: selectedId == null
          ? SuggestionInboxPane(
              onSelected: (suggestion) {
                ref.read(selectedExpenseSuggestionIdProvider.notifier).state =
                    suggestion.id;
              },
            )
          : SuggestionDetailPane(
              mobile: true,
              onBack: () {
                ref.read(selectedExpenseSuggestionIdProvider.notifier).state =
                    null;
              },
            ),
    );
  }
}

class SuggestionInboxPane extends ConsumerWidget {
  const SuggestionInboxPane({super.key, this.onSelected, this.desktop = false});

  final ValueChanged<ExpenseSuggestion>? onSelected;
  final bool desktop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestions = ref.watch(openExpenseSuggestionsProvider);
    final selectedId = ref.watch(selectedExpenseSuggestionIdProvider);
    return ColoredBox(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                RefLayout.px5,
                RefLayout.appBarTop,
                RefLayout.px5,
                12,
              ),
              child: Row(
                children: [
                  Expanded(child: Text('Ext', style: refAppBarTitleLarge())),
                  IconButton(
                    tooltip: 'Refresh suggestions',
                    onPressed: () =>
                        ref.invalidate(openExpenseSuggestionsProvider),
                    icon: const Icon(
                      Icons.refresh,
                      size: 21,
                      color: AppColors.slate500,
                    ),
                  ),
                  if (!desktop) const ExpenseAppMenuButton(),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(RefLayout.px5, 0, RefLayout.px5, 16),
            child: ExternalModeControl(compact: true),
          ),
          Expanded(
            child: ColoredBox(
              color: AppColors.slate50,
              child: suggestions.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _SuggestionError(
                  message: '$error',
                  onRetry: () => ref.invalidate(openExpenseSuggestionsProvider),
                ),
                data: (items) {
                  if (items.isEmpty) return const _SuggestionEmpty();
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(openExpenseSuggestionsProvider);
                      await ref.read(openExpenseSuggestionsProvider.future);
                    },
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
                      itemCount: items.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                            child: Row(
                              children: [
                                Text(
                                  '${items.length} ready for review',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.slate600,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'Newest first',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.slate400,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        final item = items[index - 1];
                        final selected =
                            selectedId == item.id ||
                            (desktop && selectedId == null && index == 1);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _SuggestionListTile(
                            suggestion: item,
                            selected: selected,
                            onTap: () {
                              ref
                                      .read(
                                        selectedExpenseSuggestionIdProvider
                                            .notifier,
                                      )
                                      .state =
                                  item.id;
                              onSelected?.call(item);
                            },
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SuggestionDetailPane extends ConsumerStatefulWidget {
  const SuggestionDetailPane({super.key, this.mobile = false, this.onBack});

  final bool mobile;
  final VoidCallback? onBack;

  @override
  ConsumerState<SuggestionDetailPane> createState() =>
      _SuggestionDetailPaneState();
}

class _SuggestionDetailPaneState extends ConsumerState<SuggestionDetailPane> {
  bool _busy = false;

  Future<void> _decide(ExpenseSuggestion suggestion, bool accept) async {
    if (_busy) return;
    final base = ref.read(imageBaseUrlProvider);
    final userId = ref.read(userIdProvider);
    if (base == null || base.isEmpty || userId == null || userId.isEmpty) {
      return;
    }
    setState(() => _busy = true);
    try {
      await decideExpenseSuggestion(
        imageBaseUrl: base,
        userId: userId,
        suggestionId: suggestion.id,
        accept: accept,
      );
      ref.invalidate(openExpenseSuggestionsProvider);
      ref.invalidate(expenseListProvider);
      ref.invalidate(tellerTransactionsProvider);
      ref.read(selectedExpenseSuggestionIdProvider.notifier).state = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accept ? 'Suggestion applied.' : 'Suggestion dismissed.',
            ),
          ),
        );
        if (widget.mobile) widget.onBack?.call();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update suggestion: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revise(ExpenseSuggestion suggestion) async {
    if (_busy) return;
    final note = await showDialog<String>(
      context: context,
      builder: (context) => const _RevisionDialog(),
    );
    if (note == null || !mounted) return;
    final base = ref.read(imageBaseUrlProvider);
    final userId = ref.read(userIdProvider);
    if (base == null || base.isEmpty || userId == null || userId.isEmpty) {
      return;
    }
    setState(() => _busy = true);
    try {
      await reviseExpenseSuggestion(
        imageBaseUrl: base,
        userId: userId,
        suggestionId: suggestion.id,
        note: note,
      );
      ref.invalidate(openExpenseSuggestionsProvider);
      ref.read(selectedExpenseSuggestionIdProvider.notifier).state = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Suggestion returned for revision.')),
        );
        if (widget.mobile) widget.onBack?.call();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not request revision: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(openExpenseSuggestionsProvider);
    final selectedId = ref.watch(selectedExpenseSuggestionIdProvider);
    return itemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _SuggestionError(
        message: '$error',
        onRetry: () => ref.invalidate(openExpenseSuggestionsProvider),
      ),
      data: (items) {
        if (items.isEmpty) return const _SuggestionEmpty(detail: true);
        final suggestion =
            items.where((item) => item.id == selectedId).firstOrNull ??
            items.first;
        return _SuggestionDetail(
          suggestion: suggestion,
          mobile: widget.mobile,
          busy: _busy,
          onBack: widget.onBack,
          onAccept: () => _decide(suggestion, true),
          onReject: () => _decide(suggestion, false),
          onRevise: () => _revise(suggestion),
        );
      },
    );
  }
}

class _SuggestionListTile extends ConsumerWidget {
  const _SuggestionListTile({
    required this.suggestion,
    required this.selected,
    required this.onTap,
  });

  final ExpenseSuggestion suggestion;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amount = suggestion.bank.amount;
    final preview = suggestion.products.firstOrNull;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.teal100.withValues(alpha: 0.55)
                : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppColors.teal500 : AppColors.slate200,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumbnail(imageUrl: preview?.imageUrl, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            suggestion.bank.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.slate900,
                            ),
                          ),
                        ),
                        if (amount != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            formatMoney(amount.abs()),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.slate900,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      suggestion.provider?.description ?? 'No merchant match',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.slate500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _SourceBadge(
                          label: suggestion.bank.source.toUpperCase(),
                        ),
                        if (suggestion.hasProvider) ...[
                          const SizedBox(width: 6),
                          _SourceBadge(
                            label: suggestion.provider!.source.toUpperCase(),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          _shortDate(suggestion.bank.date),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.slate400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionDetail extends StatelessWidget {
  const _SuggestionDetail({
    required this.suggestion,
    required this.mobile,
    required this.busy,
    required this.onAccept,
    required this.onReject,
    required this.onRevise,
    this.onBack,
  });

  final ExpenseSuggestion suggestion;
  final bool mobile;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onRevise;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  if (mobile)
                    IconButton(
                      tooltip: 'Back to suggestions',
                      onPressed: onBack,
                      icon: const Icon(
                        Icons.arrow_back,
                        color: AppColors.slate500,
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Review change', style: refAppBarTitleBase()),
                        Text(
                          'Suggestion #${suggestion.id}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.slate400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _SourceBadge(label: 'OPEN'),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                mobile ? 20 : 32,
                24,
                mobile ? 20 : 32,
                32,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ReviewHeader(suggestion: suggestion),
                      const SizedBox(height: 28),
                      _SectionLabel(
                        icon: Icons.account_balance_outlined,
                        label: 'BANK TRANSACTION',
                      ),
                      const SizedBox(height: 8),
                      _EventRow(event: suggestion.bank, emphasis: true),
                      if (suggestion.provider != null) ...[
                        const _FlowConnector(label: 'matched with'),
                        _SectionLabel(
                          icon: Icons.shopping_bag_outlined,
                          label:
                              '${suggestion.provider!.source.toUpperCase()} TRANSACTION',
                        ),
                        const SizedBox(height: 8),
                        _EventRow(event: suggestion.provider!),
                      ],
                      const _FlowConnector(label: 'will update'),
                      _SectionLabel(
                        icon: Icons.receipt_outlined,
                        label: 'EXPENSE',
                      ),
                      const SizedBox(height: 8),
                      _ExpensePreview(suggestion: suggestion),
                      if (suggestion.changes.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        const _SectionLabel(
                          icon: Icons.compare_arrows,
                          label: 'PROPOSED CHANGES',
                        ),
                        const SizedBox(height: 8),
                        _ChangeList(changes: suggestion.changes),
                      ],
                      if (suggestion.products.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        _SectionLabel(
                          icon: Icons.inventory_2_outlined,
                          label: 'PRODUCTS (${suggestion.products.length})',
                        ),
                        const SizedBox(height: 8),
                        for (final product in suggestion.products) ...[
                          _ProductRow(product: product),
                          if (product != suggestion.products.last)
                            const Divider(height: 1),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          _DecisionBar(
            busy: busy,
            onAccept: onAccept,
            onReject: onReject,
            onRevise: onRevise,
            mobile: mobile,
          ),
        ],
      ),
    );
  }
}

class _ReviewHeader extends StatelessWidget {
  const _ReviewHeader({required this.suggestion});

  final ExpenseSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final amount = suggestion.bank.amount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                suggestion.title,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate900,
                ),
              ),
            ),
            if (amount != null) ...[
              const SizedBox(width: 16),
              Text(
                formatMoney(amount.abs()),
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.teal700,
                ),
              ),
            ],
          ],
        ),
        if (suggestion.reason.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            suggestion.reason,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.45,
              color: AppColors.slate600,
            ),
          ),
        ],
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, this.emphasis = false});

  final SuggestionEvent event;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: emphasis ? AppColors.slate50 : Colors.white,
        border: Border.all(color: AppColors.slate200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.description,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    if (event.date != null) _longDate(event.date),
                    if (event.accountLast4 != null)
                      'Account ••••${event.accountLast4}',
                    if (event.orderIds.isNotEmpty)
                      'Order ${event.orderIds.join(', ')}',
                  ].join('  ·  '),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.slate500,
                  ),
                ),
              ],
            ),
          ),
          if (event.amount != null) ...[
            const SizedBox(width: 12),
            Text(
              formatMoney(event.amount!.abs()),
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.slate900,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExpensePreview extends StatelessWidget {
  const _ExpensePreview({required this.suggestion});

  final ExpenseSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final expense = suggestion.expense;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.teal500),
        borderRadius: BorderRadius.circular(8),
        color: AppColors.teal100.withValues(alpha: 0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  expense.name,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate900,
                  ),
                ),
              ),
              _SourceBadge(
                label: suggestion.createsExpense ? 'CREATE' : 'EXISTING',
              ),
            ],
          ),
          if (expense.companyName != null) ...[
            const SizedBox(height: 8),
            _InlineRelation(
              icon: Icons.business_outlined,
              label: 'Company',
              value: expense.companyName!,
            ),
          ],
          if (suggestion.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in suggestion.tags)
                  Chip(
                    avatar: const Icon(Icons.sell_outlined, size: 14),
                    label: Text(tag.label),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Text(
            suggestion.createsExpense
                ? 'A new Expense and its links will be created.'
                : 'The existing Expense will receive the missing transaction and product links.',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate600),
          ),
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product});

  final SuggestedProduct product;

  @override
  Widget build(BuildContext context) {
    final quantity = product.quantity;
    final details = [
      if (quantity != null)
        '${_compactNumber(quantity)} ${product.unit ?? 'item'}',
      if (product.price != null) '${formatMoney(product.price!)} each',
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Thumbnail(imageUrl: product.imageUrl, size: 72),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _SourceBadge(
                      label: product.createsProduct ? 'NEW PRODUCT' : 'PRODUCT',
                    ),
                  ],
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    details.join('  ·  '),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.slate500,
                    ),
                  ),
                ],
                if (product.maker != null) ...[
                  const SizedBox(height: 9),
                  _InlineRelation(
                    icon: Icons.subdirectory_arrow_right,
                    label: product.maker!.createsCompany
                        ? 'Create maker'
                        : 'Maker',
                    value: product.maker!.name,
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

class _Thumbnail extends ConsumerWidget {
  const _Thumbnail({required this.imageUrl, required this.size});

  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = ref.watch(imageBaseUrlProvider);
    final userId = ref.watch(userIdProvider);
    final path = imageUrl;
    if (base == null || userId == null || path == null || path.isEmpty) {
      return _ThumbnailFallback(size: size);
    }
    final normalizedBase = normalizeSuggestionHttpBase(base);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        resolveSuggestionAssetUrl(base, path),
        headers: suggestionHttpHeaders(normalizedBase, userId),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _ThumbnailFallback(size: size),
      ),
    );
  }
}

class _ThumbnailFallback extends StatelessWidget {
  const _ThumbnailFallback({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Icon(
        Icons.inventory_2_outlined,
        size: size * 0.4,
        color: AppColors.slate400,
      ),
    );
  }
}

class _FlowConnector extends StatelessWidget {
  const _FlowConnector({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            Container(width: 2, height: 48, color: AppColors.slate200),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.slate400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecisionBar extends StatelessWidget {
  const _DecisionBar({
    required this.busy,
    required this.onAccept,
    required this.onReject,
    required this.onRevise,
    required this.mobile,
  });

  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onRevise;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          mobile ? 20 : 32,
          12,
          mobile ? 20 : 32,
          12,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.slate200)),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : onReject,
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  side: const BorderSide(color: AppColors.slate300),
                  foregroundColor: AppColors.slate600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : onRevise,
                icon: const Icon(Icons.edit_note, size: 18),
                label: const Text('Revise'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  side: const BorderSide(color: AppColors.teal500),
                  foregroundColor: AppColors.teal700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: busy ? null : onAccept,
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check, size: 18),
                label: Text(
                  busy ? 'Applying' : (mobile ? 'Accept' : 'Accept & apply'),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChangeList extends StatelessWidget {
  const _ChangeList({required this.changes});

  final List<SuggestionChange> changes;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.slate200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          for (var index = 0; index < changes.length; index++) ...[
            _ChangeRow(change: changes[index]),
            if (index != changes.length - 1)
              const Divider(height: 1, indent: 16, endIndent: 16),
          ],
        ],
      ),
    );
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({required this.change});

  final SuggestionChange change;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              change.field,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.slate500,
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                if (change.before != null)
                  Text(
                    change.before!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.slate500,
                      decoration: change.after == null
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                if (change.before != null && change.after != null)
                  const Icon(
                    Icons.arrow_forward,
                    size: 15,
                    color: AppColors.slate400,
                  ),
                if (change.after != null)
                  Text(
                    change.after!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.teal700,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RevisionDialog extends StatefulWidget {
  const _RevisionDialog();

  @override
  State<_RevisionDialog> createState() => _RevisionDialogState();
}

class _RevisionDialogState extends State<_RevisionDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final note = _controller.text.trim();
    if (note.isEmpty) {
      setState(() => _error = 'Tell the AI what should change.');
      return;
    }
    Navigator.of(context).pop(note);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Revise suggestion'),
      content: SizedBox(
        width: 440,
        child: TextField(
          controller: _controller,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          maxLength: 2000,
          decoration: InputDecoration(
            labelText: 'What should the AI change?',
            alignLabelWithHint: true,
            errorText: _error,
          ),
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.send, size: 17),
          label: const Text('Send for revision'),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.slate400),
        const SizedBox(width: 7),
        Text(label, style: refSectionTitle(context)),
      ],
    );
  }
}

class _InlineRelation extends StatelessWidget {
  const _InlineRelation({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.slate400),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate500),
        ),
        Flexible(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.slate700,
            ),
          ),
        ),
      ],
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: AppColors.slate500,
        ),
      ),
    );
  }
}

class _SuggestionEmpty extends StatelessWidget {
  const _SuggestionEmpty({this.detail = false});

  final bool detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.task_alt, size: 48, color: AppColors.teal600),
            const SizedBox(height: 14),
            Text(
              detail ? 'Nothing selected' : 'You are all caught up',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.slate700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              detail
                  ? 'Choose a suggestion from the review queue.'
                  : 'There are no open expense suggestions.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate400),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionError extends StatelessWidget {
  const _SuggestionError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 38, color: AppColors.red600),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate600),
            ),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

String _shortDate(String? value) {
  final parsed = DateTime.tryParse(value ?? '');
  return parsed == null ? '' : DateFormat('MMM d').format(parsed);
}

String _longDate(String? value) {
  final parsed = DateTime.tryParse(value ?? '');
  return parsed == null ? value ?? '' : DateFormat('MMM d, y').format(parsed);
}

String _compactNumber(num value) =>
    value % 1 == 0 ? value.toInt().toString() : '$value';
