part of 'nx_appflowy_blocks.dart';

/// One touch-friendly block action shared by every editor layout.
class NxBlockDeleteControl extends StatelessWidget {
  const NxBlockDeleteControl({
    super.key,
    required this.node,
    required this.editorState,
    required this.enabled,
    required this.child,
  });
  final Node node;
  final EditorState editorState;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled || node.type == PageBlockKeys.type) return child;
    return ValueListenableBuilder<Selection?>(
      valueListenable: editorState.selectionNotifier,
      child: child,
      builder: (context, selection, content) {
        final focused =
            selection != null &&
            (listEquals(selection.start.path, node.path) ||
                listEquals(selection.end.path, node.path));
        final visible = node.delta == null || focused;
        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 44),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: content,
              ),
            ),
            if (visible)
              Positioned(
                top: 0,
                right: 0,
                child: IgnoreEditorSelectionGesture(
                  child: IconButton(
                    key: ValueKey('delete-block-${node.id}'),
                    tooltip: 'Delete block',
                    onPressed: () => _delete(context),
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    icon: Icon(
                      Icons.delete_outline,
                      size: 19,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _delete(BuildContext context) async {
    if (!editorState.editable ||
        editorState.isDisposed ||
        node.parent == null) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final parent = node.parent!;
    final root = editorState.document.root;
    final index = node.path.last;
    final next = index + 1 < parent.children.length
        ? parent.children[index + 1]
        : null;
    final removed = node.copyWith();
    final placeholder = identical(parent, root) && parent.children.length == 1
        ? paragraphNode()
        : null;
    final transaction = editorState.transaction..deleteNode(node);
    if (placeholder != null) {
      transaction.insertNode([0], placeholder, deepCopy: false);
    }
    transaction.afterSelection = null;
    await editorState.apply(transaction);
    if (!messenger.mounted || editorState.isDisposed) return;
    var restored = false;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Block deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            if (restored ||
                editorState.isDisposed ||
                !editorState.editable ||
                !identical(editorState.document.root, root) ||
                (!identical(parent, root) && parent.parent == null)) {
              return;
            }
            restored = true;
            final undo = editorState.transaction;
            final removePlaceholder =
                placeholder != null &&
                identical(placeholder.parent, parent) &&
                (placeholder.delta?.isEmpty ?? false);
            final position = next != null && identical(next.parent, parent)
                ? next.path.last
                : index.clamp(0, parent.children.length);
            if (removePlaceholder) undo.deleteNode(placeholder);
            undo.insertNode([
              ...parent.path,
              removePlaceholder ? 0 : position,
            ], removed);
            await editorState.apply(undo);
          },
        ),
      ),
    );
  }
}
