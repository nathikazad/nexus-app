import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

import 'package:nx_expense/data/teller/teller_timeline_api.dart';
import 'package:nx_expense/data/providers.dart';

const double kDesktopBreakpoint = 1100;

bool isDesktopLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;

/// Selected tab in [DesktopShell] (0–4): Expenses, Stats, Transfers, Teller, Tags.
final desktopShellTabIndexProvider = StateProvider<int>((ref) => 0);

// --- Expenses tab ---
final selectedExpenseIdProvider = StateProvider<int?>((ref) => null);

/// Panel 3 is a stack: bottom = first drill (e.g. relation list), top = deepest view.
/// Empty = blank third column.
final panel3StackProvider = StateProvider<List<Panel3State>>((ref) => const []);

// --- Transfers tab ---
final selectedTransferIdProvider = StateProvider<int?>((ref) => null);

// --- Teller tab ---
final selectedTellerRowProvider = StateProvider<TellerTransactionRow?>(
  (ref) => null,
);

/// Teller tab third column: detail, link pickers, or create flows (desktop wide layout).
final tellerPanel3Provider = StateProvider<TellerPanel3State?>((ref) => null);

@immutable
class TellerPanel3State {
  const TellerPanel3State._({
    required this.kind,
    this.detailId,
    this.tellerRow,
  });

  const TellerPanel3State.expense(int id)
    : this._(kind: TellerPanel3Kind.expense, detailId: id);

  const TellerPanel3State.transfer(int id)
    : this._(kind: TellerPanel3Kind.transfer, detailId: id);

  const TellerPanel3State.linkExpensePicker(TellerTransactionRow row)
    : this._(kind: TellerPanel3Kind.linkExpensePicker, tellerRow: row);

  const TellerPanel3State.linkTransferPicker(TellerTransactionRow row)
    : this._(kind: TellerPanel3Kind.linkTransferPicker, tellerRow: row);

  const TellerPanel3State.newExpenseForm(TellerTransactionRow row)
    : this._(kind: TellerPanel3Kind.newExpenseForm, tellerRow: row);

  const TellerPanel3State.newTransferCreate(TellerTransactionRow row)
    : this._(kind: TellerPanel3Kind.newTransferCreate, tellerRow: row);

  final TellerPanel3Kind kind;

  /// [TellerPanel3Kind.expense] / [TellerPanel3Kind.transfer] detail id.
  final int? detailId;

  /// Row context for pickers / create flows.
  final TellerTransactionRow? tellerRow;
}

enum TellerPanel3Kind {
  expense,
  transfer,
  linkExpensePicker,
  linkTransferPicker,
  newExpenseForm,
  newTransferCreate,
}

void closeTellerPanel3(WidgetRef ref) {
  ref.read(tellerPanel3Provider.notifier).state = null;
}

/// After linking/unlinking a Teller row, reload the list and update the desktop shell selection.
Future<void> refreshTellerSelectionAfterLinkChange(
  WidgetRef ref,
  String eventId,
) async {
  ref.invalidate(tellerTransactionsProvider);
  final rows = await ref.read(tellerTransactionsProvider.future);
  for (final r in rows) {
    if (r.eventId == eventId) {
      ref.read(selectedTellerRowProvider.notifier).state = r;
      return;
    }
  }
}

// --- Tags tab (desktop two-pane) ---
/// Right panel: create vs edit a tag system; `null` = empty.
final tagSystemsPanelSelectionProvider =
    StateProvider<TagSystemsPanelSelection?>((ref) => null);

@immutable
class TagSystemsPanelSelection {
  const TagSystemsPanelSelection.create() : isCreate = true, editId = null;
  const TagSystemsPanelSelection.edit(int id) : isCreate = false, editId = id;

  final bool isCreate;
  final int? editId;
}

enum Panel3Type {
  none,
  transfer,
  teller,
  tagExpenses,
  relationExpenses,
  expenseDetail,
}

class Panel3State {
  const Panel3State({
    this.type = Panel3Type.none,
    this.id,
    this.label,
    this.secondaryLabel,
    this.tellerRow,
  });

  final Panel3Type type;
  final int? id;
  final String? label;
  final String? secondaryLabel;
  final TellerTransactionRow? tellerRow;
}

void clearPanel3(WidgetRef ref) {
  ref.read(panel3StackProvider.notifier).state = const [];
}

void pushPanel3(WidgetRef ref, Panel3State state) {
  ref.read(panel3StackProvider.notifier).state = [
    ...ref.read(panel3StackProvider),
    state,
  ];
}

/// Replaces the entire panel 3 stack (e.g. new relation or tag drill from expense).
void replacePanel3(WidgetRef ref, Panel3State state) {
  ref.read(panel3StackProvider.notifier).state = [state];
}

void popPanel3(WidgetRef ref) {
  final stack = ref.read(panel3StackProvider);
  if (stack.isEmpty) return;
  if (stack.length == 1) {
    ref.read(panel3StackProvider.notifier).state = const [];
  } else {
    ref.read(panel3StackProvider.notifier).state = stack.sublist(
      0,
      stack.length - 1,
    );
  }
}

void navToExpenseDetail(BuildContext context, WidgetRef ref, int id) {
  if (isDesktopLayout(context)) {
    ref.read(selectedExpenseIdProvider.notifier).state = id;
    clearPanel3(ref);
  } else {
    context.push('/expense/$id');
  }
}

void navToTransferDetail(BuildContext context, WidgetRef ref, int transferId) {
  if (isDesktopLayout(context)) {
    pushPanel3(ref, Panel3State(type: Panel3Type.transfer, id: transferId));
  } else {
    context.push('/transfer/$transferId');
  }
}

void navToRelationExpenses(
  BuildContext context,
  WidgetRef ref, {
  required String relName,
  required int relId,
  required String displayName,
}) {
  if (isDesktopLayout(context)) {
    replacePanel3(
      ref,
      Panel3State(
        type: Panel3Type.relationExpenses,
        id: relId,
        label: relName,
        secondaryLabel: displayName,
      ),
    );
  } else {
    context.push(
      '/expenses/by-relation/${Uri.encodeComponent(relName)}/$relId/${Uri.encodeComponent(displayName)}',
    );
  }
}

void navToTagExpenses(
  BuildContext context,
  WidgetRef ref, {
  required String systemName,
  required String tagNode,
}) {
  if (isDesktopLayout(context)) {
    replacePanel3(
      ref,
      Panel3State(
        type: Panel3Type.tagExpenses,
        label: systemName,
        secondaryLabel: tagNode,
      ),
    );
  } else {
    context.push(
      '/expenses/by-tag/${Uri.encodeComponent(systemName)}/${Uri.encodeComponent(tagNode)}',
    );
  }
}

/// Open an expense inside panel 3 without changing column 2 selection (e.g. from scoped list).
void navToExpenseDetailFromPanel3(
  BuildContext context,
  WidgetRef ref,
  int expenseId,
) {
  if (isDesktopLayout(context)) {
    pushPanel3(ref, Panel3State(type: Panel3Type.expenseDetail, id: expenseId));
  } else {
    context.push('/expense/$expenseId');
  }
}

void navToTransferDetailDirect(
  BuildContext context,
  WidgetRef ref,
  int transferId,
) {
  if (isDesktopLayout(context)) {
    ref.read(selectedTransferIdProvider.notifier).state = transferId;
  } else {
    context.push('/transfer/$transferId');
  }
}

void navAfterExpenseDelete(BuildContext context, WidgetRef ref) {
  if (isDesktopLayout(context)) {
    ref.read(selectedExpenseIdProvider.notifier).state = null;
    clearPanel3(ref);
  } else {
    context.go('/expenses');
  }
}

/// Back from expense detail: pop route on mobile; clear desktop selection on shell,
/// or pop panel 3 stack when this detail is the stacked panel 3 expense.
void navExpenseDetailBack(
  BuildContext context,
  WidgetRef ref, {
  required int expenseId,
}) {
  if (!isDesktopLayout(context)) {
    context.pop();
    return;
  }
  final tp = ref.read(tellerPanel3Provider);
  if (tp != null &&
      tp.kind == TellerPanel3Kind.expense &&
      tp.detailId == expenseId) {
    ref.read(tellerPanel3Provider.notifier).state = null;
    return;
  }
  final stack = ref.read(panel3StackProvider);
  if (stack.isNotEmpty &&
      stack.last.type == Panel3Type.expenseDetail &&
      stack.last.id == expenseId) {
    popPanel3(ref);
    return;
  }
  ref.read(selectedExpenseIdProvider.notifier).state = null;
  clearPanel3(ref);
}

/// Back from transfer detail (embedded or full-screen).
void navTransferDetailBack(
  BuildContext context,
  WidgetRef ref,
  int transferId,
) {
  if (!isDesktopLayout(context)) {
    context.pop();
    return;
  }
  final tp = ref.read(tellerPanel3Provider);
  if (tp != null &&
      tp.kind == TellerPanel3Kind.transfer &&
      tp.detailId == transferId) {
    ref.read(tellerPanel3Provider.notifier).state = null;
    return;
  }
  final stack = ref.read(panel3StackProvider);
  if (stack.isNotEmpty &&
      stack.last.type == Panel3Type.transfer &&
      stack.last.id == transferId) {
    popPanel3(ref);
    return;
  }
  final sel = ref.read(selectedTransferIdProvider);
  if (sel == transferId) {
    ref.read(selectedTransferIdProvider.notifier).state = null;
    return;
  }
  context.pop();
}

void navTellerTxDetailBack(
  BuildContext context,
  WidgetRef ref,
  TellerTransactionRow row,
) {
  if (!isDesktopLayout(context)) {
    context.pop();
    return;
  }
  final stack = ref.read(panel3StackProvider);
  if (stack.isNotEmpty &&
      stack.last.type == Panel3Type.teller &&
      stack.last.tellerRow?.eventId == row.eventId) {
    popPanel3(ref);
    return;
  }
  final sel = ref.read(selectedTellerRowProvider);
  if (sel?.eventId == row.eventId) {
    ref.read(selectedTellerRowProvider.notifier).state = null;
    ref.read(tellerPanel3Provider.notifier).state = null;
    return;
  }
  context.pop();
}

void navToTagSystemEdit(BuildContext context, WidgetRef ref, int id) {
  if (isDesktopLayout(context)) {
    ref.read(tagSystemsPanelSelectionProvider.notifier).state =
        TagSystemsPanelSelection.edit(id);
  } else {
    context.push('/tag-system/form/$id');
  }
}

void navToTagSystemCreate(BuildContext context, WidgetRef ref) {
  if (isDesktopLayout(context)) {
    ref.read(tagSystemsPanelSelectionProvider.notifier).state =
        const TagSystemsPanelSelection.create();
  } else {
    context.push('/tag-system/form');
  }
}

void navTagSystemFormBack(BuildContext context, WidgetRef ref) {
  if (isDesktopLayout(context)) {
    ref.read(tagSystemsPanelSelectionProvider.notifier).state = null;
  } else {
    context.pop();
  }
}

/// From Teller detail: desktop shows linked model in the Teller third column;
/// mobile opens the expense route (pops Teller detail first).
void navToExpenseFromTellerLink(
  BuildContext context,
  WidgetRef ref,
  int expenseId,
) {
  if (isDesktopLayout(context)) {
    ref.read(tellerPanel3Provider.notifier).state = TellerPanel3State.expense(
      expenseId,
    );
  } else {
    final router = GoRouter.of(context);
    router.pop();
    router.push('/expense/$expenseId');
  }
}

/// From Teller detail: desktop shows linked transfer in the Teller third column;
/// mobile opens the transfer route (pops Teller detail first).
void navToTransferFromTellerLink(
  BuildContext context,
  WidgetRef ref,
  int transferId,
) {
  if (isDesktopLayout(context)) {
    ref.read(tellerPanel3Provider.notifier).state = TellerPanel3State.transfer(
      transferId,
    );
  } else {
    final router = GoRouter.of(context);
    router.pop();
    router.push('/transfer/$transferId');
  }
}
