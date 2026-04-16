import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nx_db/nx_db.dart';
import 'package:nx_db/src/models/requests/SetModelRequest.dart' as sm;

import '../../app_theme.dart';
import '../../data/expense_timeline_api.dart';
import '../../data/teller_timeline_api.dart';
import '../../layout.dart';
import '../../desktop/desktop_nav.dart';
import '../../providers/expense_providers.dart';
import '../../providers/teller_providers.dart';
import '../../util/expense_schema.dart';
import '../../widgets/date_attribute_picker_field.dart';
import '../../widgets/expense_app_end_drawer.dart';

/// Minimal new transfer + link to [row].
class TellerTransferQuickCreateScreen extends ConsumerStatefulWidget {
  const TellerTransferQuickCreateScreen({
    super.key,
    required this.row,
    this.embedded = false,
  });

  final TellerTransactionRow row;

  /// Desktop Teller panel 3: no app bar / drawer; close via [closeTellerPanel3].
  final bool embedded;

  @override
  ConsumerState<TellerTransferQuickCreateScreen> createState() =>
      _TellerTransferQuickCreateScreenState();
}

class _TellerTransferQuickCreateScreenState
    extends ConsumerState<TellerTransferQuickCreateScreen> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _date = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final p = widget.row.payload;
    _name.text = tellerTransactionTitleLine(p);
    final rawAmt = p['amount'];
    if (rawAmt != null) {
      final n = num.tryParse(rawAmt.toString().trim());
      if (n != null) _amount.text = n.toString();
    }
    final dateStr = p['date']?.toString();
    if (dateStr != null && dateStr.isNotEmpty) {
      _date.text = dateStr;
    } else {
      final d = widget.row.time.toLocal();
      _date.text =
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _date.dispose();
    super.dispose();
  }

  Future<void> _submit(ModelType schema) async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }
    final amountKey = primaryNumberAttributeKey(schema);
    if (amountKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transfer schema has no amount field')),
      );
      return;
    }
    final amt = num.tryParse(_amount.text.trim());
    if (amt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }
    final dateStr = _date.text.trim();
    if (dateStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Date is required (YYYY-MM-DD)')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final attrs = <sm.ModelAttribute>[
        sm.ModelAttribute(key: amountKey, value: amt),
      ];
      String? dateKey;
      for (final ad in schema.attributes ?? const <AttributeDefinition>[]) {
        final k = ad.key;
        if (k != null && k.toLowerCase() == 'date') {
          dateKey = k;
          break;
        }
      }
      if (dateKey != null) {
        attrs.add(sm.ModelAttribute(key: dateKey, value: dateStr));
      }
      for (final ad in schema.attributes ?? const <AttributeDefinition>[]) {
        final k = ad.key;
        if (k == null) continue;
        if (k == amountKey || k == dateKey) continue;
        final vt = ad.valueType ?? 'string';
        if (vt == 'string' && k.toLowerCase() == 'to') {
          attrs.add(sm.ModelAttribute(key: k, value: 'Cash'));
          break;
        }
      }

      final req = sm.SetModelRequest(
        modelType: kTransferModelTypeName,
        name: _name.text.trim(),
        attributes: attrs,
      );
      final id = await createModel(ref.container, req);
      final client = ref.read(graphqlClientProvider);
      await linkModelToTimelineEvent(
        client,
        modelId: id,
        eventTime: widget.row.time,
        eventId: widget.row.eventId,
      );
      ref.invalidate(transferListProvider);
      ref.invalidate(transferListForUiProvider);
      ref.invalidate(transferListSummaryProvider);
      if (!mounted) return;
      if (isDesktopLayout(context)) {
        await refreshTellerSelectionAfterLinkChange(ref, widget.row.eventId);
      } else {
        ref.invalidate(tellerTransactionsProvider);
      }
      if (!mounted) return;
      if (widget.embedded) {
        closeTellerPanel3(ref);
      } else {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final schemaAsync = ref.watch(transferSchemaProvider);

    return schemaAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (schema) {
        return Scaffold(
          backgroundColor: Colors.white,
          endDrawer: widget.embedded ? null : const ExpenseAppEndDrawer(),
          appBar: widget.embedded
              ? null
              : AppBar(
                  backgroundColor: Colors.white,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.slate400, size: 22),
                    onPressed: _loading ? null : () => Navigator.of(context).pop(),
                  ),
                  centerTitle: true,
                  title: Text(
                    'New transfer',
                    style: refAppBarTitleBase(),
                  ),
                  bottom: const PreferredSize(
                    preferredSize: Size.fromHeight(1),
                    child: Divider(height: 1, color: AppColors.slate100),
                  ),
                ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ColoredBox(
                        color: const Color(0x4DF8FAFC),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(RefLayout.px5, 20, RefLayout.px5, 120),
                          children: [
                            Text(
                              'Creates a transfer and links it to this Teller transaction.',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                height: 1.5,
                                color: AppColors.slate500,
                              ),
                            ),
                            const SizedBox(height: 24),
                            _quickFieldLabel('Name'),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _name,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.slate900,
                              ),
                              decoration: _deco('E.g., Cash withdrawal'),
                            ),
                            const SizedBox(height: 16),
                            _quickFieldLabel('Amount'),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _amount,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.slate900,
                              ),
                              decoration: _deco('0.00').copyWith(
                                prefixText: r'$ ',
                                prefixStyle: GoogleFonts.inter(
                                  color: AppColors.slate400,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            DateAttributePickerField(
                              label: 'Date',
                              controller: _date,
                              decoration: _deco(''),
                              onPicked: () => setState(() {}),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(RefLayout.px5, 12, RefLayout.px5, 28),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(top: BorderSide(color: AppColors.slate100)),
                      ),
                      child: FilledButton(
                        onPressed: () => _submit(schema),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.teal600,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Create & link',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  InputDecoration _deco(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.slate200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.teal600, width: 1.5),
      ),
    );
  }
}

Widget _quickFieldLabel(String text) {
  return Text(
    text.toUpperCase(),
    style: GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AppColors.slate500,
      letterSpacing: 1.2,
    ),
  );
}
