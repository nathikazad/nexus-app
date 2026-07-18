import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nx_expense/core/formatting/format.dart';
import 'package:nx_expense/core/layout/layout.dart';
import 'package:nx_expense/core/theme/app_theme.dart';
import 'package:nx_expense/data/providers.dart';
import 'package:nx_expense/data/schema/kgql_schema_helpers.dart';
import 'package:nx_expense/domain/expense/expense.dart';
import 'package:nx_expense/domain/expense/expense_product_line.dart';
import 'package:nx_expense/domain/expense/model_names.dart';
import 'package:nx_expense/domain/expense/related_model.dart';
import 'package:nx_expense/domain/schema/model_type_view.dart';
import 'package:nx_expense/features/desktop/desktop_nav.dart';
import 'package:nx_expense/features/desktop/panel_chrome.dart';
import 'package:nx_expense/features/expense/widgets/expense_bills_section.dart';
import 'package:nx_expense/features/products/widgets/product_line_card.dart';
import 'package:nx_expense/features/teller/widgets/teller_detail_readonly_section.dart';

class ExpenseDetailScreen extends ConsumerWidget {
  const ExpenseDetailScreen({super.key, required this.expenseId});

  final int expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schemaAsync = ref.watch(expenseSchemaViewProvider);
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
          data: (expense) {
            if (expense == null) {
              return Scaffold(
                appBar: AppBar(),
                body: const Center(child: Text('Expense not found')),
              );
            }
            return ExpenseDetailContent(
              schema: schema,
              expense: expense,
              expenseId: expenseId,
            );
          },
        );
      },
    );
  }
}

class ExpenseDetailContent extends ConsumerWidget {
  const ExpenseDetailContent({
    super.key,
    required this.schema,
    required this.expense,
    required this.expenseId,
  });

  final ModelTypeView schema;
  final Expense expense;
  final int expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryKey = primaryNumberAttributeKey(schema);
    num? headerAmount;
    if (primaryKey != null) {
      final v = attributeValue(expense, primaryKey);
      if (v is num) headerAmount = v;
      if (v is String) headerAmount = num.tryParse(v);
    }

    final attrDefs = schema.attributes
        .where((a) => a.key != null && a.key != primaryKey)
        .toList();

    final tagSystems = schema.tagSystems;

    final detailBody = Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) => ListView(
          padding: EdgeInsets.zero,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 840),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        vertical: constraints.maxWidth < 600 ? 32 : 40,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AppColors.slate100),
                        ),
                        color: Color(0x4DF8FAFC),
                      ),
                      child: Column(
                        children: [
                          Text(
                            headerAmount != null
                                ? formatMoney(headerAmount)
                                : '—',
                            style: GoogleFonts.inter(
                              fontSize: constraints.maxWidth < 600 ? 34 : 40,
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
                                modelDateCellLabel(expense),
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
                          if (expense.description != null &&
                              expense.description!.isNotEmpty) ...[
                            Text(
                              'Description',
                              style: refSectionTitle(context),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              expense.description!,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                height: 1.6,
                                color: AppColors.slate700,
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],

                          if (expense.description == null ||
                              expense.description!.isEmpty)
                            const SizedBox(height: 24),

                          if (expense.products.isNotEmpty) ...[
                            _ExpenseProductsSection(
                              products: expense.products,
                              expenseAmount: headerAmount,
                              onRelatedExpenses: (product) =>
                                  navToRelationExpenses(
                                    context,
                                    ref,
                                    relName: kProductModelTypeName,
                                    relId: product.id,
                                    displayName: product.name,
                                  ),
                            ),
                            const SizedBox(height: 32),
                          ],

                          if (_hasAnyTags(tagSystems)) ...[
                            Text('Tags', style: refSectionTitle(context)),
                            const SizedBox(height: 12),
                            for (final sys in tagSystems)
                              if ((expense.tags?[sys.name] ?? []).isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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

                          if (expense.relations != null &&
                              expense.relations!.isNotEmpty)
                            for (final e in expense.relations!.entries)
                              if (e.key != kTransferModelTypeName &&
                                  e.key != kProductModelTypeName)
                                if (dedupeModelsById(e.value).isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 24),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          formatAttributeLabel(e.key),
                                          style: refSectionTitle(context),
                                        ),
                                        const SizedBox(height: 12),
                                        for (final relM in dedupeModelsById(
                                          e.value,
                                        ))
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 10,
                                            ),
                                            child: _relationRow(
                                              context,
                                              ref,
                                              e.key,
                                              relM,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),

                          if (expense.relations?[kTransferModelTypeName] !=
                                  null &&
                              dedupeModelsById(
                                expense.relations![kTransferModelTypeName]!,
                              ).isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Transfer',
                                    style: refSectionTitle(context),
                                  ),
                                  const SizedBox(height: 12),
                                  for (final relM in dedupeModelsById(
                                    expense.relations![kTransferModelTypeName]!,
                                  ))
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: _transferCell(context, ref, relM),
                                    ),
                                ],
                              ),
                            ),

                          _MoreDetailsSection(
                            expense: expense,
                            attrDefs: attrDefs,
                            formatAttribute: (definition) => _formatAttr(
                              expense,
                              definition.key!,
                              definition.valueType,
                            ),
                          ),
                          const SizedBox(height: 32),

                          TellerDetailReadonlySection(modelId: expenseId),
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
            ),
          ],
        ),
      ),
    );

    if (isDesktopLayout(context)) {
      return PanelChrome(
        title: expense.name,
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
        body: Column(children: [detailBody]),
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
          expense.name,
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
      body: Column(children: [detailBody]),
    );
  }

  String _formatAttr(Expense expense, String key, String? valueType) {
    final v = attributeValue(expense, key);
    return formatDisplayAttributeValue(v, valueType);
  }

  bool _hasAnyTags(List<TagSystemView> systems) {
    for (final sys in systems) {
      if ((expense.tags?[sys.name] ?? []).isNotEmpty) return true;
    }
    return false;
  }

  Widget _buildTagValues(
    BuildContext context,
    WidgetRef ref,
    TagSystemView sys,
  ) {
    final nodes = expense.tags?[sys.name] ?? [];
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
    TagSystemView sys,
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
      border: Border.all(color: AppColors.slate200.withValues(alpha: 0.6)),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 0,
                    ),
                    child: Text(path[i], style: chipTextStyle),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    final label = path != null && path.isNotEmpty
        ? path.join(' \u203A ')
        : node;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () =>
            navToTagExpenses(context, ref, systemName: sys.name, tagNode: node),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: decoration,
          child: Text(label, style: chipTextStyle),
        ),
      ),
    );
  }

  Widget _transferCell(BuildContext context, WidgetRef ref, RelatedModel relM) {
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
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.slate300,
                  size: 22,
                ),
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
    RelatedModel relModel,
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
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.slate300,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpenseProductsSection extends StatelessWidget {
  const _ExpenseProductsSection({
    required this.products,
    required this.expenseAmount,
    required this.onRelatedExpenses,
  });

  final List<ExpenseProductLine> products;
  final num? expenseAmount;
  final ValueChanged<ExpenseProductLine> onRelatedExpenses;

  @override
  Widget build(BuildContext context) {
    final knownTotals = products
        .map((product) => product.lineTotal)
        .whereType<num>()
        .toList();
    final productSubtotal = knownTotals.isEmpty
        ? null
        : knownTotals.fold<num>(0, (sum, value) => sum + value);
    final normalizedExpenseTotal = expenseAmount?.abs();
    final difference = productSubtotal == null || normalizedExpenseTotal == null
        ? null
        : normalizedExpenseTotal - productSubtotal.abs();
    final hasMeaningfulDifference =
        difference != null && difference.abs() >= .005;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Products (${products.length})',
          key: const Key('expense-products-heading'),
          style: refSectionTitle(context),
        ),
        const SizedBox(height: 12),
        for (final product in products)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ProductLineCard(
              key: ValueKey('expense-product-${product.id}'),
              name: product.name,
              imageUrl: product.imageUrl,
              brand: product.brand,
              quantity: product.quantity,
              unit: product.unit,
              unitPrice: product.price,
              lineTotal: product.lineTotal,
              onRelatedExpenses: () => onRelatedExpenses(product),
              onOpenItem: _validWebUri(product.itemUrl) == null
                  ? null
                  : () => launchUrl(_validWebUri(product.itemUrl)!),
            ),
          ),
        if (productSubtotal != null || normalizedExpenseTotal != null)
          Container(
            key: const Key('expense-products-reconciliation'),
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.slate50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.slate100),
            ),
            child: Column(
              children: [
                if (productSubtotal != null)
                  _MoneySummaryRow(
                    label: 'Products subtotal',
                    value: productSubtotal,
                  ),
                if (hasMeaningfulDifference) ...[
                  const SizedBox(height: 7),
                  _MoneySummaryRow(
                    label: difference >= 0
                        ? 'Unallocated / tax / fees'
                        : 'Product total difference',
                    value: difference,
                  ),
                ],
                if (normalizedExpenseTotal != null) ...[
                  const Divider(height: 17, color: AppColors.slate200),
                  _MoneySummaryRow(
                    label: 'Expense total',
                    value: normalizedExpenseTotal,
                    emphasized: true,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

Uri? _validWebUri(String? value) {
  final uri = Uri.tryParse(value ?? '');
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return null;
  }
  return uri;
}

class _MoneySummaryRow extends StatelessWidget {
  const _MoneySummaryRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final num value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final weight = emphasized ? FontWeight.w700 : FontWeight.w500;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: weight,
              color: emphasized ? AppColors.slate700 : AppColors.slate500,
            ),
          ),
        ),
        Text(
          formatMoney(value),
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: weight,
            color: emphasized ? AppColors.slate900 : AppColors.slate600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _MoreDetailsSection extends StatelessWidget {
  const _MoreDetailsSection({
    required this.expense,
    required this.attrDefs,
    required this.formatAttribute,
  });

  final Expense expense;
  final List<AttributeDefView> attrDefs;
  final String Function(AttributeDefView definition) formatAttribute;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('expense-more-details'),
      color: Colors.white,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
        side: const BorderSide(color: AppColors.slate100),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: EdgeInsets.zero,
        title: Text(
          'More details',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.slate700,
          ),
        ),
        children: [
          const Divider(height: 1, color: AppColors.slate100),
          _AttrRow(
            label: 'Id',
            value: '${expense.id}',
            showDivider: attrDefs.isNotEmpty,
          ),
          for (var i = 0; i < attrDefs.length; i++)
            _AttrRow(
              label: formatAttributeLabel(attrDefs[i].key!),
              value: formatAttribute(attrDefs[i]),
              showDivider: i < attrDefs.length - 1,
            ),
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
