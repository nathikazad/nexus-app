import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nx_expense/core/layout/layout.dart';
import 'package:nx_expense/core/theme/app_theme.dart';
import 'package:nx_expense/data/providers.dart';
import 'package:nx_expense/data/teller/expense_timeline_api.dart';
import 'package:nx_expense/data/teller/teller_timeline_api.dart';
import 'package:nx_expense/domain/expense/model_names.dart';
import 'package:nx_expense/features/desktop/desktop_nav.dart';
import 'package:nx_expense/features/desktop/panel_chrome.dart';

/// Full-screen Teller transaction detail (read-only).
class TellerTransactionDetailScreen extends ConsumerWidget {
  const TellerTransactionDetailScreen({super.key, required this.row});

  final TellerTransactionRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = row.payload;
    final details = p['details'];
    Map<String, dynamic>? dmap;
    if (details is Map<String, dynamic>) {
      dmap = details;
    } else if (details is Map) {
      dmap = Map<String, dynamic>.from(details);
    }
    final processing = dmap?['processing_status']?.toString();
    final cpName = _counterpartyNameFromPayload(p);

    final listBody = ListView(
      padding: EdgeInsets.fromLTRB(
        RefLayout.px5,
        16,
        RefLayout.px5,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        _DetailRow(label: 'Date', value: _payloadDate(p) ?? row.time.toLocal().toIso8601String().split('T').first),
        _DetailRow(label: 'deleted', value: tellerPayloadIsDeleted(p) ? 'true' : 'false'),
        _DetailRow(label: 'Description', value: (p['description'] as String?)?.trim() ?? '—'),
        _DetailRow(label: 'Type', value: p['type']?.toString() ?? '—'),
        _DetailRow(label: 'Status', value: p['status']?.toString() ?? '—'),
        _DetailRow(label: 'Id', value: p['id']?.toString() ?? '—'),
        _DetailRow(label: 'processing_status', value: processing ?? '—'),
        _DetailRow(label: 'counterparty.name', value: cpName ?? '—'),
        if (row.linkedModels.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Linked', style: refSectionTitle(context)),
          const SizedBox(height: 12),
          ...row.linkedModels.map(
            (m) => _LinkedModelTile(row: row, model: m),
          ),
        ],
        const SizedBox(height: 20),
        _TellerLinkActions(row: row),
      ],
    );

    if (isDesktopLayout(context)) {
      return PanelChrome(
        title: 'Teller transaction',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.slate400, size: 22),
          onPressed: () => navTellerTxDetailBack(context, ref, row),
        ),
        body: listBody,
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.slate400, size: 22),
          onPressed: () => navTellerTxDetailBack(context, ref, row),
        ),
        centerTitle: true,
        title: Text(
          'Teller transaction',
          style: refAppBarTitleBase(),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.slate100),
        ),
      ),
      body: listBody,
    );
  }

  static String? _counterpartyNameFromPayload(Map<String, dynamic> payload) {
    final details = payload['details'];
    if (details is! Map) return null;
    final cp = details['counterparty'];
    if (cp is! Map) return null;
    final name = cp['name'];
    if (name == null) return null;
    final s = name.toString().trim();
    return s.isEmpty ? null : s;
  }

  static String? _payloadDate(Map<String, dynamic> p) {
    final raw = p['date'];
    if (raw == null) return null;
    return raw.toString();
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: AppColors.slate400,
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.slate900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TellerLinkActions extends ConsumerWidget {
  const _TellerLinkActions({required this.row});

  final TellerTransactionRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Link', style: refSectionTitle(context)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
            border: Border.all(color: AppColors.slate100),
            boxShadow: refCardShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
            child: Column(
              children: [
                _LinkActionTile(
                  icon: Icons.link_rounded,
                  iconColor: AppColors.slate500,
                  title: 'Link expense',
                  subtitle: 'Choose an existing expense',
                  onTap: () {
                    if (isDesktopLayout(context)) {
                      ref.read(tellerPanel3Provider.notifier).state =
                          TellerPanel3State.linkExpensePicker(row);
                    } else {
                      context.push('/teller/link-expense', extra: row);
                    }
                  },
                  showDividerBelow: true,
                ),
                _LinkActionTile(
                  icon: Icons.link_rounded,
                  iconColor: AppColors.slate500,
                  title: 'Link transfer',
                  subtitle: 'Choose an existing transfer',
                  onTap: () {
                    if (isDesktopLayout(context)) {
                      ref.read(tellerPanel3Provider.notifier).state =
                          TellerPanel3State.linkTransferPicker(row);
                    } else {
                      context.push('/teller/link-transfer', extra: row);
                    }
                  },
                  showDividerBelow: true,
                ),
                _LinkActionTile(
                  icon: Icons.add_rounded,
                  iconColor: AppColors.teal600,
                  title: 'New expense',
                  subtitle: 'Create and link',
                  onTap: () {
                    if (isDesktopLayout(context)) {
                      ref.read(tellerPanel3Provider.notifier).state =
                          TellerPanel3State.newExpenseForm(row);
                    } else {
                      final p = row.payload;
                      final amt = num.tryParse(p['amount']?.toString().trim() ?? '');
                      final q = <String, String>{
                        'tellerEventId': row.eventId,
                        'tellerEventTime': row.time.toUtc().toIso8601String(),
                        'prefillName': tellerTransactionTitleLine(p),
                      };
                      if (amt != null) q['prefillAmount'] = amt.toString();
                      final uri = Uri(path: '/expense/form', queryParameters: q);
                      context.push(uri.toString());
                    }
                  },
                  showDividerBelow: true,
                ),
                _LinkActionTile(
                  icon: Icons.add_rounded,
                  iconColor: AppColors.teal600,
                  title: 'New transfer',
                  subtitle: 'Create and link',
                  onTap: () {
                    if (isDesktopLayout(context)) {
                      ref.read(tellerPanel3Provider.notifier).state =
                          TellerPanel3State.newTransferCreate(row);
                    } else {
                      context.push('/teller/transfer-create', extra: row);
                    }
                  },
                  showDividerBelow: false,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LinkActionTile extends StatelessWidget {
  const _LinkActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.showDividerBelow,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showDividerBelow;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 22, color: iconColor),
                  const SizedBox(width: 12),
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
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.slate400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: AppColors.slate400, size: 22),
                ],
              ),
            ),
          ),
        ),
        if (showDividerBelow)
          const Divider(height: 1, thickness: 1, color: AppColors.slate100),
      ],
    );
  }
}

class _LinkedModelTile extends ConsumerWidget {
  const _LinkedModelTile({required this.row, required this.model});

  final TellerTransactionRow row;
  final LinkedTellerModel model;

  Future<void> _unlink(BuildContext context, WidgetRef ref) async {
    final id = model.linkId;
    if (id == null) return;
    final client = ref.read(expenseGraphqlClientProvider);
    try {
      await deleteExpenseTimelineLink(client, id);
      if (!context.mounted) return;
      ref.invalidate(tellerTransactionsProvider);
      if (isDesktopLayout(context)) {
        await refreshTellerSelectionAfterLinkChange(ref, row.eventId);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unlinked')),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpense = model.modelTypeName == kExpenseModelTypeName;
    final isTransfer = model.modelTypeName == kTransferModelTypeName;
    final tappable = isExpense || isTransfer;
    final subtitle = '${model.modelTypeName} · #${model.id}';

    final card = Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
        border: Border.all(color: AppColors.slate100),
        boxShadow: refCardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isExpense ? Icons.receipt_long_outlined : Icons.swap_horiz_rounded,
              color: AppColors.slate500,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: tappable
                  ? Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          if (isExpense) {
                            navToExpenseFromTellerLink(context, ref, model.id);
                          } else {
                            navToTransferFromTellerLink(context, ref, model.id);
                          }
                        },
                        borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                model.name,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.slate900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.slate400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          model.name,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.slate900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.slate400,
                          ),
                        ),
                      ],
                    ),
            ),
            if (tappable)
              Icon(Icons.chevron_right_rounded, color: AppColors.slate400, size: 22),
            if (model.linkId != null)
              IconButton(
                tooltip: 'Unlink',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: AppColors.slate400,
                ),
                onPressed: () => _unlink(context, ref),
              ),
          ],
        ),
      ),
    );

    return card;
  }
}
