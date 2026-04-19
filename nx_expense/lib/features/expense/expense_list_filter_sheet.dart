import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nx_expense/core/theme/app_theme.dart';
import 'package:nx_expense/domain/expense/expense_filter.dart';
import 'package:nx_expense/domain/expense/related_model.dart';
import 'package:nx_expense/domain/schema/model_type_view.dart';

class ActiveFilterChips extends StatelessWidget {
  const ActiveFilterChips({
    super.key,
    required this.filter,
    required this.schema,
    required this.onClearAll,
    required this.onRemoveTag,
    required this.onRemoveMinAmount,
    required this.onRemoveMaxAmount,
    required this.onRemoveRelation,
  });

  final ExpenseFilter filter;
  final ModelTypeView schema;
  final VoidCallback onClearAll;
  final void Function(int index) onRemoveTag;
  final VoidCallback onRemoveMinAmount;
  final VoidCallback onRemoveMaxAmount;
  final void Function(String relType, int modelId) onRemoveRelation;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (filter.tagFilters != null)
            for (var i = 0; i < filter.tagFilters!.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: chipWidget(
                  tagFilterLabel(filter.tagFilters![i]),
                  () => onRemoveTag(i),
                ),
              ),
          if (filter.minAmount != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: chipWidget(
                'Min \$${filter.minAmount!.toStringAsFixed(0)}',
                onRemoveMinAmount,
              ),
            ),
          if (filter.maxAmount != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: chipWidget(
                'Max \$${filter.maxAmount!.toStringAsFixed(0)}',
                onRemoveMaxAmount,
              ),
            ),
          if (filter.relationFilters != null)
            for (final entry in filter.relationFilters!.entries)
              for (final id in entry.value)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: chipWidget(
                    '${entry.key}: ${filter.relationFilterLabels?[entry.key]?[id] ?? '#$id'}',
                    () => onRemoveRelation(entry.key, id),
                  ),
                ),
          GestureDetector(
            onTap: onClearAll,
            child: Center(
              child: Text(
                'Clear all',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.slate400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget chipWidget(String label, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF99F6E4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.teal700,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 14, color: AppColors.teal500),
          ),
        ],
      ),
    );
  }

  String tagFilterLabel(Map<String, dynamic> tf) {
    final system = tf['system'] as String? ?? '';
    final node = tf['node'] as String? ?? '';
    return '$system: $node';
  }
}

class FilterSheet extends StatefulWidget {
  const FilterSheet({
    super.key,
    required this.schema,
    required this.initial,
    required this.allRelationModels,
    required this.onApply,
  });

  final ModelTypeView schema;
  final ExpenseFilter? initial;
  final Map<String, List<RelatedModel>> allRelationModels;
  final void Function(ExpenseFilter?) onApply;

  @override
  State<FilterSheet> createState() => FilterSheetState();
}

class FilterSheetState extends State<FilterSheet> {
  late Map<String, Set<String>> _tagSelections;
  final _minController = TextEditingController();
  final _maxController = TextEditingController();
  final Map<String, Set<String>> _expandedNodes = {};

  late Map<String, Set<int>> _relationSelections;
  final Map<String, String> _relationSearchQueries = {};
  final Map<String, TextEditingController> _relationSearchControllers = {};
  final Map<String, Map<int, String>> _relationSelectedNames = {};

  final Set<String> _expandedSections = {};

  @override
  void initState() {
    super.initState();
    _tagSelections = {};
    _relationSelections = {};
    final existing = widget.initial;
    if (existing?.tagFilters != null) {
      for (final tf in existing!.tagFilters!) {
        final system = tf['system'] as String? ?? '';
        final node = tf['node'] as String? ?? '';
        _tagSelections.putIfAbsent(system, () => {}).add(node);
      }
    }
    if (existing?.minAmount != null) {
      _minController.text = existing!.minAmount!.toStringAsFixed(0);
    }
    if (existing?.maxAmount != null) {
      _maxController.text = existing!.maxAmount!.toStringAsFixed(0);
    }
    if (existing?.relationFilters != null) {
      for (final entry in existing!.relationFilters!.entries) {
        _relationSelections[entry.key] = Set.from(entry.value);
        final models = widget.allRelationModels[entry.key] ?? [];
        final names = <int, String>{};
        for (final id in entry.value) {
          final match = models.where((m) => m.id == id);
          final m = match.isEmpty ? null : match.first;
          if (m != null) names[id] = m.name;
        }
        _relationSelectedNames[entry.key] = names;
      }
    }
    for (final ts in widget.schema.tagSystems) {
      if ((_tagSelections[ts.name] ?? {}).isNotEmpty) {
        _expandedSections.add('tag:${ts.name}');
      }
    }
    if (_minController.text.isNotEmpty || _maxController.text.isNotEmpty) {
      _expandedSections.add('amount');
    }
    for (final entry in _relationSelections.entries) {
      if (entry.value.isNotEmpty) {
        _expandedSections.add('rel:${entry.key}');
      }
    }
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    for (final c in _relationSearchControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _reset() {
    setState(() {
      _tagSelections.clear();
      _minController.clear();
      _maxController.clear();
      _relationSelections.clear();
      _relationSelectedNames.clear();
      _relationSearchQueries.clear();
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

    final minAmt = double.tryParse(_minController.text);
    final maxAmt = double.tryParse(_maxController.text);

    Map<String, Set<int>>? relFilters;
    Map<String, Map<int, String>>? relLabels;
    if (_relationSelections.isNotEmpty) {
      relFilters = Map.from(_relationSelections);
      relFilters.removeWhere((_, ids) => ids.isEmpty);
      if (relFilters.isEmpty) relFilters = null;
      if (relFilters != null) {
        relLabels = {};
        for (final entry in relFilters.entries) {
          final names = _relationSelectedNames[entry.key];
          if (names == null) continue;
          final m = <int, String>{};
          for (final id in entry.value) {
            final n = names[id];
            if (n != null) m[id] = n;
          }
          if (m.isNotEmpty) relLabels[entry.key] = m;
        }
        if (relLabels.isEmpty) relLabels = null;
      }
    }

    final filter = ExpenseFilter(
      tagFilters: tagFilters.isEmpty ? null : tagFilters,
      minAmount: minAmt,
      maxAmount: maxAmt,
      relationFilters: relFilters,
      relationFilterLabels: relLabels,
    );

    widget.onApply(filter);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final tagSystems = widget.schema.tagSystems;
    final relationNames = allRelationTargetTypeNames(widget.schema);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.slate200,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Filters',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate900,
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
                      color: AppColors.slate400,
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
                      color: AppColors.teal600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.slate100),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                for (final ts in tagSystems)
                  collapsibleSection(
                    key: 'tag:${ts.name}',
                    title: ts.name,
                    selectedCount: (_tagSelections[ts.name] ?? {}).length,
                    child: ts.isHierarchical
                        ? buildHierarchicalContent(ts)
                        : buildFlatContent(ts),
                  ),
                collapsibleSection(
                  key: 'amount',
                  title: 'Amount',
                  selectedCount:
                      (_minController.text.isNotEmpty ? 1 : 0) +
                      (_maxController.text.isNotEmpty ? 1 : 0),
                  child: buildAmountContent(),
                ),
                for (final relName in relationNames)
                  collapsibleSection(
                    key: 'rel:$relName',
                    title: relName,
                    selectedCount: (_relationSelections[relName] ?? {}).length,
                    child: buildRelationContent(relName),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget collapsibleSection({
    required String key,
    required String title,
    required int selectedCount,
    required Widget child,
  }) {
    final isExpanded = _expandedSections.contains(key);
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
                  title.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: AppColors.slate400,
                  ),
                ),
                if (selectedCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.teal600,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$selectedCount',
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
                  color: AppColors.slate400,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: child),
        const Divider(height: 1, color: AppColors.slate100),
      ],
    );
  }

  Widget buildHierarchicalContent(TagSystemView ts) {
    final selected = _tagSelections[ts.name] ?? {};
    final expanded = _expandedNodes.putIfAbsent(ts.name, () => {});
    return Container(
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.slate100, width: 2)),
      ),
      padding: const EdgeInsets.only(left: 12),
      child: Column(
        children: [
          for (final node in ts.nodes)
            buildTreeNode(ts, node, selected, expanded, depth: 0),
        ],
      ),
    );
  }

  Widget buildTreeNode(
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
                checkbox(isSelected, size: depth == 0 ? 20.0 : 18.0),
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
                          ? AppColors.slate900
                          : AppColors.slate700,
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
                      color: AppColors.slate300,
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
                left: BorderSide(color: AppColors.slate100, width: 2),
              ),
            ),
            padding: const EdgeInsets.only(left: 12),
            child: Column(
              children: [
                for (final child in node.children!)
                  buildTreeNode(
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

  Widget buildFlatContent(TagSystemView ts) {
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
                    ? AppColors.teal600
                    : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected.contains(node.name)
                      ? AppColors.teal600
                      : AppColors.slate200,
                ),
              ),
              child: Text(
                node.name,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: selected.contains(node.name)
                      ? Colors.white
                      : AppColors.slate600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget buildAmountContent() {
    final fieldStyle = GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: AppColors.slate900,
    );
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Min',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.slate400,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _minController,
                keyboardType: TextInputType.number,
                style: fieldStyle,
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  prefixStyle: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.slate400,
                  ),
                  hintText: '0',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.slate200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.slate200),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Max',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.slate400,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _maxController,
                keyboardType: TextInputType.number,
                style: fieldStyle,
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  prefixStyle: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.slate400,
                  ),
                  hintText: 'No limit',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.slate200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.slate200),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildRelationContent(String relName) {
    final allModels = widget.allRelationModels[relName] ?? [];
    final selectedIds = _relationSelections[relName] ?? {};
    final selectedNames = _relationSelectedNames[relName] ?? {};
    final query = (_relationSearchQueries[relName] ?? '').toLowerCase();
    final searchController = _relationSearchControllers.putIfAbsent(
      relName,
      () => TextEditingController(),
    );

    final candidates =
        allModels.where((m) => !selectedIds.contains(m.id)).toList()..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

    final suggestions = query.isEmpty
        ? candidates.take(20).toList()
        : candidates
              .where((m) => m.name.toLowerCase().contains(query))
              .take(20)
              .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: searchController,
          onChanged: (v) => setState(() {
            _relationSearchQueries[relName] = v;
          }),
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.slate900),
          decoration: InputDecoration(
            hintText: 'Search ${relName.toLowerCase()}...',
            hintStyle: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.slate300,
            ),
            prefixIcon: const Icon(
              Icons.search,
              size: 20,
              color: AppColors.slate400,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.slate200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.slate200),
            ),
          ),
        ),

        if (suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.slate200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                for (var i = 0; i < suggestions.length; i++) ...[
                  InkWell(
                    onTap: () {
                      setState(() {
                        final ids = _relationSelections.putIfAbsent(
                          relName,
                          () => {},
                        );
                        ids.add(suggestions[i].id);
                        final names = _relationSelectedNames.putIfAbsent(
                          relName,
                          () => {},
                        );
                        names[suggestions[i].id] = suggestions[i].name;
                        _relationSearchQueries[relName] = '';
                        searchController.clear();
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              suggestions[i].name,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppColors.slate700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (i < suggestions.length - 1)
                    const Divider(height: 1, color: AppColors.slate100),
                ],
              ],
            ),
          ),

        if (selectedIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final id in selectedIds)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDFA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF99F6E4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          selectedNames[id] ?? '#$id',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.teal700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _relationSelections[relName]?.remove(id);
                              _relationSelectedNames[relName]?.remove(id);
                            });
                          },
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: AppColors.teal500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget checkbox(bool checked, {double size = 20}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: checked ? AppColors.teal600 : Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: checked ? AppColors.teal600 : AppColors.slate300,
          width: 2,
        ),
      ),
      child: checked
          ? Icon(Icons.check, size: size - 6, color: Colors.white)
          : null,
    );
  }
}
