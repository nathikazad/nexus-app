import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:nx_db/auth.dart';

import 'package:nx_projects/core/theme/app_theme.dart';

/// Reference `reference/desktop/styles.css` `.topbar` + `.top-tab` / `.top-tab.active`.
class DesktopTopBar extends ConsumerWidget {
  DesktopTopBar({super.key, required this.activeIndex, required this.onSelect});

  /// 0 = Planner, 1 = Sprint, 2 = Today
  final int activeIndex;
  final ValueChanged<int> onSelect;

  static final _labels = <String>['Planner', 'Sprint', 'Today'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: context.colors.panel,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.colors.border)),
        ),
        padding: EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: [
            Text(
              '◆ Nexus',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                fontSize: 14,
                color: context.colors.text,
              ),
            ),
            SizedBox(width: 24),
            for (var i = 0; i < _labels.length; i++) ...[
              if (i > 0) SizedBox(width: 4),
              _TopTab(
                label: _labels[i],
                selected: activeIndex == i,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelect(i);
                },
              ),
            ],
            Spacer(),
            _AccountButton(),
          ],
        ),
      ),
    );
  }
}

class _AccountButton extends ConsumerStatefulWidget {
  _AccountButton();

  @override
  ConsumerState<_AccountButton> createState() => _AccountButtonState();
}

class _AccountButtonState extends ConsumerState<_AccountButton> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _menuEntry;

  @override
  void dispose() {
    _closeMenu();
    super.dispose();
  }

  void _toggleMenu() {
    if (_menuEntry == null) {
      _openMenu();
    } else {
      _closeMenu();
    }
  }

  void _openMenu() {
    final overlay = Overlay.of(context);
    _menuEntry = OverlayEntry(
      builder: (overlayContext) {
        final light = ref.watch(appThemeModeProvider) == ThemeMode.light;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closeMenu,
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: Offset(0, 6),
              child: _AccountMenu(
                light: light,
                onToggleTheme: () {
                  _closeMenu();
                  ref.read(appThemeModeProvider.notifier).toggle();
                },
                onLogout: () async {
                  _closeMenu();
                  await ref.read(authProvider.notifier).logout();
                },
              ),
            ),
          ],
        );
      },
    );
    overlay.insert(_menuEntry!);
  }

  void _closeMenu() {
    _menuEntry?.remove();
    _menuEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggleMenu,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Text(
              '@nathik',
              style: TextStyle(color: context.colors.muted, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountMenu extends StatelessWidget {
  _AccountMenu({
    required this.light,
    required this.onToggleTheme,
    required this.onLogout,
  });

  final bool light;
  final VoidCallback onToggleTheme;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 150,
        padding: EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: context.colors.panel,
          border: Border.all(color: context.colors.border),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AccountMenuItem(
              label: light ? 'Dark mode' : 'Light mode',
              onTap: onToggleTheme,
            ),
            _AccountMenuItem(label: 'Logout', onTap: onLogout),
          ],
        ),
      ),
    );
  }
}

class _AccountMenuItem extends StatelessWidget {
  _AccountMenuItem({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: TextStyle(color: context.colors.text, fontSize: 12),
        ),
      ),
    );
  }
}

class _TopTab extends StatelessWidget {
  _TopTab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? context.colors.panel2 : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Opacity(
            opacity: selected ? 1 : 0.55,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: selected ? context.colors.text : context.colors.muted,
                fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
