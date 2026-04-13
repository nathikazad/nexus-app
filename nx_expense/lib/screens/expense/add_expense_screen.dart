import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nx_db/nx_db.dart';
import 'package:nx_db/src/models/requests/SetModelRequest.dart' as sm;

import '../../app_theme.dart';
import '../../util/expense_schema.dart';
import '../../providers/expense_providers.dart';
import '../../layout.dart';

/// Centered modal: name + description only, then [ExpenseFormScreen] for the rest.
void showAddExpenseModal(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    builder: (ctx) => const _AddExpenseModal(),
  );
}

class _AddExpenseModal extends ConsumerStatefulWidget {
  const _AddExpenseModal();

  @override
  ConsumerState<_AddExpenseModal> createState() => _AddExpenseModalState();
}

class _AddExpenseModalState extends ConsumerState<_AddExpenseModal> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RefLayout.rounded2xl)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'New Expense',
                      style: refAppBarTitleBase(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.slate400, size: 22),
                    onPressed: _loading ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                _refLabel('Name *'),
                const SizedBox(height: 6),
                TextField(
                  controller: _name,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                  decoration: _refInputDeco(hint: 'E.g., Groceries'),
                  textCapitalization: TextCapitalization.sentences,
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                _refLabel('Description'),
                const SizedBox(height: 6),
                TextField(
                  controller: _desc,
                  maxLines: 3,
                  style: GoogleFonts.inter(fontSize: 14),
                  decoration: _refInputDeco(hint: 'Add details...'),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _submit,
                  child: Text(
                    'Create',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _refLabel(String text) {
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

  InputDecoration _refInputDeco({required String hint}) {
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
    );
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final schema = await ref.read(expenseSchemaProvider.future);
      final amountKey = primaryNumberAttributeKey(schema);
      final attrs = <sm.ModelAttribute>[];
      if (amountKey != null) {
        attrs.add(sm.ModelAttribute(key: amountKey, value: 0));
      }

      final req = sm.SetModelRequest(
        modelType: kExpenseModelTypeName,
        name: _name.text.trim(),
        description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        attributes: attrs.isEmpty ? null : attrs,
      );
      final id = await createModel(ref.container, req);
      ref.invalidate(expenseListForUiProvider);
      ref.invalidate(expenseSummaryProvider);
      if (!mounted) return;
      final router = GoRouter.of(context);
      Navigator.of(context).pop();
      router.push('/expense/form/$id');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
