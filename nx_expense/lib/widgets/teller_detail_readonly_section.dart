import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_theme.dart';
import '../desktop/desktop_nav.dart';
import '../layout.dart';
import '../providers/expense_providers.dart';
import '../screens/teller/teller_transaction_detail_screen.dart';
import '../util/format.dart';
import '../util/teller_display.dart';

/// Read-only Teller timeline links for any model (Expense, Transfer, …).
class TellerDetailReadonlySection extends ConsumerWidget {
  const TellerDetailReadonlySection({super.key, required this.modelId});

  final int modelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tellerAsync = ref.watch(expenseTimelineLinksProvider(modelId));

    return Padding(
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
          final tellerLinks = links.where((l) => l.isTellerTimelineEvent).toList();
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
    );
  }
}
