import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nx_expense/core/formatting/format.dart';
import 'package:nx_expense/core/layout/layout.dart';
import 'package:nx_expense/core/theme/app_theme.dart';
import 'package:nx_expense/data/providers.dart';
import 'package:nx_expense/data/schema/kgql_schema_helpers.dart';
import 'package:nx_expense/domain/expense/model_names.dart';
import 'package:nx_expense/domain/expense/related_model.dart';
import 'package:nx_expense/domain/schema/model_type_view.dart';
import 'package:nx_expense/domain/transfer/transfer.dart';
import 'package:nx_expense/features/desktop/desktop_nav.dart';
import 'package:nx_expense/features/desktop/panel_chrome.dart';
import 'package:nx_expense/features/teller/widgets/teller_detail_readonly_section.dart';
/// Read-only transfer detail (amount, date, title, description, attributes, relations).
class TransferDetailScreen extends ConsumerWidget {
  const TransferDetailScreen({super.key, required this.transferId});

  final int transferId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(transferDetailProvider(transferId));
    final schemaAsync = ref.watch(transferSchemaViewProvider);

    return schemaAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (schema) {
        return async.when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(
            appBar: AppBar(),
            body: Center(child: SelectableText('$e')),
          ),
          data: (transfer) {
            if (transfer == null) {
              return Scaffold(
                appBar: AppBar(),
                body: const Center(child: Text('Transfer not found')),
              );
            }
            final amountKey = primaryNumberAttributeKey(schema);
            num? headerAmount;
            if (amountKey != null) {
              final v = attributeValue(transfer, amountKey);
              if (v is num) headerAmount = v;
              if (v is String) headerAmount = num.tryParse(v);
            }
            final dateHeader = transferCellDateLabel(transfer);

            final listBody = ListView(
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
                            dateHeader,
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
                ..._transferDetailSections(context, ref, transfer, schema),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: RefLayout.px5),
                  child: TellerDetailReadonlySection(modelId: transferId),
                ),
              ],
            );

            final title = transferDisplayTitle(transfer);

            if (isDesktopLayout(context)) {
              return PanelChrome(
                title: title,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.slate400, size: 22),
                  onPressed: () => navTransferDetailBack(context, ref, transferId),
                ),
                actions: [
                  IconButton(
                    tooltip: 'Edit transfer',
                    icon: const Icon(Icons.edit_outlined, color: AppColors.slate400, size: 22),
                    onPressed: () => context.push('/transfer/form/$transferId'),
                  ),
                ],
                body: listBody,
              );
            }

            return Scaffold(
              backgroundColor: Colors.white,
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.slate400, size: 22),
                  onPressed: () => navTransferDetailBack(context, ref, transferId),
                ),
                actions: [
                  IconButton(
                    tooltip: 'Edit transfer',
                    icon: const Icon(Icons.edit_outlined, color: AppColors.slate400, size: 22),
                    onPressed: () => context.push('/transfer/form/$transferId'),
                  ),
                ],
                centerTitle: true,
                title: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: refAppBarTitleBase(),
                ),
                bottom: const PreferredSize(
                  preferredSize: Size.fromHeight(1),
                  child: Divider(height: 1, color: AppColors.slate100),
                ),
              ),
              body: listBody,
            );
          },
        );
      },
    );
  }
}

/// Same layout as [ExpenseDetailScreen]: description, id, attributes (non-amount),
/// relations, linked transfers.
List<Widget> _transferDetailSections(
  BuildContext context,
  WidgetRef ref,
  Transfer model,
  ModelTypeView schema,
) {
  final out = <Widget>[];

  final hasDescription =
      model.description != null && model.description!.isNotEmpty;

  if (hasDescription) {
    out.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(RefLayout.px5, 24, RefLayout.px5, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
          ],
        ),
      ),
    );
  }

  out.add(
    Padding(
      padding: EdgeInsets.fromLTRB(
        RefLayout.px5,
        hasDescription ? 32 : 24,
        RefLayout.px5,
        32,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
          border: Border.all(color: AppColors.slate100),
          boxShadow: refCardShadow,
        ),
        child: _TransferAttrRow(
          label: 'Id',
          value: '${model.id}',
          showDivider: false,
        ),
      ),
    ),
  );

  final amountKey = primaryNumberAttributeKey(schema);
  final attrDefs = schema.attributes
      .where((a) => a.key != null && a.key != amountKey)
      .toList();

  if (attrDefs.isNotEmpty) {
    out.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(RefLayout.px5, 0, RefLayout.px5, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Attributes', style: refSectionTitle(context)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
                border: Border.all(color: AppColors.slate100),
                boxShadow: refCardShadow,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < attrDefs.length; i++)
                    _TransferAttrRow(
                      label: formatAttributeLabel(attrDefs[i].key!),
                      value: _formatTransferDetailAttr(
                        model,
                        attrDefs[i].key!,
                        attrDefs[i].valueType,
                      ),
                      showDivider: i < attrDefs.length - 1,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  if (model.relations != null && model.relations!.isNotEmpty) {
    for (final e in model.relations!.entries) {
      if (e.key == kTransferModelTypeName) continue;
      final list = dedupeModelsById(e.value);
      if (list.isEmpty) continue;
      out.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(RefLayout.px5, 24, RefLayout.px5, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(formatAttributeLabel(e.key), style: refSectionTitle(context)),
              const SizedBox(height: 12),
              for (final relM in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _transferRelationRow(context, ref, e.key, relM),
                ),
            ],
          ),
        ),
      );
    }
  }

  final transferLinks = model.relations?[kTransferModelTypeName];
  if (transferLinks != null && dedupeModelsById(transferLinks).isNotEmpty) {
    final list = dedupeModelsById(transferLinks);
    out.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(RefLayout.px5, 24, RefLayout.px5, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Transfer', style: refSectionTitle(context)),
            const SizedBox(height: 12),
            for (final relM in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _transferLinkedTransferCell(context, ref, relM),
              ),
          ],
        ),
      ),
    );
  }

  return out;
}

String _formatTransferDetailAttr(Transfer model, String key, String? valueType) {
  final v = attributeValue(model, key);
  return formatDisplayAttributeValue(v, valueType);
}

class _TransferAttrRow extends StatelessWidget {
  const _TransferAttrRow({
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

Widget _transferRelationRow(
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
              const Icon(Icons.chevron_right, color: AppColors.slate300, size: 22),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _transferLinkedTransferCell(
  BuildContext context,
  WidgetRef ref,
  RelatedModel relM,
) {
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
