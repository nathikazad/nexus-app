import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nx_db/kgql.dart';

import 'package:nx_expense/core/formatting/format.dart';
import 'package:nx_expense/core/layout/layout.dart';
import 'package:nx_expense/core/theme/app_theme.dart';
import 'package:nx_expense/data/providers.dart';
import 'package:nx_expense/data/schema/kgql_schema_helpers.dart';
import 'package:nx_expense/domain/expense/model_names.dart';
import 'package:nx_expense/domain/order/order.dart';

class ExpenseOrderLinksFormSection extends ConsumerStatefulWidget {
  const ExpenseOrderLinksFormSection({super.key, required this.expenseId});

  final int expenseId;

  @override
  ConsumerState<ExpenseOrderLinksFormSection> createState() =>
      _ExpenseOrderLinksFormSectionState();
}

class _ExpenseOrderLinksFormSectionState
    extends ConsumerState<ExpenseOrderLinksFormSection> {
  bool _busy = false;

  Future<void> _remove(int relationId) async {
    setState(() => _busy = true);
    try {
      final client = ref.read(expenseGraphqlClientProvider);
      await setKgqlModel(
        client,
        SetModelRequest(
          id: widget.expenseId,
          relations: [ModelRelation(id: relationId, delete: true)],
        ),
      );
      ref.invalidate(expenseDetailProvider(widget.expenseId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenseAsync = ref.watch(expenseDetailProvider(widget.expenseId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('Orders', style: refSectionTitle(context))),
            if (_busy)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.teal600,
                ),
              )
            else
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () =>
                      context.push('/expense/${widget.expenseId}/link-order'),
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.add_rounded,
                      size: 22,
                      color: AppColors.teal600,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        expenseAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(
            'Could not load order links: $e',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate500),
          ),
          data: (expense) {
            final links = expense?.relations?[kOrderModelTypeName] ?? const [];
            final edgeByModelId = {
              for (final rel in expense?.relationsList ?? const [])
                if (rel.modelType == kOrderModelTypeName)
                  rel.modelId: rel.relationId,
            };
            final unique = dedupeModelsById(links);
            if (unique.isEmpty) {
              return Text(
                'No linked orders.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.slate400,
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final link in unique)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _LinkedOrderRow(
                      orderId: link.id,
                      fallbackName: link.name,
                      onRemove: edgeByModelId[link.id] == null || _busy
                          ? null
                          : () => _remove(edgeByModelId[link.id]!),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _LinkedOrderRow extends ConsumerWidget {
  const _LinkedOrderRow({
    required this.orderId,
    required this.fallbackName,
    required this.onRemove,
  });

  final int orderId;
  final String fallbackName;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(orderDetailProvider(orderId));
    return async.maybeWhen(
      data: (order) => _OrderLinkCard(
        title: order?.orderNumber ?? fallbackName,
        subtitle: _orderSubtitle(order),
        total: order?.total,
        onRemove: onRemove,
      ),
      orElse: () => _OrderLinkCard(
        title: fallbackName,
        subtitle: null,
        total: null,
        onRemove: onRemove,
      ),
    );
  }

  String? _orderSubtitle(Order? order) {
    if (order == null) return null;
    final company = order.companyName ?? 'Unknown';
    return '$company · ${formatModelDate(order.orderDate)}';
  }
}

class _OrderLinkCard extends StatelessWidget {
  const _OrderLinkCard({
    required this.title,
    required this.subtitle,
    required this.total,
    required this.onRemove,
  });

  final String title;
  final String? subtitle;
  final num? total;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
        border: Border.all(color: AppColors.slate100),
        boxShadow: refCardShadow,
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate900,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.slate400,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  formatMoney(total),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.teal600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: const Icon(
              Icons.close_rounded,
              size: 20,
              color: AppColors.slate400,
            ),
            onPressed: onRemove,
            tooltip: 'Unlink',
          ),
        ],
      ),
    );
  }
}
