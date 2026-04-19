# Desktop Support Plan

## Overview

Add an adaptive desktop layout to nx_expense. On screens ≥ 1100px wide, the app
switches from mobile push-navigation to a multi-panel layout with a
`NavigationRail`. Mobile behaviour is completely unchanged.

## Layout

```
┌──────────┬───────────────┬────────────────┬────────────────┐
│ Nav Rail │  Panel 1      │  Panel 2       │  Panel 3       │
│  ~72px   │  list         │  detail        │  contextual    │
│          │               │                │                │
│ Expenses │               │                │                │
│ Stats    │               │                │                │
│ Transfers│               │                │                │
│ Tags     │               │                │                │
│ Teller   │               │                │                │
│          │               │                │                │
│          │               │                │                │
│ ──────── │               │                │                │
│ [Logout] │               │                │                │
└──────────┴───────────────┴────────────────┴────────────────┘
```

### Per-tab content

| Tab       | Panel 1                    | Panel 2                        | Panel 3                                      |
|-----------|----------------------------|--------------------------------|----------------------------------------------|
| Expenses  | ExpenseListScreen          | ExpenseDetailScreen            | TransferDetail / Scoped expense list (by relation or tag) / TellerTransactionDetail |
| Stats     | DashboardScreen (full width, panels 2+3 collapsed)                                                        |||
| Transfers | TransfersListScreen        | TransferDetailScreen           | (empty / future use)                         |
| Tags      | TagSystemsScreen (full width, panels 2+3 collapsed)                                                       |||
| Teller    | TellerListScreen           | TellerTransactionDetailScreen  | (2-panel, no panel 3)                        |

### Navigation Rail

- Collapsed style (`NavigationRailLabelType.all`) — icon + label, ~72px wide.
- `leading`: app branding ("EXPNS.").
- `trailing`: logout button pinned to the bottom via `Expanded` + `Spacer`.
- 5 destinations: Expenses, Stats, Transfers, Tags, Teller.
- On mobile these extra destinations (Tags, Teller) remain accessible through
  existing routes/drawer — the rail only exists on desktop.

## Architecture: Option A — Platform-Aware Navigation Helpers

### Principle

Screens never know about panels. They call helper functions like
`navToExpenseDetail(context, ref, id)`. Each helper checks
`isDesktopLayout(context)`:
- **Desktop** → updates a Riverpod `StateProvider` (panel state).
- **Mobile** → calls `context.push('/expense/$id')` (existing GoRouter behaviour).

### New files

```
lib/desktop/
├── desktop_nav.dart      # isDesktopLayout(), panel providers, nav helpers
├── desktop_shell.dart    # DesktopShell widget (NavigationRail + content area)
└── panel_chrome.dart     # Lightweight panel header (replaces Scaffold/AppBar when embedded)
```

### New Riverpod state

```dart
// desktop_nav.dart

const double kDesktopBreakpoint = 1100;
bool isDesktopLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;

// --- Expenses tab ---
final selectedExpenseIdProvider    = StateProvider<int?>((ref) => null);
final panel3StateProvider          = StateProvider<Panel3State>((ref) => const Panel3State());

// --- Transfers tab ---
final selectedTransferIdProvider   = StateProvider<int?>((ref) => null);

// --- Teller tab ---
final selectedTellerTxIdProvider   = StateProvider<int?>((ref) => null);

// Panel 3 types
enum Panel3Type { none, transfer, teller, tagExpenses, relationExpenses }

class Panel3State {
  final Panel3Type type;
  final int? id;
  final String? label;
  final String? secondaryLabel;
}
```

### Navigation helpers (in `desktop_nav.dart`)

| Helper                        | Mobile fallback                              | Desktop action                        |
|-------------------------------|----------------------------------------------|---------------------------------------|
| `navToExpenseDetail`          | `context.push('/expense/$id')`               | set `selectedExpenseIdProvider`        |
| `navToTransferDetail`         | `context.push('/transfer/$id')`              | set `panel3StateProvider` (transfer)   |
| `navToRelationExpenses`       | `context.push('/expenses/by-relation/...')`  | set `panel3StateProvider` (relation)   |
| `navToTagExpenses`            | `context.push('/expenses/by-tag/...')`       | set `panel3StateProvider` (tag)        |
| `navToTellerTxDetail`         | `Navigator.push(TellerTransactionDetailScreen)` | set `selectedTellerTxIdProvider`    |
| `navToTransferDetailDirect`   | `context.push('/transfer/$id')`              | set `selectedTransferIdProvider`       |

### `desktop_shell.dart` structure

```dart
class DesktopShell extends ConsumerStatefulWidget { ... }

class _DesktopShellState extends ConsumerState<DesktopShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
            labelType: NavigationRailLabelType.all,
            leading: /* branding */,
            trailing: Expanded(
              child: Column(
                children: [Spacer(), IconButton(logout), SizedBox(height: 16)],
              ),
            ),
            destinations: [Expenses, Stats, Transfers, Tags, Teller],
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: switch (_currentIndex) {
              0 => _buildExpensesPanels(ref),       // 3-panel
              1 => const DashboardScreen(),          // full width
              2 => _buildTransfersPanels(ref),       // 3-panel
              3 => const TagSystemsScreen(),          // full width
              4 => _buildTellerPanels(ref),          // 2-panel
              _ => const SizedBox.shrink(),
            },
          ),
        ],
      ),
    );
  }
}
```

#### `_buildExpensesPanels`

```
Row(
  SizedBox(width: 360, child: ExpenseListScreen()),
  VerticalDivider,
  Expanded(child: selectedExpenseId != null ? ExpenseDetailScreen(...) : empty),
  VerticalDivider,
  SizedBox(width: 380, child: _panel3Content(...)),
)
```

Panel 3 content switches on `Panel3State.type`:
- `transfer` → `TransferDetailScreen(transferId: ...)`
- `relationExpenses` → `scopedExpenseListScreen(title: ..., initialFilter: ...)`
- `tagExpenses` → `scopedExpenseListScreen(title: ..., initialFilter: ...)`
- `teller` → `TellerTransactionDetailScreen(...)`
- `none` → empty

#### `_buildTransfersPanels`

```
Row(
  SizedBox(width: 360, child: TransfersListScreen()),
  VerticalDivider,
  Expanded(child: selectedTransferId != null ? TransferDetailScreen(...) : empty),
)
```

Two panels only. No panel 3 for transfers tab.

#### `_buildTellerPanels`

```
Row(
  SizedBox(width: 360, child: TellerListScreen()),
  VerticalDivider,
  Expanded(child: selectedTellerTxId != null ? TellerTransactionDetailScreen(...) : empty),
)
```

Two panels. Teller list on the left, transaction detail on the right.

### `panel_chrome.dart`

A lightweight `Column(header, Expanded(body))` widget that replaces
`Scaffold` + `AppBar` when a screen is embedded inside a panel. Takes a `title`,
`body`, and optional `actions`.

## Changes to Existing Files

### `router.dart`

One change in the `StatefulShellRoute.indexedStack` builder:

```dart
builder: (context, state, navigationShell) {
  if (isDesktopLayout(context)) {
    return const DesktopShell();
  }
  // ... existing mobile Scaffold with NavigationBar (unchanged) ...
}
```

All `GoRoute` definitions remain unchanged — they are still needed for mobile
navigation, deep links, and full-screen flows (expense form, tag browser, etc.).

### `expense_list_screen.dart`

- Add import: `../../desktop/desktop_nav.dart`
- Line 715: replace `context.push('/expense/${m.id}')` with
  `navToExpenseDetail(context, ref, m.id)`

### `expense_detail_screen.dart`

- Add import: `../../desktop/desktop_nav.dart`, `../../desktop/panel_chrome.dart`
- Line 571 (`_transferCell`): replace `context.push('/transfer/${relM.id}')` with
  `navToTransferDetail(context, ref, relM.id)`
- Line 631 (`_relationRow`): replace `context.push('/expenses/by-relation/...')`
  with `navToRelationExpenses(context, ref, relName: ..., relId: ..., displayName: ...)`
- Line 520 (`_buildTagValues`): replace `context.push('/expenses/by-tag/...')`
  with `navToTagExpenses(context, ref, systemName: ..., tagNode: ...)`
- Line 111 (`context.push('/expense/form/$expenseId')`) stays as-is — form is
  always full-screen.
- `_DetailBody.build`: wrap Scaffold conditionally — use `PanelChrome` when
  `isDesktopLayout(context)` is true, existing `Scaffold` otherwise.

### `transfer_detail_screen.dart`

- Same Scaffold-stripping pattern: use `PanelChrome` when embedded on desktop.

### `teller_list_screen.dart`

- Line 176: replace `Navigator.push(TellerTransactionDetailScreen)` with
  `navToTellerTxDetail(context, ref, ...)`.

### `teller_transaction_detail_screen.dart`

- Scaffold-stripping: use `PanelChrome` when `isDesktopLayout`.

### `transfers_list_screen.dart`

- Add tap handler on transfer rows to call `navToTransferDetailDirect(context, ref, id)`.

## Summary of Changes

| File                                  | Type     | Scope                                    |
|---------------------------------------|----------|------------------------------------------|
| `lib/desktop/desktop_nav.dart`        | **new**  | Providers, helpers, breakpoint            |
| `lib/desktop/desktop_shell.dart`      | **new**  | NavigationRail + multi-panel shell        |
| `lib/desktop/panel_chrome.dart`       | **new**  | Embedded panel header widget              |
| `lib/router.dart`                     | modify   | Add `isDesktopLayout` guard in builder    |
| `lib/screens/expense/expense_list_screen.dart`       | modify | 1 line: nav helper          |
| `lib/screens/expense/expense_detail_screen.dart`     | modify | ~8 lines: nav helpers + PanelChrome |
| `lib/screens/transfers/transfer_detail_screen.dart`  | modify | PanelChrome conditional     |
| `lib/screens/transfers/transfers_list_screen.dart`   | modify | Add row tap → nav helper    |
| `lib/screens/teller/teller_list_screen.dart`         | modify | 1 line: nav helper          |
| `lib/screens/teller/teller_transaction_detail_screen.dart` | modify | PanelChrome conditional |

**~3 new files (~250 lines), ~6 existing files modified (~40 lines changed).**

## Key Design Decisions

1. **No nested Navigators** — panel state is Riverpod providers, not router stacks.
2. **GoRouter stays for mobile + deep links** — desktop bypasses it for panel
   selection only.
3. **Screens stay ignorant of panels** — they call `navToX()` which internally
   checks width.
4. **Tab state persists across rail switches** — switching from Expenses → Stats →
   Expenses remembers the selected expense.
5. **Full-screen flows stay full-screen** — expense form, tag browser, relation
   picker always push a route even on desktop.
6. **Mobile is completely untouched** — `isDesktopLayout` returns false, all
   helpers fall through to existing `context.push` calls.
