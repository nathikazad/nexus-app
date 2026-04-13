import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../app_theme.dart';
import '../../data/teller_timeline_api.dart';
import '../../layout.dart';
import '../../providers/teller_providers.dart';
import '../../util/expense_schema.dart';
import '../../util/format.dart';
import '../../widgets/expense_app_end_drawer.dart';
import '../../widgets/expense_date_range_bar.dart';

class TellerListScreen extends ConsumerWidget {
  const TellerListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(tellerTransactionsInRangeProvider);
    final summaryAsync = ref.watch(tellerListSummaryProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      endDrawer: const ExpenseAppEndDrawer(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                RefLayout.px5,
                RefLayout.appBarTop,
                RefLayout.px5,
                RefLayout.pb4,
              ),
              child: Row(
                children: [
                  if (context.canPop())
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      icon: const Icon(Icons.arrow_back, color: AppColors.slate400, size: 22),
                      onPressed: () => context.pop(),
                    ),
                  Expanded(child: Text('Teller', style: refAppBarTitleLarge())),
                  const ExpenseDateRangeCalendarButton(),
                  const SizedBox(width: 4),
                  const ExpenseAppMenuButton(),
                ],
              ),
            ),
          ),
          const ExpenseDateRangeBar(bottomPadding: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(RefLayout.px5, 0, RefLayout.px5, 4),
            child: summaryAsync.when(
              data: (s) => Text(
                s.sumTotal != null ? '${s.count} · ${formatMoney(s.sumTotal)}' : '${s.count}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.slate500,
                ),
              ),
              loading: () => Text(
                '...',
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.slate500),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
          Expanded(
            child: ColoredBox(
              color: AppColors.slate50.withValues(alpha: 0.5),
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(tellerTransactionsProvider);
                  await ref.read(tellerTransactionsProvider.future);
                },
                color: AppColors.teal600,
                child: listAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Error: $e',
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate500),
                      ),
                    ),
                  ),
                  data: (rows) {
                    if (rows.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.account_balance_outlined, size: 48, color: AppColors.slate300),
                            const SizedBox(height: 12),
                            Text(
                              'No Teller transactions in this range',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.slate400,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    final items = _buildDateGroupedItems(rows);
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        RefLayout.px5,
                        8,
                        RefLayout.px5,
                        RefLayout.pb24,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, i) => items[i],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDateGroupedItems(List<TellerTransactionRow> rows) {
    final items = <Widget>[];
    String? lastDate;
    for (final r in rows) {
      final dateStr = _dateLabel(r.time);
      if (dateStr != lastDate) {
        items.add(
          Padding(
            padding: EdgeInsets.only(top: lastDate == null ? 4 : 12, bottom: 4),
            child: Text(
              dateStr,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: AppColors.slate400,
              ),
            ),
          ),
        );
        lastDate = dateStr;
      }
      items.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _TellerCard(
            row: r,
            onTap: (ctx) => _showTellerDetail(ctx, r),
          ),
        ),
      );
    }
    return items;
  }

  static String _dateLabel(DateTime t) {
    final d = t.toLocal();
    return DateFormat('MMM d, y').format(d);
  }

  void _showTellerDetail(BuildContext context, TellerTransactionRow row) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(RefLayout.rounded3xl)),
      ),
      builder: (ctx) => _TellerDetailSheet(row: row),
    );
  }
}

class _TellerCard extends StatelessWidget {
  const _TellerCard({required this.row, required this.onTap});

  final TellerTransactionRow row;
  final void Function(BuildContext context) onTap;

  @override
  Widget build(BuildContext context) {
    final title = _cardTitle(row.payload);
    final amt = _parseAmount(row.payload['amount']);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTap(context),
        borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
            border: Border.all(color: AppColors.slate100),
            boxShadow: refCardShadow,
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
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
              if (amt != null)
                Text(
                  formatMoney(amt),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.teal600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _cardTitle(Map<String, dynamic> payload) {
    final cp = _counterpartyName(payload);
    if (cp != null && cp.isNotEmpty) return cp;
    final desc = (payload['description'] as String?)?.trim() ?? '';
    final first = desc.split('\n').first;
    final cleaned = first.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isNotEmpty) return cleaned.length > 120 ? '${cleaned.substring(0, 120)}…' : cleaned;
    return 'Transaction';
  }

  static String? _counterpartyName(Map<String, dynamic> payload) {
    final details = payload['details'];
    if (details is! Map) return null;
    final cp = details['counterparty'];
    if (cp is! Map) return null;
    final name = cp['name'];
    if (name == null) return null;
    final s = name.toString().trim();
    return s.isEmpty ? null : s;
  }

  static num? _parseAmount(dynamic raw) {
    if (raw == null) return null;
    return num.tryParse(raw.toString().trim());
  }
}

class _TellerDetailSheet extends StatelessWidget {
  const _TellerDetailSheet({required this.row});

  final TellerTransactionRow row;

  @override
  Widget build(BuildContext context) {
    final p = row.payload;
    final details = p['details'];
    Map<String, dynamic>? dmap;
    if (details is Map<String, dynamic>) {
      dmap = details;
    } else if (details is Map) {
      dmap = Map<String, dynamic>.from(details);
    }
    final processing = dmap?['processing_status']?.toString();
    final cpName = _counterpartyNameFromPayload(p);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return DraggableScrollableSheet(
      maxChildSize: 0.92,
      minChildSize: 0.45,
      initialChildSize: 0.65,
      expand: false,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(RefLayout.px5, 12, RefLayout.px5, 24 + bottomInset),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.slate200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Teller transaction',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.slate900,
              ),
            ),
            const SizedBox(height: 16),
            _DetailRow(label: 'Date', value: _payloadDate(p) ?? row.time.toLocal().toIso8601String().split('T').first),
            _DetailRow(label: 'Description', value: (p['description'] as String?)?.trim() ?? '—'),
            _DetailRow(label: 'Type', value: p['type']?.toString() ?? '—'),
            _DetailRow(label: 'Status', value: p['status']?.toString() ?? '—'),
            _DetailRow(label: 'Id', value: p['id']?.toString() ?? '—'),
            _DetailRow(label: 'processing_status', value: processing ?? '—'),
            _DetailRow(label: 'counterparty.name', value: cpName ?? '—'),
            if (row.linkedModels.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Linked',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate900,
                ),
              ),
              const SizedBox(height: 8),
              ...row.linkedModels.map((m) => _LinkedModelTile(model: m)),
            ],
          ],
        );
      },
    );
  }

  static String? _counterpartyNameFromPayload(Map<String, dynamic> payload) {
    final details = payload['details'];
    if (details is! Map) return null;
    final cp = details['counterparty'];
    if (cp is! Map) return null;
    final name = cp['name'];
    if (name == null) return null;
    final s = name.toString().trim();
    return s.isEmpty ? null : s;
  }

  static String? _payloadDate(Map<String, dynamic> p) {
    final raw = p['date'];
    if (raw == null) return null;
    return raw.toString();
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: AppColors.slate400,
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.slate900,
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkedModelTile extends StatelessWidget {
  const _LinkedModelTile({required this.model});

  final LinkedTellerModel model;

  @override
  Widget build(BuildContext context) {
    final isExpense = model.modelTypeName == kExpenseModelTypeName;
    final subtitle = '${model.modelTypeName} · #${model.id}';

    final child = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
        border: Border.all(color: AppColors.slate100),
        boxShadow: refCardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isExpense ? Icons.receipt_long_outlined : Icons.swap_horiz_rounded,
            color: AppColors.slate500,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model.name,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate500),
                ),
              ],
            ),
          ),
          if (isExpense)
            Icon(Icons.chevron_right, color: AppColors.slate400, size: 22),
        ],
      ),
    );

    if (!isExpense) {
      return child;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          context.push('/expense/${model.id}');
        },
        borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
        child: child,
      ),
    );
  }
}
