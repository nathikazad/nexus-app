import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/motion/expense_motion.dart';
import '../images/upload_expense_receipt.dart';
import 'expense_form_page.dart';

/// A compact fan-out: two taps from the expense list to either entry flow.
class ExpenseQuickAdd extends ConsumerStatefulWidget {
  const ExpenseQuickAdd({super.key});
  @override
  ConsumerState<ExpenseQuickAdd> createState() => _ExpenseQuickAddState();
}

class _ExpenseQuickAddState extends ConsumerState<ExpenseQuickAdd> {
  bool _open = false;
  bool _uploading = false;

  Future<void> _photo() async {
    setState(() {
      _open = false;
    });
    try {
      await uploadExpenseReceipt(
        context,
        ref,
        onBusyChanged: (busy) {
          if (mounted) setState(() => _uploading = busy);
        },
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = ExpenseMotion.reduced(context)
        ? Duration.zero
        : ExpenseMotion.enter;
    return TapRegion(
      onTapOutside: (_) {
        if (_open) setState(() => _open = false);
      },
      child: PopScope(
        canPop: !_open,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _open) setState(() => _open = false);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AnimatedSize(
              duration: duration,
              curve: Curves.easeOutCubic,
              alignment: Alignment.bottomRight,
              child: _open
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          FloatingActionButton.extended(
                            heroTag: 'quick-add-photo',
                            onPressed: _photo,
                            icon: const Icon(
                              Icons.add_photo_alternate_outlined,
                            ),
                            label: const Text('Photo'),
                          ),
                          const SizedBox(height: 12),
                          FloatingActionButton.extended(
                            heroTag: 'quick-add-expense',
                            onPressed: () {
                              setState(() => _open = false);
                              showAddExpenseModal(context);
                            },
                            icon: const Icon(
                              Icons.account_balance_wallet_outlined,
                            ),
                            label: const Text('Expense'),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            FloatingActionButton(
              heroTag: 'quick-add',
              tooltip: _uploading
                  ? 'Uploading photo'
                  : _open
                  ? 'Close add menu'
                  : 'Add expense or photo',
              onPressed: _uploading
                  ? null
                  : () => setState(() => _open = !_open),
              child: _uploading
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : AnimatedRotation(
                      turns: _open ? .125 : 0,
                      duration: duration,
                      child: const Icon(Icons.add),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
