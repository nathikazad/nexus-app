import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nx_db/nx_db.dart';

import '../app_theme.dart';
import '../reference_layout.dart';
import '../expense_schema.dart';
import '../format.dart';
import '../providers/expense_providers.dart';

class ExpenseDetailScreen extends ConsumerWidget {
  const ExpenseDetailScreen({super.key, required this.expenseId});

  final int expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schemaAsync = ref.watch(expenseSchemaProvider);
    final modelAsync = ref.watch(expenseDetailProvider(expenseId));

    return schemaAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (schema) {
        return modelAsync.when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
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
            return _DetailBody(schema: schema, model: model, expenseId: expenseId);
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.slate400, size: 22),
          onPressed: () => context.pop(),
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
            icon: const Icon(Icons.edit_outlined, color: AppColors.slate400, size: 22),
            onPressed: () => context.push('/expense/form/$expenseId'),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.slate100),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.slate100)),
                    color: Color(0x4DF8FAFC),
                  ),
                  child: Column(
                    children: [
                      Text(
                        headerAmount != null ? formatMoney(headerAmount) : r'$45.00',
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
                          const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.slate400),
                          const SizedBox(width: 6),
                          Text(
                            model.createdAt != null
                                ? formatModelDateTime(model.createdAt)
                                : 'Mar 15, 2026, 2:30 PM',
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
                      Text('Description', style: refSectionTitle(context)),
                      const SizedBox(height: 12),
                      Text(
                        (model.description != null && model.description!.isNotEmpty)
                            ? model.description!
                            : 'Coffee meeting with client regarding the new Q3 marketing campaign deliverables and timelines.',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          height: 1.6,
                          color: AppColors.slate700,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text('Attributes', style: refSectionTitle(context)),
                      const SizedBox(height: 12),
                      Builder(
                        builder: (context) {
                          final attrs = (schema.attributes ?? const <AttributeDefinition>[])
                              .where((a) => a.key != null && a.key != primaryKey)
                              .toList();
                          if (attrs.isEmpty) {
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
                                border: Border.all(color: AppColors.slate100),
                                boxShadow: refCardShadow,
                              ),
                              child: Column(
                                children: [
                                  _AttrRow(
                                    label: 'Receipt',
                                    value: 'Yes',
                                    showDivider: true,
                                  ),
                                  _AttrRow(
                                    label: 'Tax Deductible',
                                    value: 'Yes',
                                    showDivider: true,
                                  ),
                                  _AttrRow(
                                    label: 'Payment Method',
                                    value: 'Amex *3045',
                                    showDivider: false,
                                  ),
                                ],
                              ),
                            );
                          }
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
                              border: Border.all(color: AppColors.slate100),
                              boxShadow: refCardShadow,
                            ),
                            child: Column(
                              children: [
                                for (var i = 0; i < attrs.length; i++)
                                  _AttrRow(
                                    label: attrs[i].key!,
                                    value: _formatAttr(model, attrs[i].key!),
                                    showDivider: i < attrs.length - 1,
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                      Text('Tags', style: refSectionTitle(context)),
                      const SizedBox(height: 12),
                      if (model.tags == null || model.tags!.isEmpty)
                        _placeholderTags()
                      else
                        for (final sys in schema.tagSystems ?? const <TagSystem>[]) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sys.name,
                                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate400),
                                  ),
                                  const SizedBox(height: 6),
                                  if ((model.tags![sys.name] ?? []).isEmpty)
                                    Text('None', style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate500))
                                  else
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        for (final node in model.tags![sys.name]!)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: AppColors.slate100,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: AppColors.slate200.withValues(alpha: 0.6)),
                                            ),
                                            child: Text(
                                              () {
                                                final path = tagBreadcrumbPath(sys, node);
                                                return path != null && path.length > 1 ? path.join(' › ') : node;
                                              }(),
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: AppColors.slate700,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      const SizedBox(height: 20),
                      Text('Relations', style: refSectionTitle(context)),
                      const SizedBox(height: 12),
                      if (model.relations == null || model.relations!.isEmpty)
                        _placeholderRelationRow()
                      else
                        for (final e in model.relations!.entries)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Material(
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(color: AppColors.slate100),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {},
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(0xFFCCFBF1),
                                        ),
                                        child: const Icon(Icons.storefront_outlined, size: 18, color: AppColors.teal600),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              e.key.toUpperCase(),
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                                letterSpacing: 0.8,
                                                color: AppColors.slate400,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              e.value.map((m) => m.name).join(', '),
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.slate900,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right, color: AppColors.slate300),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.slate50)),
            ),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.delete_outline),
              label: Text('Delete Expense', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete expense?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                    ],
                  ),
                );
                if (ok != true || !context.mounted) return;
                final req = SetModelRequest(id: expenseId, delete: true);
                try {
                  await createModel(ref.container, req);
                  ref.invalidate(expenseListForUiProvider);
                  ref.invalidate(expenseSummaryProvider);
                  if (context.mounted) {
                    context.go('/expenses');
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatAttr(Model model, String key) {
    final v = attributeValue(model, key);
    if (v == null) return '—';
    if (v is bool) return v ? 'Yes' : 'No';
    return v.toString();
  }

  Widget _placeholderTags() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Category', style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate400)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.slate100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.slate200.withValues(alpha: 0.6)),
          ),
          child: Text.rich(
            TextSpan(
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.slate700),
              children: [
                const TextSpan(text: 'Food '),
                TextSpan(text: '›', style: GoogleFonts.inter(color: AppColors.slate400)),
                const TextSpan(text: ' Fast Food'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('Priority', style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate400)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.slate100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.slate200.withValues(alpha: 0.6)),
          ),
          child: Text(
            'Medium',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.slate700),
          ),
        ),
      ],
    );
  }

  Widget _placeholderRelationRow() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
        border: Border.all(color: AppColors.slate100),
        boxShadow: refCardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFCCFBF1),
            ),
            child: const Icon(Icons.storefront_outlined, size: 18, color: AppColors.teal600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VENDOR',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.8,
                    color: AppColors.slate400,
                  ),
                ),
                Text(
                  'Starbucks',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.slate900),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.slate300),
        ],
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
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.slate500),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slate900),
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
