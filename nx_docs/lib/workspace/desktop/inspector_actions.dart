part of 'desktop_workspace.dart';

class _InspectorPinnedSwitch extends ConsumerStatefulWidget {
  const _InspectorPinnedSwitch({required this.document});

  final NxDocument document;

  @override
  ConsumerState<_InspectorPinnedSwitch> createState() =>
      _InspectorPinnedSwitchState();
}

class _InspectorPinnedSwitchState
    extends ConsumerState<_InspectorPinnedSwitch> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          Text(
            'Pinned',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const Spacer(),
          SizedBox(
            width: 42,
            height: 24,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Switch.adaptive(
                value: widget.document.pinned,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                activeThumbColor: AppColors.text,
                onChanged: _saving ? null : _setPinned,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setPinned(bool pinned) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(documentMutationControllerProvider)
          .setPinned(widget.document, pinned);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update pin: $error')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}

class _InspectorActions extends ConsumerStatefulWidget {
  const _InspectorActions({required this.document});

  final NxDocument document;

  @override
  ConsumerState<_InspectorActions> createState() => _InspectorActionsState();
}

class _InspectorActionsState extends ConsumerState<_InspectorActions> {
  bool _saving = false;
  bool _publishing = false;
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        children: <Widget>[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                alignment: Alignment.centerLeft,
                backgroundColor: AppColors.floating,
                foregroundColor: AppColors.onFloating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: _saving || _deleting ? null : _saveNow,
              icon: _saving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onFloating,
                      ),
                    )
                  : const Icon(Icons.save_outlined, size: 16),
              label: Text(_saving ? 'Saving...' : 'Save now'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                alignment: Alignment.centerLeft,
                backgroundColor: widget.document.publish.enabled
                    ? AppColors.panel
                    : AppColors.floating,
                foregroundColor: widget.document.publish.enabled
                    ? AppColors.text
                    : AppColors.onFloating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: _saving || _publishing || _deleting
                  ? null
                  : _togglePublish,
              icon: _publishing
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: widget.document.publish.enabled
                            ? AppColors.text
                            : AppColors.onFloating,
                      ),
                    )
                  : Icon(
                      widget.document.publish.enabled
                          ? Icons.public_off_outlined
                          : Icons.public_outlined,
                      size: 16,
                    ),
              label: Text(
                _publishing
                    ? 'Updating publish...'
                    : widget.document.publish.enabled
                    ? 'Unpublish'
                    : 'Publish',
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                foregroundColor: AppColors.red,
                side: BorderSide(color: AppColors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: _saving || _deleting ? null : _confirmDelete,
              icon: _deleting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline, size: 16),
              label: Text(_deleting ? 'Deleting...' : 'Delete'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveNow() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(documentMutationControllerProvider)
          .saveNow(widget.document);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Document saved')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save document: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _togglePublish() async {
    final nextEnabled = !widget.document.publish.enabled;
    setState(() => _publishing = true);
    try {
      await ref
          .read(documentMutationControllerProvider)
          .setPublishEnabled(widget.document, nextEnabled);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextEnabled
                ? 'Document published and synced'
                : 'Document unpublished and synced',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update publishing: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _publishing = false);
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteDocumentDialog(title: widget.document.title),
    );
    if (confirmed != true || !mounted) return;
    await _deleteDocument();
  }

  Future<void> _deleteDocument() async {
    setState(() => _deleting = true);
    try {
      await ref
          .read(documentMutationControllerProvider)
          .deleteDocument(widget.document);
      ref.read(desktopWorkspaceProvider.notifier).closeTab(widget.document.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Document deleted')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete document: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }
}

class _DeleteDocumentDialog extends StatelessWidget {
  const _DeleteDocumentDialog({required this.title});

  final String title;

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
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.delete_outline, size: 17, color: AppColors.red),
                  const SizedBox(width: 8),
                  Text(
                    'Delete document?',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'This permanently removes the document and closes its open tab.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
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
                  title.trim().isEmpty ? 'Untitled document' : title.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
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
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(true),
                    icon: const Icon(Icons.delete_outline, size: 15),
                    label: const Text('Delete'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
