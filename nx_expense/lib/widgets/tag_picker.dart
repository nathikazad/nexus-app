import 'package:flutter/material.dart';
import 'package:nx_db/nx_db.dart';

import 'tag_tree_tile.dart';

/// Returns selected node names per system rules (one for exclusive, many for multiple).
Future<List<String>?> showTagPickerSheet(
  BuildContext context, {
  required TagSystem system,
  required List<String> initial,
}) {
  final exclusive = system.selectionMode.toLowerCase() == 'exclusive';
  final hierarchical = system.isHierarchical;

  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return _TagPickerBody(
        system: system,
        initial: initial,
        exclusive: exclusive,
        hierarchical: hierarchical,
      );
    },
  );
}

class _TagPickerBody extends StatefulWidget {
  const _TagPickerBody({
    required this.system,
    required this.initial,
    required this.exclusive,
    required this.hierarchical,
  });

  final TagSystem system;
  final List<String> initial;
  final bool exclusive;
  final bool hierarchical;

  @override
  State<_TagPickerBody> createState() => _TagPickerBodyState();
}

class _TagPickerBodyState extends State<_TagPickerBody> {
  late Set<String> _sel;

  @override
  void initState() {
    super.initState();
    _sel = {...widget.initial};
  }

  void _toggle(String name) {
    setState(() {
      if (widget.exclusive) {
        _sel = {name};
      } else {
        if (_sel.contains(name)) {
          _sel.remove(name);
        } else {
          _sel.add(name);
        }
      }
    });
  }

  Widget _flat() {
    final nodes = widget.system.nodes;
    final flat = <TagNode>[];
    void collect(List<TagNode> ns) {
      for (final n in ns) {
        flat.add(n);
        if (n.children != null) collect(n.children!);
      }
    }

    collect(nodes);

    if (widget.exclusive) {
      return ListView(
        shrinkWrap: true,
        children: [
          for (final n in flat)
            RadioListTile<String>(
              value: n.name,
              groupValue: _sel.isEmpty ? null : _sel.first,
              onChanged: (v) {
                if (v != null) setState(() => _sel = {v});
              },
              title: Text(n.name),
            ),
        ],
      );
    }

    return ListView(
      shrinkWrap: true,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final n in flat)
              FilterChip(
                label: Text(n.name),
                selected: _sel.contains(n.name),
                onSelected: (_) => _toggle(n.name),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.85;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: maxH,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.system.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 2),
              Text(
                widget.exclusive ? 'Choose one' : 'Choose any',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: widget.hierarchical
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final root in widget.system.nodes)
                              TagTreeTile(
                                node: root,
                                selected: _sel,
                                onTapNode: (name) {
                                  if (widget.exclusive) {
                                    setState(() => _sel = {name});
                                  } else {
                                    _toggle(name);
                                  }
                                },
                                multiSelect: !widget.exclusive,
                              ),
                          ],
                        )
                      : _flat(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, _sel.toList()),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact row that opens the picker sheet.
class TagPickerRow extends StatelessWidget {
  const TagPickerRow({
    super.key,
    required this.system,
    required this.value,
    required this.onChanged,
  });

  final TagSystem system;
  final List<String> value;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        final res = await showTagPickerSheet(
          context,
          system: system,
          initial: value,
        );
        if (res != null) onChanged(res);
      },
      icon: const Icon(Icons.label_outline),
      label: Text(
        value.isEmpty ? 'Select ${system.name}' : value.join(', '),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
