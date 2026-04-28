import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nx_cooking/core/theme/app_theme.dart';
import 'package:nx_cooking/domain/recipe_filter.dart';
import 'package:nx_cooking/domain/schema/model_type_view.dart';

/// Bottom sheet: filter recipes by KGQL tag systems (same shape as nx_expense).
class RecipeTagFilterSheet extends StatefulWidget {
  const RecipeTagFilterSheet({
    super.key,
    required this.schema,
    required this.initial,
    required this.onApply,
  });

  final ModelTypeView schema;
  final RecipeFilter? initial;
  final void Function(RecipeFilter?) onApply;

  @override
  State<RecipeTagFilterSheet> createState() => _RecipeTagFilterSheetState();
}

class _RecipeTagFilterSheetState extends State<RecipeTagFilterSheet> {
  late Map<String, Set<String>> _tagSelections;
  final Map<String, Set<String>> _expandedNodes = {};
  final Set<String> _expandedSections = {};

  @override
  void initState() {
    super.initState();
    _tagSelections = {};
    final existing = widget.initial;
    if (existing?.tagFilters != null) {
      for (final tf in existing!.tagFilters!) {
        final system = tf['system'] as String? ?? '';
        final node = tf['node'] as String? ?? '';
        _tagSelections.putIfAbsent(system, () => {}).add(node);
      }
    }
    for (final ts in widget.schema.tagSystems) {
      if ((_tagSelections[ts.name] ?? {}).isNotEmpty) {
        _expandedSections.add('tag:${ts.name}');
      }
    }
  }

  void _reset() {
    setState(() {
      _tagSelections.clear();
    });
  }

  void _apply() {
    final tagFilters = <Map<String, dynamic>>[];
    for (final entry in _tagSelections.entries) {
      for (final node in entry.value) {
        tagFilters.add({
          'system': entry.key,
          'node': node,
          'include_descendants': true,
        });
      }
    }
    final f = RecipeFilter(
      tagFilters: tagFilters.isEmpty ? null : tagFilters,
    );
    widget.onApply(f.isEmpty ? null : f);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final tagSystems = widget.schema.tagSystems;
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.zinc200,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Filter by tag',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.zinc900,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _reset,
                  child: Text(
                    'Reset',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.zinc400,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: _apply,
                  child: Text(
                    'Apply',
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
          Expanded(
            child: tagSystems.isEmpty
                ? Center(
                    child: Text(
                      'No tag systems yet.\nAdd them from the menu (Tags).',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.zinc500,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    children: [
                      for (final ts in tagSystems) _collapsibleSection(ts),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _collapsibleSection(TagSystemView ts) {
    final key = 'tag:${ts.name}';
    final isExpanded = _expandedSections.contains(key);
    final count = (_tagSelections[ts.name] ?? {}).length;
    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedSections.remove(key);
              } else {
                _expandedSections.add(key);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Text(
                  ts.name.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: AppColors.zinc400,
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.orange500,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 20,
                  color: AppColors.zinc400,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ts.isHierarchical
                ? _buildHierarchicalContent(ts)
                : _buildFlatContent(ts),
          ),
        const Divider(height: 1, color: AppColors.zinc100),
      ],
    );
  }

  Widget _buildHierarchicalContent(TagSystemView ts) {
    final selected = _tagSelections[ts.name] ?? {};
    final expanded = _expandedNodes.putIfAbsent(ts.name, () => {});
    return Container(
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.zinc100, width: 2)),
      ),
      padding: const EdgeInsets.only(left: 12),
      child: Column(
        children: [
          for (final node in ts.nodes)
            _buildTreeNode(ts, node, selected, expanded, depth: 0),
        ],
      ),
    );
  }

  Widget _buildTreeNode(
    TagSystemView ts,
    TagNodeView node,
    Set<String> selected,
    Set<String> expanded, {
    required int depth,
  }) {
    final hasChildren = node.children != null && node.children!.isNotEmpty;
    final isExpanded = expanded.contains(node.name);
    final isSelected = selected.contains(node.name);
    final isExclusive = ts.selectionMode == 'exclusive';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() {
              final sel = _tagSelections.putIfAbsent(ts.name, () => {});
              if (isSelected) {
                sel.remove(node.name);
              } else {
                if (isExclusive) sel.clear();
                sel.add(node.name);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                _checkbox(isSelected, size: depth == 0 ? 20.0 : 18.0),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    node.name,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: depth == 0
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: depth == 0
                          ? AppColors.zinc900
                          : AppColors.zinc700,
                    ),
                  ),
                ),
                if (hasChildren)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isExpanded) {
                          expanded.remove(node.name);
                        } else {
                          expanded.add(node.name);
                        }
                      });
                    },
                    child: Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_down
                          : Icons.chevron_right,
                      size: 18,
                      color: AppColors.zinc300,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (hasChildren && isExpanded)
          Container(
            margin: const EdgeInsets.only(left: 20),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: AppColors.zinc100, width: 2),
              ),
            ),
            padding: const EdgeInsets.only(left: 12),
            child: Column(
              children: [
                for (final child in node.children!)
                  _buildTreeNode(
                    ts,
                    child,
                    selected,
                    expanded,
                    depth: depth + 1,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildFlatContent(TagSystemView ts) {
    final selected = _tagSelections[ts.name] ?? {};
    final isExclusive = ts.selectionMode == 'exclusive';

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final node in ts.nodes)
          GestureDetector(
            onTap: () {
              setState(() {
                final sel = _tagSelections.putIfAbsent(ts.name, () => {});
                if (selected.contains(node.name)) {
                  sel.remove(node.name);
                } else {
                  if (isExclusive) sel.clear();
                  sel.add(node.name);
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected.contains(node.name)
                    ? AppColors.orange500
                    : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected.contains(node.name)
                      ? AppColors.orange500
                      : AppColors.zinc200,
                ),
              ),
              child: Text(
                node.name,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: selected.contains(node.name)
                      ? Colors.white
                      : AppColors.zinc600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _checkbox(bool checked, {double size = 20}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: checked ? AppColors.orange500 : Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: checked ? AppColors.orange500 : AppColors.zinc300,
          width: 2,
        ),
      ),
      child: checked
          ? Icon(Icons.check, size: size - 6, color: Colors.white)
          : null,
    );
  }
}
