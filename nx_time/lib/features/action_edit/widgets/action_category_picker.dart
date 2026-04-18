import 'package:flutter/material.dart';

import 'package:nx_time/app_theme.dart';
import 'package:nx_time/core/theme/action_color_palette.dart';
import 'package:nx_time/data/action_category_option.dart';

/// Category picker: pass options from [actionCategoryOptionsProvider] (DB-backed).
Future<ActionCategoryOption?> showActionCategoryPicker(
  BuildContext context, {
  required List<ActionCategoryOption> categories,
  ActionCategoryOption? selected,
}) {
  return showModalBottomSheet<ActionCategoryOption>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CategoryPickerBody(
      categories: categories,
      selected: selected,
    ),
  );
}

class _CategoryPickerBody extends StatelessWidget {
  const _CategoryPickerBody({
    required this.categories,
    this.selected,
  });

  final List<ActionCategoryOption> categories;
  final ActionCategoryOption? selected;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.slate200),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Search types…',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.slate400,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (categories.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No action types loaded. Check connection and try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: AppColors.slate500),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.42,
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final c in categories)
                          _CategoryRow(
                            option: c,
                            isSelected: selected?.modelTypeId == c.modelTypeId,
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
  const _CategoryRow({
    required this.option,
    required this.isSelected,
  });

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
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 10,
            ),
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
                      fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                      color: isSelected ? style.foreground : AppColors.slate900,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check,
                    size: 16,
                    color: style.foreground,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
