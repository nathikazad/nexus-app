import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_docs/documents/document_actions.dart';
import 'package:nx_docs/documents/document_models.dart';
import 'package:nx_docs/workspace/workspace_state.dart';

class MobileCreateButton extends ConsumerStatefulWidget {
  const MobileCreateButton({super.key});

  @override
  ConsumerState<MobileCreateButton> createState() => _MobileCreateButtonState();
}

class _MobileCreateButtonState extends ConsumerState<MobileCreateButton> {
  bool _busy = false;

  Future<void> _create() async {
    final kind = await showModalBottomSheet<DocumentKind>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.note_add_outlined),
              title: const Text('New document'),
              subtitle: const Text('Start writing'),
              onTap: () => Navigator.pop(context, DocumentKind.document),
            ),
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('New book'),
              onTap: () => Navigator.pop(context, DocumentKind.book),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    if (kind == null || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      final document = await ref
          .read(documentMutationControllerProvider)
          .createDocument(kind: kind);
      if (!mounted) return;
      ref.read(mobileWorkspaceProvider.notifier).openDocument(document.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not create the document. Check your connection and try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'New document or book',
    onPressed: _busy ? null : _create,
    icon: _busy
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.add),
  );
}
