import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

import '../data/teller_timeline_api.dart';

const double kDesktopBreakpoint = 1100;

bool isDesktopLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;

/// Selected tab in [DesktopShell] (0–4).
final desktopShellTabIndexProvider = StateProvider<int>((ref) => 0);

// --- Expenses tab ---
final selectedExpenseIdProvider = StateProvider<int?>((ref) => null);

final panel3StateProvider = StateProvider<Panel3State>(
  (ref) => const Panel3State(),
);

// --- Transfers tab ---
final selectedTransferIdProvider = StateProvider<int?>((ref) => null);

// --- Teller tab ---
final selectedTellerRowProvider = StateProvider<TellerTransactionRow?>(
  (ref) => null,
);

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

enum Panel3Type { none, transfer, teller, tagExpenses, relationExpenses }

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

void navToExpenseDetail(BuildContext context, WidgetRef ref, int id) {
  if (isDesktopLayout(context)) {
    ref.read(selectedExpenseIdProvider.notifier).state = id;
    ref.read(panel3StateProvider.notifier).state = const Panel3State();
  } else {
    context.push('/expense/$id');
  }
}

void navToTransferDetail(BuildContext context, WidgetRef ref, int transferId) {
  if (isDesktopLayout(context)) {
    ref.read(panel3StateProvider.notifier).state = Panel3State(
      type: Panel3Type.transfer,
      id: transferId,
    );
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
    ref.read(panel3StateProvider.notifier).state = Panel3State(
      type: Panel3Type.relationExpenses,
      id: relId,
      label: relName,
      secondaryLabel: displayName,
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
    ref.read(panel3StateProvider.notifier).state = Panel3State(
      type: Panel3Type.tagExpenses,
      label: systemName,
      secondaryLabel: tagNode,
    );
  } else {
    context.push(
      '/expenses/by-tag/${Uri.encodeComponent(systemName)}/${Uri.encodeComponent(tagNode)}',
    );
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
    ref.read(panel3StateProvider.notifier).state = const Panel3State();
  } else {
    context.go('/expenses');
  }
}

/// Back from expense detail: pop route on mobile; clear desktop selection on shell.
void navExpenseDetailBack(BuildContext context, WidgetRef ref) {
  if (!isDesktopLayout(context)) {
    context.pop();
    return;
  }
  ref.read(selectedExpenseIdProvider.notifier).state = null;
  ref.read(panel3StateProvider.notifier).state = const Panel3State();
}

/// Back from transfer detail (embedded or full-screen).
void navTransferDetailBack(BuildContext context, WidgetRef ref, int transferId) {
  if (!isDesktopLayout(context)) {
    context.pop();
    return;
  }
  final p3 = ref.read(panel3StateProvider);
  if (p3.type == Panel3Type.transfer && p3.id == transferId) {
    ref.read(panel3StateProvider.notifier).state = const Panel3State();
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
  final p3 = ref.read(panel3StateProvider);
  if (p3.type == Panel3Type.teller &&
      p3.tellerRow?.eventId == row.eventId) {
    ref.read(panel3StateProvider.notifier).state = const Panel3State();
    return;
  }
  final sel = ref.read(selectedTellerRowProvider);
  if (sel?.eventId == row.eventId) {
    ref.read(selectedTellerRowProvider.notifier).state = null;
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

/// From Teller detail: open expense and switch to Expenses rail tab.
void navToExpenseFromTellerLink(BuildContext context, WidgetRef ref, int expenseId) {
  if (isDesktopLayout(context)) {
    ref.read(desktopShellTabIndexProvider.notifier).state = 0;
    ref.read(selectedExpenseIdProvider.notifier).state = expenseId;
    ref.read(panel3StateProvider.notifier).state = const Panel3State();
    ref.read(selectedTellerRowProvider.notifier).state = null;
  } else {
    final router = GoRouter.of(context);
    router.pop();
    router.push('/expense/$expenseId');
  }
}
