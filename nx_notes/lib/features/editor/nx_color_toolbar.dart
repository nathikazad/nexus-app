import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:nx_notes/core/theme/app_theme.dart';

const _nxTextColorItemId = 'nx.textColor';
const _nxHighlightColorItemId = 'nx.highlightColor';

ToolbarItem buildNxTextColorItem({List<ColorOption>? colorOptions}) {
  return _buildNxColorItem(
    id: _nxTextColorItemId,
    tooltip: AppFlowyEditorL10n.current.textColor,
    isTextColor: true,
    icon: Icons.format_color_text,
    options: colorOptions,
  );
}

ToolbarItem buildNxHighlightColorItem({List<ColorOption>? colorOptions}) {
  return _buildNxColorItem(
    id: _nxHighlightColorItemId,
    tooltip: AppFlowyEditorL10n.current.highlightColor,
    isTextColor: false,
    icon: Icons.format_color_fill,
    options: colorOptions,
  );
}

ToolbarItem _buildNxColorItem({
  required String id,
  required String tooltip,
  required bool isTextColor,
  required IconData icon,
  required List<ColorOption>? options,
}) {
  return ToolbarItem(
    id: id,
    group: 4,
    isActive: onlyShowInTextType,
    builder: (context, editorState, highlightColor, iconColor, tooltipBuilder) {
      final selection = editorState.selection!.normalized;
      final attribute = isTextColor
          ? AppFlowyRichTextKeys.textColor
          : AppFlowyRichTextKeys.backgroundColor;
      final selectedColorHex = _selectedColorHex(
        editorState: editorState,
        selection: selection,
        attribute: attribute,
      );
      final showClearButton = _selectionHasColorAttribute(
        editorState: editorState,
        selection: selection,
        attribute: attribute,
      );
      final child = _NxCompactColorToolbarButton(
        icon: icon,
        iconColor: iconColor ?? Colors.white,
        selectedColor: _toolbarSwatchColor(
          selectedColorHex,
          isTextColor: isTextColor,
        ),
        hasSelectedColor: selectedColorHex != null,
        isTextColor: isTextColor,
        onPressed: () {
          _showNxCompactColorMenu(
            context: context,
            editorState: editorState,
            selection: selection,
            selectedColorHex: selectedColorHex,
            isTextColor: isTextColor,
            showClearButton: showClearButton,
            options: options,
          );
        },
      );

      if (tooltipBuilder == null) {
        return child;
      }
      return tooltipBuilder(context, id, tooltip, child);
    },
  );
}

String? _selectedColorHex({
  required EditorState editorState,
  required Selection selection,
  required String attribute,
}) {
  String? colorHex;
  final nodes = editorState.getNodesInSelection(selection);
  final allTextHasColor = nodes.allSatisfyInSelection(selection, (delta) {
    if (delta.everyAttributes((attributes) => attributes.isEmpty)) {
      return false;
    }
    return delta.everyAttributes((attributes) {
      final value = attributes[attribute];
      if (value is String && value.trim().isNotEmpty) {
        colorHex ??= value;
        return true;
      }
      return false;
    });
  });
  return allTextHasColor ? colorHex : null;
}

bool _selectionHasColorAttribute({
  required EditorState editorState,
  required Selection selection,
  required String attribute,
}) {
  final nodes = editorState.getNodesInSelection(selection);
  var hasColor = false;
  nodes.allSatisfyInSelection(selection, (delta) {
    if (!hasColor) {
      hasColor = delta.whereType<TextInsert>().any((element) {
        return element.attributes?[attribute] != null;
      });
    }
    return true;
  });
  return hasColor;
}

Color _toolbarSwatchColor(String? colorHex, {required bool isTextColor}) {
  final parsed = colorHex?.tryToColor();
  if (parsed != null) return parsed;
  return isTextColor ? Colors.white : Colors.transparent;
}

void _showNxCompactColorMenu({
  required BuildContext context,
  required EditorState editorState,
  required Selection selection,
  required String? selectedColorHex,
  required bool isTextColor,
  required bool showClearButton,
  required List<ColorOption>? options,
}) {
  final rects = editorState.selectionRects();
  if (rects.isEmpty || editorState.renderBox == null) return;

  final rect = rects.first;
  final left = rect.left + 10;
  double? top;
  double? bottom;
  final offset = rect.center;
  final editorOffset = editorState.renderBox!.localToGlobal(Offset.zero);
  final editorHeight = editorState.renderBox!.size.height;
  final threshold = editorOffset.dy + editorHeight - 190;
  if (offset.dy > threshold) {
    bottom = editorOffset.dy + editorHeight - rect.top - 5;
  } else {
    top = rect.bottom + 5;
  }

  OverlayEntry? overlay;
  var holdsFocus = false;
  void releaseFocus() {
    if (!holdsFocus) return;
    holdsFocus = false;
    keepEditorFocusNotifier.decrease();
  }

  void dismissOverlay() {
    overlay?.remove();
    overlay = null;
    releaseFocus();
  }

  holdsFocus = true;
  keepEditorFocusNotifier.increase();
  overlay = FullScreenOverlayEntry(
    top: top,
    bottom: bottom,
    left: left,
    dismissCallback: releaseFocus,
    builder: (context) {
      return _NxCompactColorMenu(
        selectedColorHex: selectedColorHex,
        showClearButton: showClearButton,
        options:
            options ??
            (isTextColor
                ? generateTextColorOptions()
                : generateHighlightColorOptions()),
        onSelected: (colorHex) {
          if (isTextColor) {
            formatFontColor(
              editorState,
              selection,
              colorHex,
              withUpdateSelection: true,
            );
          } else {
            formatHighlightColor(
              editorState,
              selection,
              colorHex,
              withUpdateSelection: true,
            );
          }
          dismissOverlay();
        },
      );
    },
  ).build();
  Overlay.of(context, rootOverlay: true).insert(overlay!);
}

class _NxCompactColorToolbarButton extends StatelessWidget {
  const _NxCompactColorToolbarButton({
    required this.icon,
    required this.iconColor,
    required this.selectedColor,
    required this.hasSelectedColor,
    required this.isTextColor,
    required this.onPressed,
  });

  final IconData icon;
  final Color iconColor;
  final Color selectedColor;
  final bool hasSelectedColor;
  final bool isTextColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 30,
      child: IconButton(
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Positioned(top: 4, child: Icon(icon, size: 17, color: iconColor)),
            Positioned(
              bottom: 4,
              child: _NxColorSwatch(
                color: selectedColor,
                selected: hasSelectedColor,
                clear: !isTextColor && !hasSelectedColor,
                size: const Size(15, 5),
                radius: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NxCompactColorMenu extends StatelessWidget {
  const _NxCompactColorMenu({
    required this.selectedColorHex,
    required this.showClearButton,
    required this.options,
    required this.onSelected,
  });

  final String? selectedColorHex;
  final bool showClearButton;
  final List<ColorOption> options;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      if (showClearButton)
        _NxColorSwatchButton(
          color: Colors.transparent,
          clear: true,
          selected: selectedColorHex == null,
          onTap: () => onSelected(null),
        ),
      for (final option in options)
        _NxColorSwatchButton(
          color: option.colorHex.tryToColor() ?? Colors.transparent,
          clear: false,
          selected: option.colorHex == selectedColorHex,
          onTap: () => onSelected(option.colorHex),
        ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SizedBox(
          width: 112,
          child: Wrap(spacing: 8, runSpacing: 8, children: children),
        ),
      ),
    );
  }
}

class _NxColorSwatchButton extends StatelessWidget {
  const _NxColorSwatchButton({
    required this.color,
    required this.clear,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool clear;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: _NxColorSwatch(
            color: color,
            selected: selected,
            clear: clear,
            size: const Size.square(26),
            radius: 13,
          ),
        ),
      ),
    );
  }
}

class _NxColorSwatch extends StatelessWidget {
  const _NxColorSwatch({
    required this.color,
    required this.selected,
    required this.clear,
    required this.size,
    required this.radius,
  });

  final Color color;
  final bool selected;
  final bool clear;
  final Size size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: size,
      painter: _NxColorSwatchPainter(
        color: color,
        selected: selected,
        clear: clear,
        radius: radius,
      ),
    );
  }
}

class _NxColorSwatchPainter extends CustomPainter {
  const _NxColorSwatchPainter({
    required this.color,
    required this.selected,
    required this.clear,
    required this.radius,
  });

  final Color color;
  final bool selected;
  final bool clear;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final fill = Paint()
      ..color = clear ? Colors.white : color
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, fill);

    final border = Paint()
      ..color = selected ? AppColors.text : AppColors.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 2 : 1;
    canvas.drawRRect(rrect.deflate(selected ? 1 : 0.5), border);

    if (clear) {
      final slash = Paint()
        ..color = AppColors.red
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(size.width * 0.25, size.height * 0.75),
        Offset(size.width * 0.75, size.height * 0.25),
        slash,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NxColorSwatchPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.selected != selected ||
        oldDelegate.clear != clear ||
        oldDelegate.radius != radius;
  }
}
