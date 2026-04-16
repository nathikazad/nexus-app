import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nx_db/nx_db.dart';

import '../app_theme.dart';
import '../data/expense_timeline_api.dart';
import '../layout.dart';
import '../providers/expense_providers.dart';
import '../providers/teller_providers.dart';
import '../util/format.dart';
import '../util/teller_display.dart';

/// Linked Teller transactions + add via full-screen picker ([linkPickerRoute]).
class ModelTellerLinksFormSection extends ConsumerStatefulWidget {
  const ModelTellerLinksFormSection({
    super.key,
    required this.modelId,
    required this.linkPickerRoute,
  });

  final int modelId;

  /// Registered route, e.g. `/expense/12/link-teller` or `/transfer/12/link-teller`.
  final String linkPickerRoute;

  @override
  ConsumerState<ModelTellerLinksFormSection> createState() =>
      _ModelTellerLinksFormSectionState();
}

class _ModelTellerLinksFormSectionState extends ConsumerState<ModelTellerLinksFormSection> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() fn) async {
    setState(() => _busy = true);
    try {
      await fn();
      if (!mounted) return;
      ref.invalidate(expenseTimelineLinksProvider(widget.modelId));
      ref.invalidate(tellerTransactionsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onRemove(ExpenseTellerLink link) async {
    final client = ref.read(graphqlClientProvider);
    await _run(() => deleteExpenseTimelineLink(client, link.linkId));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(expenseTimelineLinksProvider(widget.modelId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: Text('Teller', style: refSectionTitle(context))),
            if (_busy)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.teal600),
              )
            else
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _busy ? null : () => context.push(widget.linkPickerRoute),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
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
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(
            'Could not load Teller links: $e',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate500),
          ),
          data: (links) {
            final tellerLinks = links.where((l) => l.isTellerTimelineEvent).toList();
            if (tellerLinks.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'No linked Teller transactions.',
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.slate400),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final link in tellerLinks)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
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
                            child: Builder(
                              builder: (context) {
                                final amt = num.tryParse(
                                  link.payload['amount']?.toString().trim() ?? '',
                                );
                                return Column(
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
                                    const SizedBox(height: 4),
                                    Text(
                                      tellerDetailDateLabel(link.payload, link.eventTime),
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
                                );
                              },
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            icon: Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: AppColors.slate400,
                            ),
                            onPressed: _busy ? null : () => _onRemove(link),
                            tooltip: 'Unlink',
                          ),
                        ],
                      ),
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

/// Expense form: [ModelTellerLinksFormSection] with `/expense/:id/link-teller`.
class ExpenseTellerLinksFormSection extends StatelessWidget {
  const ExpenseTellerLinksFormSection({super.key, required this.expenseId});

  final int expenseId;

  @override
  Widget build(BuildContext context) {
    return ModelTellerLinksFormSection(
      modelId: expenseId,
      linkPickerRoute: '/expense/$expenseId/link-teller',
    );
  }
}
