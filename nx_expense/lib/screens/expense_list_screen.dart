import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nx_db/nx_db.dart';

import '../app_theme.dart';
import '../expense_schema.dart';
import '../format.dart';
import '../providers/expense_providers.dart';
import '../reference_layout.dart';
import '../widgets/expense_card.dart';
import '../widgets/tag_chip.dart';

/// Reference Screen 2 summary line when live data is unavailable.
const String kReferenceSummaryLine = '12 expenses · \$1,240.00 total';

class ExpenseListScreen extends ConsumerWidget {
  const ExpenseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schemaAsync = ref.watch(expenseSchemaProvider);
    final listAsync = ref.watch(expenseListForUiProvider);
    final summaryAsync = ref.watch(expenseSummaryProvider);
    final filter = ref.watch(expenseListFilterProvider);

    Future<void> refresh() async {
      ref.invalidate(expenseSchemaProvider);
      ref.invalidate(expenseListForUiProvider);
      ref.invalidate(expenseSummaryProvider);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: schemaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: SelectableText('Schema: $e')),
        data: (schema) {
          final chips = filterChipDescriptors(schema);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(RefLayout.px5, RefLayout.pt12, RefLayout.px5, RefLayout.pb4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text('Expenses', style: refAppBarTitleLarge()),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                            icon: const Icon(Icons.settings_outlined, color: AppColors.slate400, size: 22),
                            onPressed: () => context.push('/tag-systems'),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                            icon: const Icon(Icons.logout, color: AppColors.slate400, size: 22),
                            onPressed: () async {
                              await ref.read(authProvider.notifier).logout();
                              if (context.mounted) context.go('/login');
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(RefLayout.px5, 0, RefLayout.px5, RefLayout.pb3),
                child: summaryAsync.when(
                  data: (s) => Text(
                    s.sumTotal != null
                        ? '${s.count} expenses · ${formatMoney(s.sumTotal)} total'
                        : '${s.count} expenses',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.slate500,
                    ),
                  ),
                  loading: () => Text(
                    kReferenceSummaryLine,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.slate500,
                    ),
                  ),
                  error: (_, __) => Text(
                    kReferenceSummaryLine,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.slate500,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(RefLayout.px5, 0, RefLayout.px5, RefLayout.pb4),
                child: SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterPill(
                        label: 'All',
                        selected: filter == null,
                        onTap: () {
                          ref.read(expenseListFilterProvider.notifier).setFilter(null);
                          ref.invalidate(expenseListForUiProvider);
                        },
                      ),
                      const SizedBox(width: RefLayout.gap2),
                      for (final d in chips) ...[
                        _FilterPill(
                          label: d.label,
                          selected: _chipSelected(filter, d),
                          onTap: () {
                            if (d.nodeName == null) {
                              context.push('/tag-browser/${Uri.encodeComponent(d.systemName)}');
                            } else {
                              ref.read(expenseListFilterProvider.notifier).setFilter(ExpenseFilter(
                                tagFilters: [
                                  {
                                    'system': d.systemName,
                                    'node': d.nodeName,
                                    'include_descendants': true,
                                  },
                                ],
                              ));
                              ref.invalidate(expenseListForUiProvider);
                            }
                          },
                        ),
                        const SizedBox(width: RefLayout.gap2),
                      ],
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ColoredBox(
                  color: AppColors.slate50.withValues(alpha: 0.5),
                  child: RefreshIndicator(
                    onRefresh: refresh,
                    color: AppColors.teal600,
                    child: listAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => ListView(
                        padding: const EdgeInsets.fromLTRB(RefLayout.px5, 8, RefLayout.px5, RefLayout.pb24),
                        children: [
                          Text(
                            'Could not load expenses. Reference placeholders:',
                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate500),
                          ),
                          const SizedBox(height: 12),
                          ..._referencePlaceholderCards(),
                        ],
                      ),
                      data: (models) {
                        if (models.isEmpty) {
                          return ListView(
                            padding: const EdgeInsets.fromLTRB(RefLayout.px5, 8, RefLayout.px5, RefLayout.pb24),
                            children: _referencePlaceholderCards(),
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(RefLayout.px5, 8, RefLayout.px5, RefLayout.pb24),
                          itemCount: models.length,
                          itemBuilder: (context, i) {
                            final m = models[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: ExpenseCard(
                                model: m,
                                schema: schema,
                                onTap: () => context.push('/expense/${m.id}'),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _chipSelected(ExpenseFilter? f, FilterChipDescriptor d) {
    if (f?.tagFilters == null || f!.tagFilters!.isEmpty) return false;
    final tf = f.tagFilters!.first;
    return tf['system'] == d.systemName && tf['node'] == d.nodeName;
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.slate900 : Colors.white,
      borderRadius: BorderRadius.circular(999),
      elevation: selected ? 1 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? AppColors.slate900 : AppColors.slate200),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.slate600,
            ),
          ),
        ),
      ),
    );
  }
}

List<Widget> _referencePlaceholderCards() {
  return [
    _ReferenceDemoCard(
      title: 'Starbucks Coffee',
      amount: r'$4.50',
      date: 'Mar 15, 2026',
      tags: const ['Category: Food', 'Priority: Low'],
      vendor: 'Starbucks Corp',
      vendorLabel: 'Vendor',
    ),
    _ReferenceDemoCard(
      title: 'Uber Ride',
      amount: r'$24.00',
      date: 'Mar 14, 2026',
      tags: const ['Category: Transport'],
      vendor: 'Uber Technologies',
      vendorLabel: 'Vendor',
    ),
    _ReferenceDemoCard(
      title: 'Monthly Groceries',
      amount: r'$185.50',
      date: 'Mar 10, 2026',
      tags: const ['Category: Food', 'Priority: High'],
      vendor: 'Whole Foods',
      vendorLabel: 'Vendor',
    ),
  ];
}

class _ReferenceDemoCard extends StatelessWidget {
  const _ReferenceDemoCard({
    required this.title,
    required this.amount,
    required this.date,
    required this.tags,
    required this.vendor,
    required this.vendorLabel,
  });

  final String title;
  final String amount;
  final String date;
  final List<String> tags;
  final String vendor;
  final String vendorLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
        border: Border.all(color: AppColors.slate100),
        boxShadow: refCardShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate900,
                  ),
                ),
              ),
              Text(
                amount,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.teal600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(date, style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate400)),
          const SizedBox(height: 12),
          Wrap(
            spacing: RefLayout.gap15,
            runSpacing: RefLayout.gap15,
            children: [for (final t in tags) ExpenseTagChip(label: t)],
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.slate500,
              ),
              children: [
                TextSpan(text: '$vendorLabel: ', style: GoogleFonts.inter(color: AppColors.slate400)),
                TextSpan(text: vendor),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
