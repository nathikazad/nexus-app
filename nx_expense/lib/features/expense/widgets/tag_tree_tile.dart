import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nx_expense/core/layout/layout.dart';
import 'package:nx_expense/core/theme/app_theme.dart';
import 'package:nx_expense/domain/schema/model_type_view.dart';

/// Expandable row for hierarchical tag picking (mockup-style radio rows).
class TagTreeTile extends StatefulWidget {
  const TagTreeTile({
    super.key,
    required this.node,
    required this.selected,
    required this.onTapNode,
    this.multiSelect = false,
  });

  final TagNodeView node;
  final Set<String> selected;
  final void Function(String name) onTapNode;
  final bool multiSelect;

  @override
  State<TagTreeTile> createState() => _TagTreeTileState();
}

class _TagTreeTileState extends State<TagTreeTile> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final children = widget.node.children ?? const <TagNodeView>[];
    final hasKids = children.isNotEmpty;
    final isSel = widget.selected.contains(widget.node.name);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.white,
          child: InkWell(
            onTap: () {
              if (widget.multiSelect) {
                widget.onTapNode(widget.node.name);
              } else {
                widget.onTapNode(widget.node.name);
              }
            },
            child: Padding(
              padding: EdgeInsets.only(
                left: hasKids ? 0 : 20,
                right: RefLayout.px5,
                top: 14,
                bottom: 14,
              ),
              child: Row(
                children: [
                  if (hasKids)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      icon: Icon(
                        _expanded ? Icons.expand_more : Icons.chevron_right,
                        color: AppColors.slate400,
                        size: 22,
                      ),
                      onPressed: () => setState(() => _expanded = !_expanded),
                    )
                  else
                    const SizedBox(width: 36),
                  Expanded(
                    child: Text(
                      widget.node.name,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: hasKids ? FontWeight.w600 : FontWeight.w500,
                        color: hasKids
                            ? AppColors.slate900
                            : AppColors.slate700,
                      ),
                    ),
                  ),
                  if (widget.multiSelect)
                    Checkbox(
                      value: isSel,
                      activeColor: AppColors.teal600,
                      onChanged: (_) => widget.onTapNode(widget.node.name),
                    )
                  else
                    _TagRadioCircle(selected: isSel),
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 1, color: AppColors.slate50),
        if (hasKids && _expanded)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final c in children)
                  TagTreeTile(
                    node: c,
                    selected: widget.selected,
                    onTapNode: widget.onTapNode,
                    multiSelect: widget.multiSelect,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TagRadioCircle extends StatelessWidget {
  const _TagRadioCircle({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(
          color: selected ? AppColors.teal600 : AppColors.slate300,
          width: selected ? 5 : 1,
        ),
      ),
    );
  }
}
