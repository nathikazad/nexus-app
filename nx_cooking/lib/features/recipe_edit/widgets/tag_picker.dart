import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nx_cooking/core/theme/app_theme.dart';
import 'package:nx_cooking/domain/schema/model_type_view.dart';
import 'tag_tree_tile.dart';

/// Returns selected node names per system rules (one for exclusive, many for multiple).
Future<List<String>?> showTagPickerSheet(
  BuildContext context, {
  required TagSystemView system,
  required List<String> initial,
}) {
  final exclusive = system.selectionMode.toLowerCase() == 'exclusive';
  final hierarchical = system.isHierarchical;

  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
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

  final TagSystemView system;
  final List<String> initial;
  final bool exclusive;
  final bool hierarchical;

  @override
  State<_TagPickerBody> createState() => _TagPickerBodyState();
}

class _TagPickerBodyState extends State<_TagPickerBody> {
  late Set<String> _sel;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sel = {...widget.initial};
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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

  void _clearExclusive() {
    setState(() => _sel = {});
  }

  List<TagNodeView> _flattenNodes(List<TagNodeView> roots) {
    final out = <TagNodeView>[];
    void walk(List<TagNodeView> ns) {
      for (final n in ns) {
        out.add(n);
        if (n.children != null) walk(n.children!);
      }
    }

    walk(roots);
    return out;
  }

  String _searchPlaceholder() {
    final n = widget.system.name;
    return 'Search ${n.toLowerCase()}...';
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.88;
    final q = _search.text.trim().toLowerCase();

    return SafeArea(
      child: SizedBox(
        height: maxH,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.arrow_back, color: AppColors.zinc400, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      'Select ${widget.system.name}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                        color: AppColors.zinc900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, _sel.toList()),
                    child: Text(
                      'Done',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.orange500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.zinc100),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.zinc900),
                decoration: InputDecoration(
                  hintText: _searchPlaceholder(),
                  hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.zinc400),
                  prefixIcon: const Icon(Icons.search, color: AppColors.zinc400, size: 20),
                  filled: true,
                  fillColor: AppColors.zinc100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.zinc100),
            Expanded(
              child: widget.exclusive && !widget.hierarchical
                  ? _buildFlatExclusive(q)
                  : widget.exclusive && widget.hierarchical
                      ? _buildHierarchicalExclusive(q)
                      : _buildMultiple(q),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlatExclusive(String q) {
    final flat = _flattenNodes(widget.system.nodes);
    final filtered = q.isEmpty
        ? flat
        : flat.where((n) => n.name.toLowerCase().contains(q)).toList();

    return ListView(
      children: [
        _noneRowExclusive(),
        for (var i = 0; i < filtered.length; i++)
          _radioRow(
            label: filtered[i].name,
            labelStyle: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.zinc900,
            ),
            selected: _sel.contains(filtered[i].name),
            onTap: () => _toggle(filtered[i].name),
            showDivider: i < filtered.length - 1,
          ),
      ],
    );
  }

  Widget _buildHierarchicalExclusive(String q) {
    if (q.isNotEmpty) {
      final flat = _flattenNodes(widget.system.nodes);
      final filtered = flat.where((n) => n.name.toLowerCase().contains(q)).toList();
      return ListView(
        children: [
          _noneRowExclusive(),
          for (var i = 0; i < filtered.length; i++)
            _radioRow(
              label: filtered[i].name,
              labelStyle: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.zinc700,
              ),
              selected: _sel.contains(filtered[i].name),
              onTap: () => _toggle(filtered[i].name),
              showDivider: i < filtered.length - 1,
            ),
        ],
      );
    }

    return ListView(
      children: [
        _noneRowExclusive(),
        for (final root in widget.system.nodes)
          TagTreeTile(
            node: root,
            selected: _sel,
            onTapNode: (name) => setState(() => _sel = {name}),
          ),
      ],
    );
  }

  Widget _noneRowExclusive() {
    final on = _sel.isEmpty;
    return _radioRow(
      label: 'None',
      labelStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        fontStyle: FontStyle.italic,
        color: AppColors.zinc400,
      ),
      selected: on,
      onTap: _clearExclusive,
      showDivider: true,
    );
  }

  Widget _radioRow({
    required String label,
    required TextStyle labelStyle,
    required bool selected,
    required VoidCallback onTap,
    required bool showDivider,
  }) {
    return Column(
      children: [
        Material(
          color: Colors.white,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Expanded(child: Text(label, style: labelStyle)),
                  _TagRadioCircle(selected: selected),
                ],
              ),
            ),
          ),
        ),
        if (showDivider) const Divider(height: 1, color: AppColors.zinc100),
      ],
    );
  }

  Widget _buildMultiple(String q) {
    if (widget.hierarchical) {
      final flat = _flattenNodes(widget.system.nodes);
      if (q.isNotEmpty) {
        final filtered = flat.where((n) => n.name.toLowerCase().contains(q)).toList();
        return ListView(
          children: [
            for (var i = 0; i < filtered.length; i++)
              _checkboxRow(
                label: filtered[i].name,
                checked: _sel.contains(filtered[i].name),
                onTap: () => _toggle(filtered[i].name),
                showDivider: i < filtered.length - 1,
              ),
          ],
        );
      }
      return ListView(
        children: [
          for (final root in widget.system.nodes)
            TagTreeTile(
              node: root,
              selected: _sel,
              multiSelect: true,
              onTapNode: (name) => _toggle(name),
            ),
        ],
      );
    }

    final flat = _flattenNodes(widget.system.nodes);
    final filtered = q.isEmpty
        ? flat
        : flat.where((n) => n.name.toLowerCase().contains(q)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final n in filtered)
              FilterChip(
                label: Text(n.name, style: GoogleFonts.inter(fontSize: 13)),
                selected: _sel.contains(n.name),
                onSelected: (_) => _toggle(n.name),
                selectedColor: AppColors.orange100,
                checkmarkColor: AppColors.orange600,
              ),
          ],
        ),
      ],
    );
  }

  Widget _checkboxRow({
    required String label,
    required bool checked,
    required VoidCallback onTap,
    required bool showDivider,
  }) {
    return Column(
      children: [
        Material(
          color: Colors.white,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.zinc900,
                      ),
                    ),
                  ),
                  Checkbox(
                    value: checked,
                    onChanged: (_) => onTap(),
                    fillColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return AppColors.orange500;
                      }
                      return null;
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider) const Divider(height: 1, color: AppColors.zinc100),
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
          color: selected ? AppColors.orange500 : AppColors.zinc300,
          width: selected ? 5 : 1,
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

  final TagSystemView system;
  final List<String> value;
  final ValueChanged<List<String>> onChanged;

  String _valueLabel() {
    if (value.isEmpty) return 'Select ${system.name}';
    return value.map((node) {
      final path = tagBreadcrumbPath(system, node);
      return (path != null && path.length > 1) ? path.join(' \u203A ') : node;
    }).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final res = await showTagPickerSheet(
            context,
            system: system,
            initial: value,
          );
          if (res != null) onChanged(res);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  system.name,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.zinc700,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  _valueLabel(),
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: value.isEmpty ? AppColors.zinc400 : AppColors.zinc900,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.zinc300, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
