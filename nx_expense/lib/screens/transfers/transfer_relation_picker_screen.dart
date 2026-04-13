import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:nx_db/nx_db.dart';

import '../../app_theme.dart';
import '../../layout.dart';
import '../../providers/expense_providers.dart';
import '../../util/expense_schema.dart';
import '../../util/format.dart';
import '../../widgets/expense_date_range_bar.dart';
import '../../widgets/relation_picker.dart';

/// Passed via GoRouter `extra` to [TransferRelationPickerScreen].
class TransferRelationPickerExtra {
  const TransferRelationPickerExtra({
    required this.allowMultiple,
    required this.initialIds,
  });

  final bool allowMultiple;
  final List<int> initialIds;
}

/// Full-screen transfer list (matches [TransfersListScreen] layout); tap a row to
/// return a [RelationPickResult] and pop.
class TransferRelationPickerScreen extends ConsumerStatefulWidget {
  const TransferRelationPickerScreen({
    super.key,
    required this.allowMultiple,
    required this.initialIds,
  });

  final bool allowMultiple;
  final List<int> initialIds;

  @override
  ConsumerState<TransferRelationPickerScreen> createState() =>
      _TransferRelationPickerScreenState();
}

class _TransferRelationPickerScreenState
    extends ConsumerState<TransferRelationPickerScreen> {
  late Set<int> _sel;

  @override
  void initState() {
    super.initState();
    _sel = {...dedupeIntIdsPreserveOrder(widget.initialIds)};
  }

  Future<void> _createNew() async {
    final map = await showCreateRelationSheetForType(
      context,
      targetModelTypeName: kTransferModelTypeName,
    );
    if (!mounted || map == null) return;
    context.pop(RelationPickCreate(map));
  }

  void _onCardTap(Model m) {
    final id = m.id;
    if (!widget.allowMultiple) {
      context.pop(RelationPickLink([id]));
      return;
    }
    setState(() {
      if (_sel.contains(id)) {
        _sel.remove(id);
      } else {
        _sel.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(transferListForUiProvider);
    final summaryAsync = ref.watch(transferListSummaryProvider);
    final schemaAsync = ref.watch(transferSchemaProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.slate400, size: 22),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: Text(
          'Select transfer',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            color: AppColors.slate900,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.slate100),
        ),
        actions: [
          if (widget.allowMultiple)
            TextButton(
              onPressed: () => context.pop(
                RelationPickLink(dedupeIntIdsPreserveOrder(_sel.toList())),
              ),
              child: Text(
                'Done',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.teal600,
                ),
              ),
            ),
        ],
      ),
      body: schemaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: SelectableText('Schema: $e')),
        data: (schema) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  RefLayout.px5,
                  RefLayout.appBarTop,
                  RefLayout.px5,
                  RefLayout.pb4,
                ),
                child: Row(
                  children: [
                    Expanded(child: Text('Transfers', style: refAppBarTitleLarge())),
                    const ExpenseDateRangeCalendarButton(),
                  ],
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
                      ref.invalidate(transferSchemaProvider);
                      ref.invalidate(transferListProvider);
                      ref.invalidate(transferListForUiProvider);
                      ref.invalidate(transferListSummaryProvider);
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
                      data: (models) {
                        if (models.isEmpty) {
                          return ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 48),
                              Icon(Icons.swap_horiz_rounded, size: 48, color: AppColors.slate300),
                              const SizedBox(height: 12),
                              Center(
                                child: Text(
                                  'No transfers in this range',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.slate400,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                        final items = _buildDateGroupedItems(models, schema);
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(RefLayout.px5, 8, RefLayout.px5, 28),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.slate100)),
                ),
                child: OutlinedButton(
                  onPressed: _createNew,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.slate200, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_circle_outline, color: AppColors.slate500, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Create new Transfer',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildDateGroupedItems(List<Model> models, ModelType schema) {
    final items = <Widget>[];
    String? lastDate;
    final amountKey = primaryNumberAttributeKey(schema);

    for (final m in models) {
      final dateStr = _dateLabel(m.createdAt);
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
      final id = m.id;
      final selected = _sel.contains(id);
      items.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _TransferPickCard(
            title: transferDisplayTitle(m),
            amount: amountKey != null ? _num(m, amountKey) : null,
            showCheckbox: widget.allowMultiple,
            selected: selected,
            onTap: () => _onCardTap(m),
          ),
        ),
      );
    }
    return items;
  }

  static String _dateLabel(String? iso) {
    if (iso == null || iso.isEmpty) return 'Unknown';
    try {
      final d = DateTime.parse(iso);
      return DateFormat('MMM d, y').format(d);
    } catch (_) {
      return iso;
    }
  }

  static num? _num(Model m, String key) {
    final raw = attributeValue(m, key);
    if (raw is num) return raw;
    return num.tryParse('$raw');
  }
}

class _TransferPickCard extends StatelessWidget {
  const _TransferPickCard({
    required this.title,
    required this.amount,
    required this.showCheckbox,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final num? amount;
  final bool showCheckbox;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
              if (amount != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    formatMoney(amount),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.teal600,
                    ),
                  ),
                ),
              if (showCheckbox)
                Checkbox(
                  value: selected,
                  activeColor: AppColors.teal600,
                  onChanged: (_) => onTap(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
