import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:nx_projects/core/theme/app_theme.dart';

/// Right-side overlay matching `reference/desktop` task drawers: dim backdrop,
/// fixed right panel, header + body.
class ReferenceSideDrawer extends StatelessWidget {
  const ReferenceSideDrawer({
    super.key,
    required this.onClose,
    this.title = '',
    required this.child,
    this.widthMode = ReferenceSideDrawerWidth.narrow,
    this.subtitle,
    this.trailing,
    this.showHeader = true,
  });

  final VoidCallback onClose;
  final String title;
  final Widget child;

  /// When false, only [child] is shown (full height). Use for custom chrome inside the body.
  final bool showHeader;

  /// [narrow] = 560 (forms). [wide] = min(720, 0.96 * viewport) (read-only view).
  final ReferenceSideDrawerWidth widthMode;
  final String? subtitle;
  final List<Widget>? trailing;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final w = size.width;
    final h = size.height;
    final double maxW = widthMode == ReferenceSideDrawerWidth.wide
        ? math.min(720, w * 0.96)
        : 560.0;
    return Stack(
      children: [
        Positioned.fill(
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClose,
              child: const ColoredBox(color: Color(0x99080A0E)),
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: Material(
            color: AppColors.panel,
            elevation: 8,
            child: SizedBox(
              width: maxW,
              height: h,
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: AppColors.border),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 16,
                      offset: Offset(-4, 0),
                    ),
                  ],
                ),
                child: showHeader
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (title.isNotEmpty)
                                        Text(
                                          title,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.text,
                                          ),
                                        ),
                                      if (subtitle != null) ...[
                                        if (title.isNotEmpty) const SizedBox(height: 4),
                                        Text(
                                          subtitle!,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.dim,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (trailing != null) ...trailing!,
                                IconButton(
                                  onPressed: onClose,
                                  icon: const Icon(Icons.close, size: 20),
                                  style: IconButton.styleFrom(
                                    minimumSize: const Size(32, 32),
                                    padding: EdgeInsets.zero,
                                    foregroundColor: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: AppColors.border),
                          Expanded(child: child),
                        ],
                      )
                    : child,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Width preset for [ReferenceSideDrawer].
enum ReferenceSideDrawerWidth { narrow, wide }
