import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nx_cooking/core/theme/app_theme.dart';
import 'package:nx_cooking/domain/recipe_filter.dart';
import 'package:nx_cooking/domain/schema/model_type_view.dart';
import 'package:nx_cooking/domain/search_result.dart';

/// Bottom sheet: filter recipes by tags and ingredients (KGQL).
class RecipeTagFilterSheet extends StatefulWidget {
  const RecipeTagFilterSheet({
    super.key,
    required this.schema,
    required this.ingredients,
    required this.initial,
    required this.onApply,
  });

  final ModelTypeView schema;
  final List<CookingItemEntry> ingredients;
  final RecipeFilter? initial;
  final void Function(RecipeFilter?) onApply;

  @override
  State<RecipeTagFilterSheet> createState() => _RecipeTagFilterSheetState();
}

class _RecipeTagFilterSheetState extends State<RecipeTagFilterSheet> {
  late Map<String, Set<String>> _tagSelections;
  final Set<int> _ingredientSelection = {};
  String _ingredientQuery = '';
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
    if (existing?.ingredientFilters != null) {
      for (final row in existing!.ingredientFilters!) {
        final id = row['id'];
        if (id is int) {
          _ingredientSelection.add(id);
        } else if (id != null) {
          final parsed = int.tryParse(id.toString());
          if (parsed != null) _ingredientSelection.add(parsed);
        }
      }
    }
    for (final ts in widget.schema.tagSystems) {
      if ((_tagSelections[ts.name] ?? {}).isNotEmpty) {
        _expandedSections.add('tag:${ts.name}');
      }
    }
    if (_ingredientSelection.isNotEmpty) {
      _expandedSections.add('ingredients');
    }
  }

  void _reset() {
    setState(() {
      _tagSelections.clear();
      _ingredientSelection.clear();
      _ingredientQuery = '';
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
    final ingFilters = <Map<String, dynamic>>[];
    for (final id in _ingredientSelection) {
      String name = '';
      for (final e in widget.ingredients) {
        if (e.id == id) {
          name = e.name;
          break;
        }
      }
      ingFilters.add({'id': id, 'name': name});
    }
    final f = RecipeFilter(
      tagFilters: tagFilters.isEmpty ? null : tagFilters,
      ingredientFilters: ingFilters.isEmpty ? null : ingFilters,
    );
    widget.onApply(f.isEmpty ? null : f);
    Navigator.pop(context);
  }

  Widget _ingredientsSection() {
    final key = 'ingredients';
    final isExpanded = _expandedSections.contains(key);
    final q = _ingredientQuery.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.ingredients
        : widget.ingredients
              .where((e) => e.name.toLowerCase().contains(q))
              .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  'INGREDIENTS',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: AppColors.zinc400,
                  ),
                ),
                if (_ingredientSelection.isNotEmpty) ...[
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
                      '${_ingredientSelection.length}',
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
        if (isExpanded) ...[
          TextField(
            onChanged: (v) => setState(() => _ingredientQuery = v),
            decoration: InputDecoration(
              hintText: 'Search ingredients…',
              hintStyle: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.zinc400,
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              filled: true,
              fillColor: AppColors.zinc50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.zinc200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.zinc200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppColors.orange500,
                  width: 1.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in filtered)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_ingredientSelection.contains(e.id)) {
                        _ingredientSelection.remove(e.id);
                      } else {
                        _ingredientSelection.add(e.id);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _ingredientSelection.contains(e.id)
                          ? AppColors.orange500
                          : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _ingredientSelection.contains(e.id)
                            ? AppColors.orange500
                            : AppColors.zinc200,
                      ),
                    ),
                    child: Text(
                      e.name,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _ingredientSelection.contains(e.id)
                            ? Colors.white
                            : AppColors.zinc600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No matches',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.zinc400,
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
        const Divider(height: 1, color: AppColors.zinc100),
      ],
    );
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
                  'Filter recipes',
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
            child: (tagSystems.isEmpty && widget.ingredients.isEmpty)
                ? Center(
                    child: Text(
                      'No tag systems or catalog ingredients yet.\n'
                      'Add tag systems from the menu (Tags).',
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
                      if (widget.ingredients.isNotEmpty) _ingredientsSection(),
                      if (tagSystems.isEmpty && widget.ingredients.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 16),
                          child: Text(
                            'No tag systems yet. Add them from the menu (Tags).',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.zinc400,
                            ),
                          ),
                        ),
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
                      color: depth == 0 ? AppColors.zinc900 : AppColors.zinc700,
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
