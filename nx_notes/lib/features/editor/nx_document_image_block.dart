part of 'nx_appflowy_blocks.dart';

class NxDocumentImageBlockMenu extends StatefulWidget {
  const NxDocumentImageBlockMenu({
    required this.node,
    required this.state,
    required this.deleteDocumentImage,
    super.key,
  });

  final Node node;
  final ImageBlockComponentWidgetState state;
  final Future<void> Function(String url)? deleteDocumentImage;

  @override
  State<NxDocumentImageBlockMenu> createState() =>
      _NxDocumentImageBlockMenuState();
}

class _NxDocumentImageBlockMenuState extends State<NxDocumentImageBlockMenu> {
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 8,
      right: 8,
      child: Material(
        color: AppColors.text,
        borderRadius: BorderRadius.circular(6),
        child: IconButton(
          tooltip: 'Delete image',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 30, height: 30),
          onPressed: _deleting ? null : _delete,
          icon: _deleting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.delete_outline, size: 16, color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _delete() async {
    setState(() => _deleting = true);
    final src = widget.node.attributes[ImageBlockKeys.url];
    try {
      if (src is String && widget.deleteDocumentImage != null) {
        await widget.deleteDocumentImage!(src);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('Could not delete image file: $error')),
        );
      }
    } finally {
      _removeBlock();
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  void _removeBlock() {
    final editorState = widget.state.editorState;
    final transaction = editorState.transaction..deleteNode(widget.node);
    editorState.apply(transaction);
  }
}
