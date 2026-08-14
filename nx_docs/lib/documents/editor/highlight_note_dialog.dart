part of 'nx_highlight_notes.dart';

enum _NxHighlightNoteDialogAction { save, delete }

class _NxHighlightNoteDialogResult {
  const _NxHighlightNoteDialogResult.save(this.text)
    : action = _NxHighlightNoteDialogAction.save;

  const _NxHighlightNoteDialogResult.delete()
    : action = _NxHighlightNoteDialogAction.delete,
      text = '';

  final _NxHighlightNoteDialogAction action;
  final String text;
}

class _NxHighlightNoteDialog extends StatefulWidget {
  const _NxHighlightNoteDialog({
    required this.initialText,
    required this.quote,
    required this.canDelete,
  });

  final String initialText;
  final String quote;
  final bool canDelete;

  @override
  State<_NxHighlightNoteDialog> createState() => _NxHighlightNoteDialogState();
}

class _NxHighlightNoteDialogState extends State<_NxHighlightNoteDialog> {
  late final TextEditingController _controller;
  bool _canSave = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _canSave = _controller.text.trim().isNotEmpty;
    _controller.addListener(_updateCanSave);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_updateCanSave)
      ..dispose();
    super.dispose();
  }

  void _updateCanSave() {
    final canSave = _controller.text.trim().isNotEmpty;
    if (canSave != _canSave) {
      setState(() => _canSave = canSave);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.panel,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.line),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    Icons.sticky_note_2_outlined,
                    size: 17,
                    color: AppColors.faint,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Highlight note',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (widget.quote.isNotEmpty) ...[
                Text(
                  'Selection',
                  style: TextStyle(
                    color: AppColors.faint,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.sidebar,
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.quote,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Text(
                'Note',
                style: TextStyle(
                  color: AppColors.faint,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _controller,
                autofocus: true,
                minLines: 5,
                maxLines: 9,
                cursorColor: AppColors.text,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 13,
                  height: 1.45,
                ),
                decoration: InputDecoration(
                  hintText: 'Add a note...',
                  hintStyle: TextStyle(color: AppColors.faint, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.sidebar,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  border: _noteInputBorder(AppColors.line),
                  enabledBorder: _noteInputBorder(AppColors.line),
                  focusedBorder: _noteInputBorder(AppColors.hover),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  if (widget.canDelete)
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pop(const _NxHighlightNoteDialogResult.delete());
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.red,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      icon: const Icon(Icons.delete_outline, size: 15),
                      label: const Text('Delete note'),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.muted,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _canSave
                        ? () {
                            Navigator.of(context).pop(
                              _NxHighlightNoteDialogResult.save(
                                _controller.text,
                              ),
                            );
                          }
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.floating,
                      foregroundColor: AppColors.onFloating,
                      disabledBackgroundColor: AppColors.hover,
                      disabledForegroundColor: AppColors.faint,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  OutlineInputBorder _noteInputBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: color),
    );
  }
}
