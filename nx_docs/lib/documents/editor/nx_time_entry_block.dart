part of 'nx_appflowy_blocks.dart';

Node nxTimeEntryNode({TimeOfDay? time, String text = ''}) {
  final value = time ?? TimeOfDay.now();
  return Node(
    type: nxTimeEntryBlockType,
    attributes: {
      'time':
          '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}',
      blockComponentDelta: (Delta()..insert(text)).toJson(),
    },
  );
}

class NxTimeEntryBlockComponentBuilder extends BlockComponentBuilder {
  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return NxTimeEntryBlockComponentWidget(
      key: node.key,
      node: node,
      configuration: configuration,
      showActions: showActions(node),
      actionBuilder: (context, state) =>
          actionBuilder(blockComponentContext, state),
      actionTrailingBuilder: (context, state) =>
          actionTrailingBuilder(blockComponentContext, state),
      editorState: Provider.of<EditorState>(
        blockComponentContext.buildContext,
        listen: false,
      ),
    );
  }

  @override
  BlockComponentValidate get validate =>
      (node) => true;
}

class NxTimeEntryBlockComponentWidget extends BlockComponentStatefulWidget {
  const NxTimeEntryBlockComponentWidget({
    super.key,
    required super.node,
    required super.configuration,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    required this.editorState,
  });

  final EditorState editorState;

  @override
  State<NxTimeEntryBlockComponentWidget> createState() =>
      _NxTimeEntryBlockComponentWidgetState();
}

class _NxTimeEntryBlockComponentWidgetState
    extends State<NxTimeEntryBlockComponentWidget>
    with
        SelectableMixin,
        DefaultSelectableMixin,
        BlockComponentConfigurable,
        BlockComponentBackgroundColorMixin {
  @override
  final forwardKey = GlobalKey(debugLabel: 'nx_time_entry_text');

  @override
  GlobalKey<State<StatefulWidget>> get containerKey => widget.node.key;

  @override
  GlobalKey<State<StatefulWidget>> blockComponentKey = GlobalKey(
    debugLabel: nxTimeEntryBlockType,
  );

  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  @override
  Widget build(BuildContext context) {
    final storedTime = _stringAttribute(node, 'time', '00:00');
    final parts = storedTime.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? parts[1] : '00';
    final time =
        '${hour % 12 == 0 ? 12 : hour % 12}:$minute ${hour < 12 ? 'AM' : 'PM'}';
    Widget child = Container(
      key: blockComponentKey,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.blue, width: 2)),
        color: AppColors.sidebar,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IgnoreEditorSelectionGesture(
            child: Tooltip(
              message: widget.editorState.editable
                  ? 'Change entry time'
                  : 'Entry time',
              child: InkWell(
                onTap: widget.editorState.editable ? _pickTime : null,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.panel,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Text(
                    time,
                    style: TextStyle(
                      color: AppColors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [ui.FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: AppFlowyRichText(
                key: forwardKey,
                delegate: this,
                node: node,
                editorState: widget.editorState,
                cursorColor: widget.editorState.editorStyle.cursorColor,
                selectionColor: widget.editorState.editorStyle.selectionColor,
                cursorWidth: widget.editorState.editorStyle.cursorWidth,
                placeholderText: 'What happened?',
              ),
            ),
          ),
        ],
      ),
    );
    child = _wrapBlockSelection(
      node: node,
      delegate: this,
      editorState: widget.editorState,
      child: child,
    );
    if (widget.showActions && widget.actionBuilder != null) {
      child = BlockComponentActionWrapper(
        node: node,
        actionBuilder: widget.actionBuilder!,
        actionTrailingBuilder: widget.actionTrailingBuilder,
        child: child,
      );
    }
    return child;
  }

  Future<void> _pickTime() async {
    final parts = _stringAttribute(node, 'time', '00:00').split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final selected = await showTimePicker(
      context: context,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
      initialTime: TimeOfDay(
        hour: hour.clamp(0, 23),
        minute: minute.clamp(0, 59),
      ),
    );
    if (selected == null ||
        !mounted ||
        widget.editorState.isDisposed ||
        !widget.editorState.editable) {
      return;
    }
    final value =
        '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}';
    await widget.editorState.apply(
      widget.editorState.transaction..updateNode(node, {'time': value}),
    );
  }
}
