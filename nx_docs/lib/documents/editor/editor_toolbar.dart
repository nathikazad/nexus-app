part of 'document_editor_view.dart';

bool canPersistDocumentTransaction(
  DocumentInteractionMode interactionMode,
  Transaction transaction,
) {
  return interactionMode == DocumentInteractionMode.edit;
}

EditorStyle _editorStyle(
  _DocumentEditorMode mode, {
  required double textScaleFactor,
  required bool useMobileSelectionHandles,
}) {
  final readMode = mode == _DocumentEditorMode.read;
  final bodyStyle = readMode
      ? TextStyle(color: _readModeTextColor(), fontSize: 18, height: 1.6)
      : TextStyle(color: AppColors.editorText, fontSize: 16, height: 1.62);
  final lineHeight = readMode ? 1.6 : 1.62;
  final textStyleConfiguration = TextStyleConfiguration(
    text: bodyStyle,
    bold: const TextStyle(fontWeight: FontWeight.w700),
    italic: const TextStyle(fontStyle: FontStyle.italic),
    underline: const TextStyle(decoration: TextDecoration.underline),
    strikethrough: const TextStyle(decoration: TextDecoration.lineThrough),
    href: TextStyle(
      foreground: Paint()..color = AppColors.blue,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.blue,
    ),
    code: TextStyle(
      color: AppColors.text,
      backgroundColor: AppColors.subtle,
      fontFamily: 'monospace',
    ),
    lineHeight: lineHeight,
  );
  if (useMobileSelectionHandles) {
    return EditorStyle.mobile(
      textScaleFactor: textScaleFactor,
      cursorColor: AppColors.text,
      dragHandleColor: AppColors.blue,
      selectionColor: const Color(0x333B82F6),
      padding: EdgeInsets.zero,
      textSpanDecorator: nxHighlightNoteTextSpanDecorator,
      textSpanOverlayBuilder: nxHighlightNoteOverlayBuilder,
      textStyleConfiguration: textStyleConfiguration,
    );
  }
  return EditorStyle.desktop(
    textScaleFactor: textScaleFactor,
    cursorColor: AppColors.text,
    selectionColor: const Color(0x333B82F6),
    padding: EdgeInsets.zero,
    textSpanDecorator: nxHighlightNoteTextSpanDecorator,
    textSpanOverlayBuilder: nxHighlightNoteOverlayBuilder,
    textStyleConfiguration: textStyleConfiguration,
  );
}

Color _readModeBackgroundColor() {
  return AppColors.isDark ? const Color(0xff171512) : const Color(0xfff6f5f1);
}

Color _readModeTextColor() {
  return AppColors.isDark ? const Color(0xffe8e1d5) : const Color(0xff25231f);
}

class EditorContextBar extends StatelessWidget {
  const EditorContextBar({
    required this.resultContext,
    required this.activeDocumentId,
    required this.onBack,
    required this.onClear,
    super.key,
  });

  final DocumentResultContext resultContext;
  final int activeDocumentId;
  final VoidCallback onBack;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final index = resultContext.resultIds.indexOf(activeDocumentId);
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.sidebar,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: <Widget>[
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: AppColors.muted,
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, size: 16),
            label: Text('Back to ${resultContext.title}'),
          ),
          const Spacer(),
          Text(
            '${index + 1} of ${resultContext.resultIds.length}',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(width: 8),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onClear,
            icon: Icon(Icons.close, size: 16, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
