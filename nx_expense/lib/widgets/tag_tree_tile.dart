import 'package:flutter/material.dart';
import 'package:nx_db/nx_db.dart';

/// Expandable row for hierarchical tag picking.
class TagTreeTile extends StatefulWidget {
  const TagTreeTile({
    super.key,
    required this.node,
    required this.selected,
    required this.onTapNode,
    this.multiSelect = false,
  });

  final TagNode node;
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
    final children = widget.node.children ?? const <TagNode>[];
    final hasKids = children.isNotEmpty;
    final isSel = widget.selected.contains(widget.node.name);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (hasKids)
              IconButton(
                icon: Icon(_expanded ? Icons.expand_more : Icons.chevron_right),
                onPressed: () => setState(() => _expanded = !_expanded),
              )
            else
              const SizedBox(width: 48),
            Expanded(
              child: ListTile(
                dense: true,
                leading: widget.multiSelect
                    ? Checkbox(
                        value: isSel,
                        onChanged: (_) => widget.onTapNode(widget.node.name),
                      )
                    : Icon(isSel ? Icons.radio_button_checked : Icons.radio_button_off),
                title: Text(widget.node.name),
                onTap: () => widget.onTapNode(widget.node.name),
              ),
            ),
          ],
        ),
        if (hasKids && _expanded)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
