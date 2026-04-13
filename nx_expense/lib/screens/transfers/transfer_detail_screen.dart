import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app_theme.dart';
import '../../desktop/desktop_nav.dart';
import '../../desktop/panel_chrome.dart';
import '../../layout.dart';
import '../../providers/expense_providers.dart';
import '../../util/expense_schema.dart';
import '../../util/format.dart';

/// Read-only transfer detail (amount, date, title, description).
class TransferDetailScreen extends ConsumerWidget {
  const TransferDetailScreen({super.key, required this.transferId});

  final int transferId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(transferDetailProvider(transferId));
    final schemaAsync = ref.watch(transferSchemaProvider);

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
          data: (model) {
            if (model == null) {
              return Scaffold(
                appBar: AppBar(),
                body: const Center(child: Text('Transfer not found')),
              );
            }
            final amountKey = primaryNumberAttributeKey(schema);
            num? headerAmount;
            if (amountKey != null) {
              final v = attributeValue(model, amountKey);
              if (v is num) headerAmount = v;
              if (v is String) headerAmount = num.tryParse(v);
            }
            final dateHeader = transferCellDateLabel(model);

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
                if (model.description != null && model.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(RefLayout.px5),
                    child: Text(
                      model.description!,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.6,
                        color: AppColors.slate700,
                      ),
                    ),
                  ),
              ],
            );

            final title = transferDisplayTitle(model);

            if (isDesktopLayout(context)) {
              return PanelChrome(
                title: title,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.slate400, size: 22),
                  onPressed: () => navTransferDetailBack(context, ref, transferId),
                ),
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
