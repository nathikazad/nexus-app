import 'package:flutter/material.dart';

import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/core/theme/action_color_palette.dart';
import 'package:nx_time/features/action_edit/action_category_option.dart';

/// Category picker: pass options from [actionCategoryOptionsProvider] in
/// `action_edit_providers.dart` (DB-backed; subtype list from [actionSubtypeModelTypesProvider] in data layer).
Future<ActionCategoryOption?> showActionCategoryPicker(
  BuildContext context, {
  required List<ActionCategoryOption> categories,
  ActionCategoryOption? selected,
}) {
  return showModalBottomSheet<ActionCategoryOption>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) =>
        _CategoryPickerBody(categories: categories, selected: selected),
  );
}

class _CategoryPickerBody extends StatefulWidget {
  const _CategoryPickerBody({required this.categories, this.selected});

  final List<ActionCategoryOption> categories;
  final ActionCategoryOption? selected;

  @override
  State<_CategoryPickerBody> createState() => _CategoryPickerBodyState();
}

class _CategoryPickerBodyState extends State<_CategoryPickerBody> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<ActionCategoryOption> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return widget.categories;
    return widget.categories
        .where((c) => c.name.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final screenH = MediaQuery.sizeOf(context).height;

    /// Fixed allocation for rows so the sheet height does not change when the
    /// filtered list shrinks or is empty (content scrolls inside).
    final listAreaHeight = screenH * 0.42;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.slate200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Select type',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.slate900,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search types…',
                    hintStyle: const TextStyle(
                      fontSize: 14,
                      color: AppColors.slate400,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.slate200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.slate200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.sky600),
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.slate900,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: listAreaHeight,
                  child: widget.categories.isEmpty
                      ? const Center(
                          child: Text(
                            'No action types loaded. Check connection and try again.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.slate500,
                            ),
                          ),
                        )
                      : _filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'No types match your search.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.slate500,
                            ),
                          ),
                        )
                      : ListView(
                          children: [
                            for (final c in _filtered)
                              _CategoryRow(
                                option: c,
                                isSelected:
                                    widget.selected?.modelTypeId ==
                                    c.modelTypeId,
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.option, required this.isSelected});

  final ActionCategoryOption option;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final style = categoryPillStyleFromBarColor(option.dotColor);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: isSelected ? style.background : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => Navigator.of(context).pop(option),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: option.dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    option.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w500
                          : FontWeight.w400,
                      color: isSelected ? style.foreground : AppColors.slate900,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check, size: 16, color: style.foreground),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
