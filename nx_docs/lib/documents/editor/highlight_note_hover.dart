part of 'nx_highlight_notes.dart';

class _NxInlineHoverTarget extends StatelessWidget {
  const _NxInlineHoverTarget({
    required this.editorState,
    required this.selection,
    required this.noteId,
    required this.noteText,
    required this.href,
  });

  final EditorState editorState;
  final Selection selection;
  final String? noteId;
  final String? noteText;
  final String? href;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (event) {
        _NxInlineHoverOverlay.show(
          context: context,
          editorState: editorState,
          position: event.position,
          noteText: noteText,
          href: href,
          selection: selection,
        );
      },
      onExit: (_) => _NxInlineHoverOverlay.scheduleHide(),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          final link = href;
          if (link != null) {
            unawaited(editorLaunchUrl(link));
            return;
          }
          final id = noteId;
          if (id == null) {
            return;
          }
          unawaited(
            showNxHighlightNoteDialog(
              context,
              editorState,
              selection,
              noteId: id,
            ),
          );
        },
      ),
    );
  }
}

class _NxInlineHoverOverlay {
  static OverlayEntry? _entry;
  static Timer? _hideTimer;

  static void show({
    required BuildContext context,
    required EditorState editorState,
    required Offset position,
    required String? noteText,
    required String? href,
    required Selection selection,
  }) {
    final hasNote = noteText != null && noteText.trim().isNotEmpty;
    if (!hasNote && href == null) {
      return;
    }
    hide();
    final overlay = Overlay.of(context, rootOverlay: true);
    _entry = OverlayEntry(
      builder: (context) {
        final size = MediaQuery.sizeOf(context);
        const margin = 8.0;
        const gap = 12.0;
        final editorWidth = editorState.renderBox?.size.width ?? size.width;
        final maxWidth = math.min(
          math.max(editorWidth * 0.7, size.width * 0.52),
          size.width - margin * 2,
        );
        final fixedWidth =
            _expandedHoverNoteWidth(noteText ?? href ?? '', maxWidth) ??
            (href == null ? null : math.min(360.0, maxWidth));
        final horizontalFootprint = fixedWidth ?? maxWidth;
        final left = (position.dx + gap).clamp(
          margin,
          size.width - horizontalFootprint - margin,
        );
        final belowSpace = size.height - position.dy - gap - margin;
        final aboveSpace = position.dy - gap - margin;
        final showAbove = belowSpace < 180 && aboveSpace > belowSpace;
        final availableHeight = showAbove ? aboveSpace : belowSpace;
        final maxHeight = math.max(80.0, math.min(420.0, availableHeight));
        final top = showAbove ? null : position.dy + gap;
        final bottom = showAbove ? size.height - position.dy + gap : null;
        return Positioned(
          left: left,
          top: top,
          bottom: bottom,
          child: Material(
            color: Colors.transparent,
            child: MouseRegion(
              onEnter: (_) => _cancelHide(),
              onExit: (_) => scheduleHide(),
              child: SizedBox(
                width: fixedWidth,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxWidth,
                    maxHeight: maxHeight,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _inlineHoverBackground,
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (hasNote)
                              Text(
                                noteText,
                                textWidthBasis: fixedWidth == null
                                    ? TextWidthBasis.longestLine
                                    : TextWidthBasis.parent,
                                style: const TextStyle(
                                  color: _inlineHoverForeground,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            if (hasNote && href != null)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Divider(
                                  height: 1,
                                  color: _inlineHoverDivider,
                                ),
                              ),
                            if (href != null)
                              _NxInlineLinkActions(
                                href: href,
                                onOpen: () {
                                  hide();
                                  unawaited(editorLaunchUrl(href));
                                },
                                onCopy: () {
                                  unawaited(
                                    Clipboard.setData(
                                      ClipboardData(text: href),
                                    ),
                                  );
                                  hide();
                                },
                                onRemove: () {
                                  unawaited(
                                    editorState.formatDelta(selection, {
                                      BuiltInAttributeKey.href: null,
                                    }),
                                  );
                                  hide();
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_entry!);
  }

  static void scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 160), hide);
  }

  static void hide() {
    _hideTimer?.cancel();
    _hideTimer = null;
    _entry?.remove();
    _entry = null;
  }

  static void _cancelHide() {
    _hideTimer?.cancel();
    _hideTimer = null;
  }
}

class _NxInlineLinkActions extends StatelessWidget {
  const _NxInlineLinkActions({
    required this.href,
    required this.onOpen,
    required this.onCopy,
    required this.onRemove,
  });

  final String href;
  final VoidCallback onOpen;
  final VoidCallback onCopy;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final documentId = nxDocumentIdFromHref(href);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          documentId == null ? href : 'Document $documentId',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _inlineHoverForeground,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            _NxInlineHoverButton(
              icon: Icons.open_in_new,
              label: 'Open',
              onPressed: onOpen,
            ),
            _NxInlineHoverButton(
              icon: Icons.copy,
              label: 'Copy',
              onPressed: onCopy,
            ),
            _NxInlineHoverButton(
              icon: Icons.link_off,
              label: 'Remove',
              onPressed: onRemove,
            ),
          ],
        ),
      ],
    );
  }
}

class _NxInlineHoverButton extends StatelessWidget {
  const _NxInlineHoverButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: _inlineHoverMuted,
        backgroundColor: _inlineHoverButtonBackground,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
      icon: Icon(icon, size: 13),
      label: Text(label),
    );
  }
}

double? _expandedHoverNoteWidth(String text, double maxWidth) {
  final trimmed = text.trim();
  final lines = trimmed.split('\n');
  final longestLine = lines.fold<int>(
    0,
    (longest, line) => math.max(longest, line.trimRight().length),
  );
  final shouldExpand =
      trimmed.length >= 120 || lines.length >= 3 || longestLine >= 80;
  return shouldExpand ? maxWidth : null;
}
