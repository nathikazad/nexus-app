part of 'nx_appflowy_blocks.dart';

/// A stable, content-first table presentation for stored document tables.
///
/// AppFlowy's editable table widget owns row sizing and editing controls. Those
/// can leave a sized, empty surface when an imported table is opened on macOS.
/// This renderer derives its size from cell content in both document modes;
/// table cells remain presentation-only while the rest of the document can
/// still be edited.
class NxReadTableBlockComponentBuilder extends BlockComponentBuilder {
  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return NxReadTableBlockComponentWidget(
      key: node.key,
      node: node,
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

class NxReadTableBlockComponentWidget extends BlockComponentStatefulWidget {
  const NxReadTableBlockComponentWidget({
    required super.node,
    required super.configuration,
    super.key,
  });

  @override
  State<NxReadTableBlockComponentWidget> createState() =>
      _NxReadTableBlockComponentWidgetState();
}

class _NxReadTableBlockComponentWidgetState
    extends State<NxReadTableBlockComponentWidget>
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
    final columns = widget.node.attributes[TableBlockKeys.colsLen] as int;
    final rows = widget.node.attributes[TableBlockKeys.rowsLen] as int;
    final cells = <(int, int), Node>{
      for (final cell in widget.node.children)
        if (cell.attributes[TableCellBlockKeys.colPosition] is int &&
            cell.attributes[TableCellBlockKeys.rowPosition] is int)
          (
            cell.attributes[TableCellBlockKeys.colPosition] as int,
            cell.attributes[TableCellBlockKeys.rowPosition] as int,
          ): cell,
    };
    final baseStyle = editorState.editorStyle.textStyleConfiguration.text;
    final textScale = editorState.editorStyle.textScaleFactor;
    final tableTextStyle = baseStyle.copyWith(
      fontSize: (baseStyle.fontSize ?? 16) * textScale,
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
        border: TableBorder.all(color: AppColors.line, width: 0.8),
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
                      _nxReadTableCellText(cells[(column, row)]),
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
  Position start() => Position(path: widget.node.path, offset: 0);

  @override
  Position end() => Position(path: widget.node.path, offset: 1);

  @override
  Position getPositionInOffset(Offset start) => end();

  @override
  List<Rect> getRectsInSelection(
    Selection selection, {
    bool shiftWithBaseOffset = false,
  }) {
    final parentBox = context.findRenderObject();
    final tableBox = _tableKey.currentContext?.findRenderObject();
    if (parentBox is RenderBox && tableBox is RenderBox) {
      return <Rect>[
        (shiftWithBaseOffset
                ? tableBox.localToGlobal(Offset.zero, ancestor: parentBox)
                : Offset.zero) &
            tableBox.size,
      ];
    }
    final renderBox = _renderBox;
    return <Rect>[Offset.zero & (renderBox?.size ?? Size.zero)];
  }

  @override
  Selection getSelectionInRange(Offset start, Offset end) =>
      Selection.single(path: widget.node.path, startOffset: 0, endOffset: 1);

  @override
  bool get shouldCursorBlink => false;

  @override
  CursorStyle get cursorStyle => CursorStyle.cover;

  @override
  Offset localToGlobal(Offset offset, {bool shiftWithBaseOffset = false}) =>
      _renderBox?.localToGlobal(offset) ?? offset;

  @override
  Rect getBlockRect({bool shiftWithBaseOffset = false}) =>
      getRectsInSelection(Selection.invalid()).first;

  @override
  Rect? getCursorRectInPosition(
    Position position, {
    bool shiftWithBaseOffset = false,
  }) {
    final size = _renderBox?.size;
    if (size == null) return null;
    return Rect.fromLTWH(-size.width / 2, 0, size.width, size.height);
  }
}

String _nxReadTableCellText(Node? cell) {
  if (cell == null) return '';
  final parts = <String>[];

  void collect(Node node) {
    final text = node.delta?.toPlainText().trim() ?? '';
    if (text.isNotEmpty) {
      parts.add(text);
    } else {
      final customText = nxPlainTextForCustomNode(node).trim();
      if (customText.isNotEmpty) parts.add(customText);
    }
    for (final child in node.children) {
      collect(child);
    }
  }

  for (final child in cell.children) {
    collect(child);
  }
  return parts.join('\n');
}
