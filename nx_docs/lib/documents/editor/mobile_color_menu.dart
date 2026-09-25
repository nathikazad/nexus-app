import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:nx_docs/app/theme.dart';

MobileToolbarItem buildNxMobileColorItem() => MobileToolbarItem.withMenu(
  itemIconBuilder: (context, _, _) => Tooltip(
    message: 'Text color and highlight',
    child: AFMobileIcon(
      afMobileIcons: AFMobileIcons.color,
      color: AppColors.text,
    ),
  ),
  itemMenuBuilder: (_, state, _) {
    final selection = state.selection;
    return selection == null
        ? const SizedBox.shrink()
        : _MobileColorMenu(editorState: state, selection: selection);
  },
);

class _MobileColorMenu extends StatefulWidget {
  const _MobileColorMenu({required this.editorState, required this.selection});

  final EditorState editorState;
  final Selection selection;

  @override
  State<_MobileColorMenu> createState() => _MobileColorMenuState();
}

class _MobileColorMenuState extends State<_MobileColorMenu> {
  bool _highlight = false;

  String get _attribute => _highlight
      ? AppFlowyRichTextKeys.backgroundColor
      : AppFlowyRichTextKeys.textColor;

  bool _isSelected(String? color) {
    final state = widget.editorState;
    final selection = widget.selection;
    if (selection.isCollapsed) {
      if (state.toggledStyle.containsKey(_attribute)) {
        return state.toggledStyle[_attribute] == color;
      }
      final delta = state.getNodeAtPath(selection.start.path)?.delta;
      if (delta == null || delta.isEmpty) return color == null;
      final index = (selection.start.offset - 1).clamp(0, delta.length - 1);
      return delta
          .slice(index, index + 1)
          .everyAttributes((attributes) => attributes[_attribute] == color);
    }
    return state
        .getNodesInSelection(selection)
        .allSatisfyInSelection(
          selection,
          (delta) => delta.everyAttributes(
            (attributes) => attributes[_attribute] == color,
          ),
        );
  }

  Future<void> _apply(String? color) async {
    final state = widget.editorState;
    if (state.isDisposed) return;
    if (widget.selection.isCollapsed) {
      // formatDelta intentionally ignores carets. The IME consumes toggledStyle
      // for the next insertion, including null to clear an inherited color.
      state.updateToggledStyle(_attribute, color);
    } else {
      await state.formatDelta(widget.selection, {
        _attribute: color,
      }, withUpdateSelection: false);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final textOptions = generateTextColorOptions();
    final options = _highlight ? generateHighlightColorOptions() : textOptions;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (final highlight in [false, true])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: TextButton(
                    key: ValueKey(
                      highlight
                          ? 'mobile-highlight-tab'
                          : 'mobile-text-color-tab',
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.text,
                      backgroundColor: _highlight == highlight
                          ? AppColors.hover
                          : AppColors.panel,
                      minimumSize: const Size(0, 44),
                    ),
                    onPressed: () => setState(() => _highlight = highlight),
                    child: Text(highlight ? 'Highlight' : 'Text Color'),
                  ),
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            widget.selection.isCollapsed
                ? 'Applies to new text'
                : 'Applies to selected text',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _choice('Default', null, constraints.maxWidth),
              for (var i = 0; i < options.length; i++)
                _choice(
                  textOptions[i].name,
                  options[i].colorHex,
                  constraints.maxWidth,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _choice(String name, String? hex, double width) {
    final selected = _isSelected(hex);
    return SizedBox(
      width: (width - 16) / 3,
      child: Semantics(
        selected: selected,
        child: OutlinedButton(
          key: ValueKey('mobile-${_highlight ? 'highlight' : 'text'}-$name'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.text,
            backgroundColor: selected ? AppColors.subtle : AppColors.panel,
            side: BorderSide(
              color: selected ? AppColors.blue : AppColors.line,
              width: selected ? 2 : 1,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: const Size(0, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          onPressed: () => _apply(hex),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (hex == null)
                Icon(Icons.format_color_reset, size: 16, color: AppColors.text)
              else
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: hex.tryToColor(),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.muted),
                  ),
                ),
              const SizedBox(width: 5),
              Flexible(child: Text(name, style: const TextStyle(fontSize: 12))),
            ],
          ),
        ),
      ),
    );
  }
}
