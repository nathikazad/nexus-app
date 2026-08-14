import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class NxReadTableBlockComponentBuilder extends BlockComponentBuilder {
  @override
  BlockComponentWidget build(BlockComponentContext context) {
    return _NxReadTableBlockComponentWidget(
      key: context.node.key,
      node: context.node,
      configuration: configuration,
    );
  }

  @override
  BlockComponentValidate get validate => (node) {
    final columns = node.attributes[TableBlockKeys.colsLen];
    final rows = node.attributes[TableBlockKeys.rowsLen];
    return columns is int &&
        rows is int &&
        columns > 0 &&
        rows > 0 &&
        node.children.isNotEmpty;
  };
}

class _NxReadTableBlockComponentWidget extends BlockComponentStatefulWidget {
  const _NxReadTableBlockComponentWidget({
    required super.node,
    required super.configuration,
    super.key,
  });

  @override
  State<_NxReadTableBlockComponentWidget> createState() =>
      _NxReadTableBlockComponentWidgetState();
}

class _NxReadTableBlockComponentWidgetState
    extends State<_NxReadTableBlockComponentWidget>
    with SelectableMixin, BlockComponentConfigurable {
  final _tableKey = GlobalKey(debugLabel: 'nx_read_table');

  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  RenderBox? get _renderBox => context.findRenderObject() as RenderBox?;

  @override
  Widget build(BuildContext context) {
    final editorState = context.read<EditorState>();
    final columns = node.attributes[TableBlockKeys.colsLen] as int;
    final rows = node.attributes[TableBlockKeys.rowsLen] as int;
    final cells = <(int, int), Node>{
      for (final cell in node.children)
        if (cell.attributes[TableCellBlockKeys.colPosition] is int &&
            cell.attributes[TableCellBlockKeys.rowPosition] is int)
          (
            cell.attributes[TableCellBlockKeys.colPosition] as int,
            cell.attributes[TableCellBlockKeys.rowPosition] as int,
          ): cell,
    };
    final baseStyle = editorState.editorStyle.textStyleConfiguration.text;
    final tableTextStyle = baseStyle.copyWith(
      fontSize:
          (baseStyle.fontSize ?? 16) * editorState.editorStyle.textScaleFactor,
      height: 1.35,
    );

    Widget child = Padding(
      key: _tableKey,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Table(
        key: const ValueKey<String>('nx-read-table'),
        columnWidths: <int, TableColumnWidth>{
          for (var column = 0; column < columns; column++)
            column: const FlexColumnWidth(),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        border: TableBorder.all(color: Theme.of(context).dividerColor),
        children: <TableRow>[
          for (var row = 0; row < rows; row++)
            TableRow(
              children: <Widget>[
                for (var column = 0; column < columns; column++)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Text(
                      _cellText(cells[(column, row)]),
                      style: row == 0
                          ? tableTextStyle.copyWith(fontWeight: FontWeight.w700)
                          : tableTextStyle,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
    child = BlockSelectionContainer(
      node: node,
      delegate: this,
      listenable: editorState.selectionNotifier,
      remoteSelection: editorState.remoteSelections,
      blockColor: editorState.editorStyle.selectionColor,
      supportTypes: const <BlockSelectionType>[BlockSelectionType.block],
      child: child,
    );
    return child;
  }

  @override
  Position start() => Position(path: node.path, offset: 0);

  @override
  Position end() => Position(path: node.path, offset: 1);

  @override
  Position getPositionInOffset(Offset offset) => end();

  @override
  List<Rect> getRectsInSelection(
    Selection selection, {
    bool shiftWithBaseOffset = false,
  }) {
    final parentBox = _renderBox;
    final tableBox = _tableKey.currentContext?.findRenderObject();
    if (parentBox != null && tableBox is RenderBox) {
      return <Rect>[
        (shiftWithBaseOffset
                ? tableBox.localToGlobal(Offset.zero, ancestor: parentBox)
                : Offset.zero) &
            tableBox.size,
      ];
    }
    return <Rect>[Offset.zero & (parentBox?.size ?? Size.zero)];
  }

  @override
  Selection getSelectionInRange(Offset start, Offset end) {
    return Selection.single(path: node.path, startOffset: 0, endOffset: 1);
  }

  @override
  bool get shouldCursorBlink => false;

  @override
  CursorStyle get cursorStyle => CursorStyle.cover;

  @override
  Offset localToGlobal(Offset offset, {bool shiftWithBaseOffset = false}) {
    return _renderBox?.localToGlobal(offset) ?? offset;
  }

  @override
  Rect getBlockRect({bool shiftWithBaseOffset = false}) {
    return getRectsInSelection(Selection.invalid()).first;
  }

  @override
  Rect? getCursorRectInPosition(
    Position position, {
    bool shiftWithBaseOffset = false,
  }) {
    final size = _renderBox?.size;
    return size == null
        ? null
        : Rect.fromLTWH(-size.width / 2, 0, size.width, size.height);
  }
}

String _cellText(Node? cell) {
  if (cell == null) return '';
  final parts = <String>[];

  void collect(Node node) {
    final text = node.delta?.toPlainText().trim() ?? '';
    if (text.isNotEmpty) parts.add(text);
    for (final child in node.children) {
      collect(child);
    }
  }

  for (final child in cell.children) {
    collect(child);
  }
  return parts.join('\n');
}
