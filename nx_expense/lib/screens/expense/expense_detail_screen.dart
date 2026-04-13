import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nx_db/nx_db.dart';

import '../../app_theme.dart';
import '../../desktop/desktop_nav.dart';
import '../../desktop/panel_chrome.dart';
import '../../layout.dart';
import '../../util/expense_schema.dart';
import '../../util/format.dart';
import '../../providers/expense_providers.dart';
import '../../util/teller_display.dart';
import '../../widgets/expense_bills_section.dart';
import '../teller/teller_transaction_detail_screen.dart';

class ExpenseDetailScreen extends ConsumerWidget {
  const ExpenseDetailScreen({super.key, required this.expenseId});

  final int expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schemaAsync = ref.watch(expenseSchemaProvider);
    final modelAsync = ref.watch(expenseDetailProvider(expenseId));

    return schemaAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (schema) {
        return modelAsync.when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(
            appBar: AppBar(),
            body: Center(child: SelectableText('$e')),
          ),
          data: (model) {
            if (model == null) {
              return Scaffold(
                appBar: AppBar(),
                body: const Center(child: Text('Expense not found')),
              );
            }
            return _DetailBody(
              schema: schema,
              model: model,
              expenseId: expenseId,
            );
          },
        );
      },
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({
    required this.schema,
    required this.model,
    required this.expenseId,
  });

  final ModelType schema;
  final Model model;
  final int expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryKey = primaryNumberAttributeKey(schema);
    num? headerAmount;
    if (primaryKey != null) {
      final v = attributeValue(model, primaryKey);
      if (v is num) headerAmount = v;
      if (v is String) headerAmount = num.tryParse(v);
    }

    // Collect non-primary attributes that have values
    final attrDefs = (schema.attributes ?? const <AttributeDefinition>[])
        .where((a) => a.key != null && a.key != primaryKey)
        .toList();

    final tagSystems = schema.tagSystems ?? const <TagSystem>[];
    final tellerAsync = ref.watch(expenseTimelineLinksProvider(expenseId));

    final detailBody = Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Header: amount + date
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.slate100),
                    ),
                    color: Color(0x4DF8FAFC),
                  ),
                  child: Column(
                    children: [
                      Text(
                        headerAmount != null ? formatMoney(headerAmount) : '—',
                        style: GoogleFonts.inter(
                          fontSize: 40,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -1,
                          height: 1,
                          color: AppColors.teal600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: AppColors.slate400,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            model.createdAt != null
                                ? formatModelDateTime(model.createdAt)
                                : '—',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.slate400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(RefLayout.px5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Description
                      if (model.description != null &&
                          model.description!.isNotEmpty) ...[
                        Text('Description', style: refSectionTitle(context)),
                        const SizedBox(height: 12),
                        Text(
                          model.description!,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            height: 1.6,
                            color: AppColors.slate700,
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],

                      // Attributes
                      if (attrDefs.isNotEmpty) ...[
                        Text('Attributes', style: refSectionTitle(context)),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(
                              RefLayout.rounded2xl,
                            ),
                            border: Border.all(color: AppColors.slate100),
                            boxShadow: refCardShadow,
                          ),
                          child: Column(
                            children: [
                              for (var i = 0; i < attrDefs.length; i++)
                                _AttrRow(
                                  label: formatAttributeLabel(attrDefs[i].key!),
                                  value: _formatAttr(model, attrDefs[i].key!),
                                  showDivider: i < attrDefs.length - 1,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],

                      // Tags — only show systems that have assigned nodes
                      if (_hasAnyTags(tagSystems)) ...[
                        Text('Tags', style: refSectionTitle(context)),
                        const SizedBox(height: 12),
                        for (final sys in tagSystems)
                          if ((model.tags?[sys.name] ?? []).isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sys.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppColors.slate400,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  _buildTagValues(context, ref, sys),
                                ],
                              ),
                            ),
                        const SizedBox(height: 20),
                      ],

                      // Relations — one heading per target type (not Transfer; see below)
                      if (model.relations != null && model.relations!.isNotEmpty)
                        for (final e in model.relations!.entries)
                          if (e.key != kTransferModelTypeName)
                            if (dedupeModelsById(e.value).isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      formatAttributeLabel(e.key),
                                      style: refSectionTitle(context),
                                    ),
                                    const SizedBox(height: 12),
                                    for (final relM in dedupeModelsById(e.value))
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 10),
                                        child: _relationRow(context, ref, e.key, relM),
                                      ),
                                  ],
                                ),
                              ),

                      if (model.relations?[kTransferModelTypeName] != null &&
                          dedupeModelsById(model.relations![kTransferModelTypeName]!)
                              .isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Transfer', style: refSectionTitle(context)),
                              const SizedBox(height: 12),
                              for (final relM in dedupeModelsById(
                                model.relations![kTransferModelTypeName]!,
                              ))
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _transferCell(context, ref, relM),
                                ),
                            ],
                          ),
                        ),

                      // Teller (bank) transactions — below Relations / Transfer
                      Padding(
                        padding: const EdgeInsets.only(top: 32),
                        child: tellerAsync.when(
                          loading: () => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Teller', style: refSectionTitle(context)),
                              const SizedBox(height: 12),
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          error: (e, _) => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Teller', style: refSectionTitle(context)),
                              const SizedBox(height: 8),
                              Text(
                                'Could not load Teller links.',
                                style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate400),
                              ),
                            ],
                          ),
                          data: (links) {
                            final tellerLinks =
                                links.where((l) => l.isTellerTimelineEvent).toList();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('Teller', style: refSectionTitle(context)),
                                const SizedBox(height: 12),
                                if (tellerLinks.isEmpty)
                                  Text(
                                    'No linked Teller transactions.',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: AppColors.slate400,
                                    ),
                                  )
                                else
                                  for (final link in tellerLinks)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Builder(
                                        builder: (context) {
                                          final amt = num.tryParse(
                                            link.payload['amount']?.toString().trim() ?? '',
                                          );
                                          final dateStr = tellerDetailDateLabel(
                                            link.payload,
                                            link.eventTime,
                                          );
                                          return Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: () {
                                                final row = link.toTellerTransactionRow();
                                                if (isDesktopLayout(context)) {
                                                  pushPanel3(
                                                    ref,
                                                    Panel3State(
                                                      type: Panel3Type.teller,
                                                      tellerRow: row,
                                                    ),
                                                  );
                                                } else {
                                                  Navigator.of(context).push<void>(
                                                    MaterialPageRoute<void>(
                                                      builder: (_) =>
                                                          TellerTransactionDetailScreen(row: row),
                                                    ),
                                                  );
                                                }
                                              },
                                              borderRadius: BorderRadius.circular(
                                                RefLayout.rounded2xl,
                                              ),
                                              child: Ink(
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(
                                                    RefLayout.rounded2xl,
                                                  ),
                                                  border: Border.all(color: AppColors.slate100),
                                                  boxShadow: refCardShadow,
                                                ),
                                                padding: const EdgeInsets.all(16),
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            tellerDetailHeadline(link.payload),
                                                            style: GoogleFonts.inter(
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.w600,
                                                              color: AppColors.slate900,
                                                            ),
                                                          ),
                                                          const SizedBox(height: 6),
                                                          Text(
                                                            dateStr,
                                                            style: GoogleFonts.inter(
                                                              fontSize: 12,
                                                              color: AppColors.slate400,
                                                            ),
                                                          ),
                                                          const SizedBox(height: 4),
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
                                                    Icon(
                                                      Icons.chevron_right,
                                                      color: AppColors.slate400,
                                                      size: 22,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                              ],
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 32),
                        child: ExpenseBillsSection(expenseId: expenseId),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Delete button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.slate50)),
            ),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.delete_outline),
              label: Text(
                'Delete Expense',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete expense?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (ok != true || !context.mounted) return;
                final req = SetModelRequest(id: expenseId, delete: true);
                try {
                  await createModel(ref.container, req);
                  ref.invalidate(expenseListForUiProvider);
                  ref.invalidate(expenseListSummaryProvider);
                  if (context.mounted) navAfterExpenseDelete(context, ref);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('$e')));
                  }
                }
              },
            ),
          ),
        ],
    );

    if (isDesktopLayout(context)) {
      return PanelChrome(
        title: model.name,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: AppColors.slate400,
            size: 22,
          ),
          onPressed: () =>
              navExpenseDetailBack(context, ref, expenseId: expenseId),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.edit_outlined,
              color: AppColors.slate400,
              size: 22,
            ),
            onPressed: () => context.push('/expense/form/$expenseId'),
          ),
        ],
        body: detailBody,
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: AppColors.slate400,
            size: 22,
          ),
          onPressed: () =>
              navExpenseDetailBack(context, ref, expenseId: expenseId),
        ),
        centerTitle: true,
        title: Text(
          model.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: refAppBarTitleBase(),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.edit_outlined,
              color: AppColors.slate400,
              size: 22,
            ),
            onPressed: () => context.push('/expense/form/$expenseId'),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.slate100),
        ),
      ),
      body: detailBody,
    );
  }

  String _formatAttr(Model model, String key) {
    final v = attributeValue(model, key);
    if (v == null) return '—';
    if (v is bool) return v ? 'Yes' : 'No';
    if (v is num) return formatMoney(v);
    return v.toString();
  }

  bool _hasAnyTags(List<TagSystem> systems) {
    for (final sys in systems) {
      if ((model.tags?[sys.name] ?? []).isNotEmpty) return true;
    }
    return false;
  }

  Widget _buildTagValues(BuildContext context, WidgetRef ref, TagSystem sys) {
    final nodes = model.tags?[sys.name] ?? [];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final node in nodes)
          _buildTagAssignmentChip(context, ref, sys, node),
      ],
    );
  }

  Widget _buildTagAssignmentChip(
    BuildContext context,
    WidgetRef ref,
    TagSystem sys,
    String node,
  ) {
    final path = tagBreadcrumbPath(sys, node);
    final chipTextStyle = GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: AppColors.slate700,
    );
    final sepStyle = chipTextStyle.copyWith(color: AppColors.slate400);
    final decoration = BoxDecoration(
      color: AppColors.slate100,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: AppColors.slate200.withValues(alpha: 0.6),
      ),
    );

    if (path != null && path.length > 1) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: decoration,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < path.length; i++) ...[
              if (i > 0) Text(' \u203A ', style: sepStyle),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => navToTagExpenses(
                    context,
                    ref,
                    systemName: sys.name,
                    tagNode: path[i],
                  ),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    child: Text(path[i], style: chipTextStyle),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    final label =
        path != null && path.isNotEmpty ? path.join(' \u203A ') : node;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => navToTagExpenses(
          context,
          ref,
          systemName: sys.name,
          tagNode: node,
        ),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: decoration,
          child: Text(label, style: chipTextStyle),
        ),
      ),
    );
  }

  Widget _transferCell(BuildContext context, WidgetRef ref, Model relM) {
    final title = transferDisplayTitle(relM);
    final amt = transferAmountAttribute(relM);
    final dateStr = transferCellDateLabel(relM);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate100),
        boxShadow: refCardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => navToTransferDetail(context, ref, relM.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        dateStr,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.slate400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  amt != null ? formatMoney(amt) : '—',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.teal600,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: AppColors.slate300, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _relationRow(
    BuildContext context,
    WidgetRef ref,
    String relName,
    Model relModel,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate100),
        boxShadow: refCardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => navToRelationExpenses(
            context,
            ref,
            relName: relName,
            relId: relModel.id,
            displayName: relModel.name,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    relModel.name,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate900,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.slate300, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AttrRow extends StatelessWidget {
  const _AttrRow({
    required this.label,
    required this.value,
    required this.showDivider,
  });

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.slate500,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate900,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1, color: AppColors.slate50),
      ],
    );
  }
}

