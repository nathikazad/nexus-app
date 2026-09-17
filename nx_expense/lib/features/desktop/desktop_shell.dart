import 'package:nx_expense/core/motion/expense_motion.dart';
import 'package:nx_expense/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_expense/features/expense/expense_form_page.dart';
import 'package:nx_expense/features/expense/expense_list_view_model.dart';
import 'desktop_nav.dart';

/// The URL is the selection state on every screen size. Desktop adds source
/// panes around the same routed child; it never mounts a second hidden shell.
class DesktopShell extends ConsumerWidget {
  const DesktopShell({
    super.key,
    required this.uri,
    required this.child,
    required this.buildDestination,
  });
  final Uri uri;
  final Widget child;
  final Widget Function(Uri) buildDestination;
  static const sections = [
    '/expenses',
    '/dashboard',
    '/budget',
    '/teller',
    '/orders',
    '/tag-systems',
    '/images',
  ];
  static const labels = [
    'Expenses',
    'Stats',
    'Budget',
    'Bank',
    'Orders',
    'Tags',
    'Images',
  ];
  static const icons = [
    Icons.account_balance_wallet_outlined,
    Icons.bar_chart,
    Icons.savings_outlined,
    Icons.account_balance_outlined,
    Icons.shopping_bag_outlined,
    Icons.sell_outlined,
    Icons.photo_library_outlined,
  ];

  Widget pane(Uri location) => NavigationLocation(
    key: ValueKey(location.toString()),
    uri: location,
    child: PaneEntrance(child: buildDestination(location)),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = navigationSection(uri);
    final index = sections.indexOf(section);
    final root = sections.contains(uri.path);
    final desktop = isDesktopLayout(context);
    final parent = navigationParent(uri);
    final showParent =
        parent != null &&
        !sections.contains(parent.path) &&
        parent.path != uri.path &&
        !parent.path.contains('/form') &&
        !parent.path.contains('/link-');
    final selecting = ref.watch(expenseListSelectionModeProvider);
    return Scaffold(
      backgroundColor: AppColors.slate50,
      body: desktop
          ? Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: NavigationRail(
                      backgroundColor: AppColors.slate900,
                      indicatorColor: AppColors.teal100,
                      selectedIconTheme: const IconThemeData(
                        color: AppColors.teal700,
                      ),
                      unselectedIconTheme: const IconThemeData(
                        color: AppColors.slate400,
                      ),
                      selectedLabelTextStyle: Theme.of(context)
                          .textTheme
                          .labelSmall!
                          .copyWith(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                      unselectedLabelTextStyle: Theme.of(context)
                          .textTheme
                          .labelSmall!
                          .copyWith(color: AppColors.slate400, fontSize: 11),
                      leading: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Column(
                          children: [
                            Icon(
                              Icons.account_balance_wallet_rounded,
                              color: AppColors.teal100,
                              size: 28,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'NX Expense',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      selectedIndex: index,
                      labelType: NavigationRailLabelType.all,
                      onDestinationSelected: (i) => context.go(sections[i]),
                      destinations: [
                        for (var i = 0; i < sections.length; i++)
                          NavigationRailDestination(
                            icon: Icon(icons[i]),
                            label: Text(labels[i]),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (!root) ...[
                    SizedBox(
                      width: showParent ? 280 : 340,
                      child: _PanelSurface(child: pane(Uri.parse(section))),
                    ),
                    const SizedBox(width: 10),
                    if (showParent) ...[
                      Expanded(child: _PanelSurface(child: pane(parent))),
                      const SizedBox(width: 10),
                    ],
                  ],
                  Expanded(child: _PanelSurface(active: true, child: child)),
                ],
              ),
            )
          : child,
      floatingActionButton: uri.path == '/expenses' && !selecting
          ? FloatingActionButton(
              tooltip: 'New expense',
              onPressed: () => showAddExpenseModal(context),
              child: const Icon(Icons.add),
            )
          : uri.path == '/tag-systems' && desktop
          ? FloatingActionButton(
              onPressed: () => navToTagSystemCreate(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: !desktop && root && index < 4
          ? DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.slate200)),
              ),
              child: NavigationBar(
                animationDuration: ExpenseMotion.reduced(context)
                    ? Duration.zero
                    : ExpenseMotion.enter,
                selectedIndex: index,
                onDestinationSelected: (i) => context.go(sections[i]),
                destinations: [
                  for (var i = 0; i < 4; i++)
                    NavigationDestination(
                      icon: Icon(icons[i]),
                      label: labels[i],
                    ),
                ],
              ),
            )
          : null,
    );
  }
}

class _PanelSurface extends StatelessWidget {
  const _PanelSurface({required this.child, this.active = false});
  final Widget child;
  final bool active;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: active ? AppColors.slate200 : AppColors.slate100,
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.slate900.withValues(alpha: active ? .045 : .02),
          blurRadius: 24,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(1),
      child: ClipRRect(borderRadius: BorderRadius.circular(21), child: child),
    ),
  );
}
