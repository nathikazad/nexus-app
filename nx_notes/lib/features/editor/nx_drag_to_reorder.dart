part of 'nx_appflowy_blocks.dart';

enum _DropVerticalPosition { top, bottom }

class NxDragToReorderAction extends StatefulWidget {
  const NxDragToReorderAction({
    required this.blockComponentContext,
    required this.builder,
    super.key,
  });

  final BlockComponentContext blockComponentContext;
  final BlockComponentBuilder builder;

  @override
  State<NxDragToReorderAction> createState() => _NxDragToReorderActionState();
}

const String _reorderInterceptorKey = 'nx_notes_drag_to_reorder';

class _NxDragToReorderActionState extends State<NxDragToReorderAction> {
  late final EditorState editorState = context.read<EditorState>();
  late final Node feedbackNode;
  late final BlockComponentContext feedbackContext;
  Offset? _globalPosition;
  Selection? _beforeSelection;

  late final SelectionGestureInterceptor _gestureInterceptor =
      SelectionGestureInterceptor(
        key: _reorderInterceptorKey,
        canTap: (details) => !_isTapInBounds(details.globalPosition),
      );

  RenderBox? get _renderBox => context.findRenderObject() as RenderBox?;

  @override
  void initState() {
    super.initState();
    editorState.service.selectionService.registerGestureInterceptor(
      _gestureInterceptor,
    );
    feedbackNode = widget.blockComponentContext.node.copyWith();
    feedbackContext = BlockComponentContext(
      widget.blockComponentContext.buildContext,
      feedbackNode,
    );
  }

  @override
  void dispose() {
    editorState.service.selectionService.unregisterGestureInterceptor(
      _reorderInterceptorKey,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 7, right: 4),
      child: Draggable<Node>(
        data: feedbackNode,
        feedback: _buildFeedback(),
        onDragStarted: editorState.selectionService.removeDropTarget,
        onDragUpdate: (details) {
          editorState.selectionService.renderDropTargetForOffset(
            details.globalPosition,
            builder: (context, data) => _buildDropArea(
              context,
              data,
              widget.blockComponentContext.node,
            ),
          );
          _globalPosition = details.globalPosition;
          editorState.scrollService?.startAutoScroll(details.globalPosition);
        },
        onDragEnd: (_) {
          editorState.selectionService.removeDropTarget();
          final position = _globalPosition;
          _globalPosition = null;
          if (position == null) {
            return;
          }
          final data = editorState.selectionService.getDropTargetRenderData(
            position,
          );
          _moveNodeToNewPosition(
            widget.blockComponentContext.node,
            data?.cursorNode?.path,
            position,
          );
        },
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _selectBlock,
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: Icon(
              Icons.drag_indicator_rounded,
              size: 18,
              color: AppColors.faint,
            ),
          ),
        ),
      ),
    );
  }

  void _selectBlock() {
    final path = widget.blockComponentContext.node.path;
    if (_beforeSelection != null && path.inSelection(_beforeSelection)) {
      editorState.updateSelectionWithReason(
        _beforeSelection,
        customSelectionType: SelectionType.block,
      );
      return;
    }
    editorState.updateSelectionWithReason(
      Selection.collapsed(Position(path: path)),
      customSelectionType: SelectionType.block,
    );
  }

  bool _isTapInBounds(Offset offset) {
    final renderBox = _renderBox;
    if (renderBox == null) {
      return false;
    }
    final result = renderBox.paintBounds.contains(
      renderBox.globalToLocal(offset),
    );
    _beforeSelection = result ? editorState.selection : null;
    return result;
  }

  void _moveNodeToNewPosition(
    Node node,
    Path? acceptedPath,
    Offset dragOffset,
  ) {
    if (acceptedPath == null) {
      return;
    }
    final targetNode = editorState.getNodeAtPath(acceptedPath);
    if (targetNode == null) {
      return;
    }
    final position = _getPosition(targetNode, dragOffset);
    if (position == null) {
      return;
    }
    final (verticalPosition, _) = position;
    final newPath = verticalPosition == _DropVerticalPosition.bottom
        ? targetNode.path.next
        : targetNode.path;
    if (_shouldIgnoreDrop(node, newPath)) {
      return;
    }
    final transaction = editorState.transaction..moveNode(newPath, node);
    editorState.apply(transaction);
  }

  Widget _buildFeedback() {
    final child = IntrinsicWidth(
      child: IntrinsicHeight(
        child: Provider.value(
          value: editorState,
          child: widget.builder.build(feedbackContext),
        ),
      ),
    );

    return Opacity(
      opacity: 0.72,
      child: Material(color: Colors.transparent, child: child),
    );
  }
}

Widget _buildDropArea(
  BuildContext context,
  DragAreaBuilderData data,
  Node dragNode,
) {
  final targetNode = data.targetNode;
  if (_shouldIgnoreDrop(dragNode, targetNode.path)) {
    return const SizedBox.shrink();
  }

  final position = _getPosition(targetNode, data.dragOffset);
  if (position == null) {
    return const SizedBox.shrink();
  }
  final (verticalPosition, globalBlockRect) = position;

  return Positioned(
    top: verticalPosition == _DropVerticalPosition.top
        ? globalBlockRect.top
        : globalBlockRect.bottom,
    left: globalBlockRect.left + 22,
    child: Container(
      height: 2,
      width: globalBlockRect.width - 22,
      color: AppColors.blue,
    ),
  );
}

(_DropVerticalPosition, Rect)? _getPosition(
  Node targetNode,
  Offset dragOffset,
) {
  final selectable = targetNode.selectable;
  final renderBox = selectable?.context.findRenderObject() as RenderBox?;
  if (selectable == null || renderBox == null) {
    return null;
  }

  final globalBlockOffset = renderBox.localToGlobal(Offset.zero);
  final globalBlockRect = globalBlockOffset & renderBox.size;
  if (!globalBlockRect.contains(dragOffset)) {
    return null;
  }

  final verticalPosition =
      dragOffset.dy < globalBlockRect.top + globalBlockRect.height / 2
      ? _DropVerticalPosition.top
      : _DropVerticalPosition.bottom;
  return (verticalPosition, globalBlockRect);
}

bool _shouldIgnoreDrop(Node dragNode, Path? targetPath) {
  if (targetPath == null) {
    return true;
  }
  if (dragNode.path.equals(targetPath)) {
    return true;
  }
  if (dragNode.path.isAncestorOf(targetPath)) {
    return true;
  }
  return false;
}
