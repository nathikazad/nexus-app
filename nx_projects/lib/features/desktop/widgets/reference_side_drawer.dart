import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:nx_projects/core/theme/app_theme.dart';

/// Right-side overlay matching `reference/desktop` task drawers: dim backdrop,
/// fixed right panel, header + body.
class ReferenceSideDrawer extends StatelessWidget {
  ReferenceSideDrawer({
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
              child: ColoredBox(color: Color(0x99080A0E)),
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: Material(
            color: context.colors.panel,
            elevation: 8,
            child: SizedBox(
              width: maxW,
              height: h,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: context.colors.border),
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
                            padding: EdgeInsets.fromLTRB(16, 12, 8, 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (title.isNotEmpty)
                                        Text(
                                          title,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: context.colors.text,
                                          ),
                                        ),
                                      if (subtitle != null) ...[
                                        if (title.isNotEmpty)
                                          SizedBox(height: 4),
                                        Text(
                                          subtitle!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: context.colors.dim,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (trailing != null) ...trailing!,
                                IconButton(
                                  onPressed: onClose,
                                  icon: Icon(Icons.close, size: 20),
                                  style: IconButton.styleFrom(
                                    minimumSize: Size(32, 32),
                                    padding: EdgeInsets.zero,
                                    foregroundColor: context.colors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Divider(height: 1, color: context.colors.border),
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
