import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:nx_db/auth.dart';

import 'package:nx_expense/core/layout/layout.dart';
import 'package:nx_expense/core/theme/app_theme.dart';
import 'package:nx_expense/data/teller/teller_sync_api.dart';
import 'package:nx_expense/data/teller/teller_timeline_api.dart';
import 'package:nx_expense/core/formatting/format.dart';
import 'package:nx_expense/data/providers.dart';
import 'package:nx_expense/features/desktop/desktop_nav.dart';
import 'package:nx_expense/features/expense/widgets/expense_date_range_bar.dart';
import 'package:nx_expense/features/shell/expense_app_end_drawer.dart';
import 'teller_transaction_detail_page.dart';

enum _TellerSortMode {
  dateAsc,
  dateDesc,
  amountAsc,
  amountDesc;

  bool get isDate => this == dateAsc || this == dateDesc;
}

class TellerListScreen extends ConsumerStatefulWidget {
  const TellerListScreen({super.key});

  @override
  ConsumerState<TellerListScreen> createState() => _TellerListScreenState();
}

class _TellerListScreenState extends ConsumerState<TellerListScreen> {
  bool _syncBusy = false;
  bool _pendingOnly = false;
  bool _unlinkedOnly = false;
  _TellerSortMode? _sortModeOverride;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onSyncFromServer() async {
    if (_syncBusy) return;
    final base = ref.read(imageBaseUrlProvider);
    final uid = ref.read(userIdProvider);
    if (base == null || base.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image / MCP HTTP URL is not configured.'),
          ),
        );
      }
      return;
    }
    if (uid == null || uid.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Not signed in.')));
      }
      return;
    }
    setState(() => _syncBusy = true);
    try {
      await postTellerSync(imageBaseUrl: base, userId: uid);
      ref.invalidate(tellerTransactionsProvider);
      await ref.read(tellerTransactionsProvider.future);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Teller sync failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _syncBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(tellerTransactionsInRangeProvider);
    final dateRange = ref.watch(expenseDateRangeProvider);
    final sortMode =
        _sortModeOverride ?? _defaultTellerSortModeForDateRange(dateRange);

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
                  if (Navigator.of(context).canPop())
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: AppColors.slate400,
                        size: 22,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  Expanded(child: Text('Teller', style: refAppBarTitleLarge())),
                  if (isDesktopLayout(context))
                    Tooltip(
                      message: 'Fetch from Teller (server sync)',
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        onPressed: _syncBusy ? null : _onSyncFromServer,
                        icon: _syncBusy
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.teal600,
                                ),
                              )
                            : const Icon(
                                Icons.refresh,
                                color: AppColors.slate400,
                                size: 22,
                              ),
                      ),
                    ),
                  const ExpenseDateRangeCalendarButton(),
                  const SizedBox(width: 4),
                  const ExpenseAppMenuButton(),
                ],
              ),
            ),
          ),
          const ExpenseDateRangeBar(bottomPadding: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              RefLayout.px5,
              0,
              RefLayout.px5,
              4,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.slate900),
              decoration: InputDecoration(
                hintText: 'Search Teller transactions...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.slate400,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 20,
                  color: AppColors.slate500,
                ),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 20,
                          color: AppColors.slate400,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      ),
                filled: true,
                fillColor: AppColors.slate100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.teal600),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              RefLayout.px5,
              0,
              RefLayout.px5,
              8,
            ),
            child: Row(
              children: [
                _TellerFilterPill(
                  label: 'Pending',
                  selected: _pendingOnly,
                  onTap: () => setState(() => _pendingOnly = !_pendingOnly),
                ),
                const SizedBox(width: 8),
                _TellerFilterPill(
                  label: 'Unlinked',
                  selected: _unlinkedOnly,
                  onTap: () => setState(() => _unlinkedOnly = !_unlinkedOnly),
                ),
                const Spacer(),
                _TellerSortButton(
                  sortMode: sortMode,
                  active: _sortModeOverride != null,
                  onSelected: (mode) =>
                      setState(() => _sortModeOverride = mode),
                ),
              ],
            ),
          ),
          Expanded(
            child: ColoredBox(
              color: AppColors.slate50.withValues(alpha: 0.5),
              child: RefreshIndicator(
                onRefresh: _onSyncFromServer,
                color: AppColors.teal600,
                child: listAsync.when(
                  loading: () => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ],
                  ),
                  error: (e, _) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Error: $e',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.slate500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  data: (rows) {
                    final filtered = _sortRows(_applyFilters(rows), sortMode);
                    if (filtered.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: RefLayout.px5,
                        ),
                        children: [
                          SizedBox(
                            height: 280,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.account_balance_outlined,
                                    size: 48,
                                    color: AppColors.slate300,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    rows.isEmpty
                                        ? 'No Teller transactions in this range'
                                        : 'No Teller transactions match',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.slate400,
                                    ),
                                  ),
                                  if (!isDesktopLayout(context)) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Swipe down to sync from Teller',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.slate400,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    final items = sortMode.isDate
                        ? _buildDateGroupedItems(ref, filtered)
                        : _buildFlatItems(ref, filtered);
                    return ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        RefLayout.px5,
                        8,
                        RefLayout.px5,
                        RefLayout.pb24,
                      ),
                      itemCount: items.length + 1,
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              _summaryFor(filtered),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.slate500,
                              ),
                            ),
                          );
                        }
                        return items[i - 1];
                      },
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

  List<Widget> _buildDateGroupedItems(
    WidgetRef ref,
    List<TellerTransactionRow> rows,
  ) {
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
            onTap: (ctx) {
              if (isDesktopLayout(ctx)) {
                ref.read(selectedTellerRowProvider.notifier).state = r;
                ref.read(tellerPanel3Provider.notifier).state = null;
              } else {
                Navigator.of(ctx).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => TellerTransactionDetailScreen(row: r),
                  ),
                );
              }
            },
          ),
        ),
      );
    }
    return items;
  }

  List<Widget> _buildFlatItems(WidgetRef ref, List<TellerTransactionRow> rows) {
    return [
      for (final r in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _TellerCard(
            row: r,
            onTap: (ctx) {
              if (isDesktopLayout(ctx)) {
                ref.read(selectedTellerRowProvider.notifier).state = r;
                ref.read(tellerPanel3Provider.notifier).state = null;
              } else {
                Navigator.of(ctx).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => TellerTransactionDetailScreen(row: r),
                  ),
                );
              }
            },
          ),
        ),
    ];
  }

  static String _dateLabel(DateTime t) {
    final d = t.toLocal();
    return DateFormat('MMM d, y').format(d);
  }

  List<TellerTransactionRow> _applyFilters(List<TellerTransactionRow> rows) {
    final query = _searchController.text.trim().toLowerCase();
    return rows.where((row) {
      if (_pendingOnly && !_isPending(row)) return false;
      if (_unlinkedOnly && tellerRowHasExpenseOrTransferLink(row)) {
        return false;
      }
      if (query.isEmpty) return true;
      return _searchText(row).contains(query);
    }).toList();
  }

  static _TellerSortMode _defaultTellerSortModeForDateRange(
    DateTimeRange range,
  ) {
    return isDateRangeCurrentCalendarMonth(range)
        ? _TellerSortMode.dateDesc
        : _TellerSortMode.dateAsc;
  }

  static List<TellerTransactionRow> _sortRows(
    List<TellerTransactionRow> rows,
    _TellerSortMode mode,
  ) {
    final sorted = [...rows];
    switch (mode) {
      case _TellerSortMode.dateAsc:
        sorted.sort((a, b) => a.time.compareTo(b.time));
      case _TellerSortMode.dateDesc:
        sorted.sort((a, b) => b.time.compareTo(a.time));
      case _TellerSortMode.amountAsc:
        sorted.sort((a, b) => _amountSortKey(a).compareTo(_amountSortKey(b)));
      case _TellerSortMode.amountDesc:
        sorted.sort((a, b) => _amountSortKey(b).compareTo(_amountSortKey(a)));
    }
    return sorted;
  }

  static num _amountSortKey(TellerTransactionRow row) {
    return num.tryParse(row.payload['amount']?.toString().trim() ?? '') ?? 0;
  }

  static bool _isPending(TellerTransactionRow row) {
    return row.payload['status']?.toString().trim().toLowerCase() == 'pending';
  }

  static String _searchText(TellerTransactionRow row) {
    final details = row.payload['details'];
    final counterparty = details is Map
        ? (details['counterparty'] is Map
              ? (details['counterparty'] as Map)['name']
              : null)
        : null;
    final linked = row.linkedModels.map((m) => '${m.name} ${m.modelTypeName}');
    return [
      tellerTransactionTitleLine(row.payload),
      row.payload['description'],
      row.payload['amount'],
      row.payload['status'],
      row.payload['type'],
      row.payload['date'],
      counterparty,
      ...linked,
    ].whereType<Object>().join(' ').toLowerCase();
  }

  static String _summaryFor(List<TellerTransactionRow> rows) {
    num? sum;
    for (final row in rows) {
      final amount = num.tryParse(row.payload['amount']?.toString() ?? '');
      if (amount != null) sum = (sum ?? 0) + amount;
    }
    return sum == null
        ? '${rows.length}'
        : '${rows.length} · ${formatMoney(sum)}';
  }
}

class _TellerSortButton extends StatelessWidget {
  const _TellerSortButton({
    required this.sortMode,
    required this.active,
    required this.onSelected,
  });

  final _TellerSortMode sortMode;
  final bool active;
  final ValueChanged<_TellerSortMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_TellerSortMode>(
      tooltip: 'Sort Teller transactions',
      offset: const Offset(0, 36),
      onSelected: onSelected,
      itemBuilder: (context) => [
        _item(
          mode: _TellerSortMode.dateAsc,
          current: sortMode,
          icon: Icons.arrow_upward_rounded,
          label: 'Date',
        ),
        _item(
          mode: _TellerSortMode.dateDesc,
          current: sortMode,
          icon: Icons.arrow_downward_rounded,
          label: 'Date',
        ),
        _item(
          mode: _TellerSortMode.amountAsc,
          current: sortMode,
          icon: Icons.arrow_upward_rounded,
          label: 'Amount',
        ),
        _item(
          mode: _TellerSortMode.amountDesc,
          current: sortMode,
          icon: Icons.arrow_downward_rounded,
          label: 'Amount',
        ),
      ],
      child: Container(
        width: 36,
        height: 34,
        decoration: BoxDecoration(
          color: active ? AppColors.teal100 : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? AppColors.teal600 : AppColors.slate200,
          ),
        ),
        child: Icon(
          Icons.sort,
          size: 18,
          color: active ? AppColors.teal700 : AppColors.slate500,
        ),
      ),
    );
  }

  PopupMenuItem<_TellerSortMode> _item({
    required _TellerSortMode mode,
    required _TellerSortMode current,
    required IconData icon,
    required String label,
  }) {
    final selected = mode == current;
    return PopupMenuItem<_TellerSortMode>(
      value: mode,
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.slate500),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.slate700,
              ),
            ),
          ),
          if (selected)
            const Icon(Icons.check_rounded, size: 18, color: AppColors.teal600),
        ],
      ),
    );
  }
}

class _TellerFilterPill extends StatelessWidget {
  const _TellerFilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.teal100 : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.teal600 : AppColors.slate200,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.teal700 : AppColors.slate500,
          ),
        ),
      ),
    );
  }
}

class _TellerCard extends StatelessWidget {
  const _TellerCard({required this.row, required this.onTap});

  final TellerTransactionRow row;
  final void Function(BuildContext context) onTap;

  @override
  Widget build(BuildContext context) {
    final title = tellerTransactionTitleLine(row.payload);
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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate900,
                        ),
                      ),
                    ),
                    if (tellerPayloadIsDeleted(row.payload)) ...[
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Tooltip(
                          message: 'Removed from Teller (no longer in API)',
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: AppColors.slate500,
                          ),
                        ),
                      ),
                    ] else if (!tellerRowHasExpenseOrTransferLink(row)) ...[
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Tooltip(
                          message: 'No expense or transfer linked yet',
                          child: Icon(
                            Icons.link_off_rounded,
                            size: 18,
                            color: AppColors.slate400,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (amt != null) ...[
                const SizedBox(width: 8),
                Text(
                  formatMoney(amt),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.teal600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static num? _parseAmount(dynamic raw) {
    if (raw == null) return null;
    return num.tryParse(raw.toString().trim());
  }
}
