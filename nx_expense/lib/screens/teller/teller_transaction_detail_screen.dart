import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app_theme.dart';
import '../../data/teller_timeline_api.dart';
import '../../desktop/desktop_nav.dart';
import '../../desktop/panel_chrome.dart';
import '../../layout.dart';
import '../../util/expense_schema.dart';

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
        _DetailRow(label: 'Description', value: (p['description'] as String?)?.trim() ?? '—'),
        _DetailRow(label: 'Type', value: p['type']?.toString() ?? '—'),
        _DetailRow(label: 'Status', value: p['status']?.toString() ?? '—'),
        _DetailRow(label: 'Id', value: p['id']?.toString() ?? '—'),
        _DetailRow(label: 'processing_status', value: processing ?? '—'),
        _DetailRow(label: 'counterparty.name', value: cpName ?? '—'),
        if (row.linkedModels.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Linked',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.slate900,
            ),
          ),
          const SizedBox(height: 8),
          ...row.linkedModels.map((m) => _LinkedModelTile(model: m)),
        ],
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

class _LinkedModelTile extends ConsumerWidget {
  const _LinkedModelTile({required this.model});

  final LinkedTellerModel model;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpense = model.modelTypeName == kExpenseModelTypeName;
    final subtitle = '${model.modelTypeName} · #${model.id}';

    final child = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
        border: Border.all(color: AppColors.slate100),
        boxShadow: refCardShadow,
      ),
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
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate500),
                ),
              ],
            ),
          ),
          if (isExpense)
            Icon(Icons.chevron_right, color: AppColors.slate400, size: 22),
        ],
      ),
    );

    if (!isExpense) {
      return child;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => navToExpenseFromTellerLink(context, ref, model.id),
        borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
        child: child,
      ),
    );
  }
}
