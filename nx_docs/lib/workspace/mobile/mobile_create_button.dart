import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_docs/app/theme.dart';
import 'package:nx_docs/documents/document_actions.dart';
import 'package:nx_docs/workspace/workspace_state.dart';

class MobileCreateButton extends ConsumerStatefulWidget {
  const MobileCreateButton({super.key});

  @override
  ConsumerState<MobileCreateButton> createState() => _MobileCreateButtonState();
}

class _MobileCreateButtonState extends ConsumerState<MobileCreateButton> {
  bool _busy = false;

  Future<void> _create() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final document = await ref
          .read(documentMutationControllerProvider)
          .createDocument();
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
    tooltip: 'New document',
    onPressed: _busy ? null : _create,
    style: IconButton.styleFrom(
      foregroundColor: AppColors.text,
      backgroundColor: AppColors.subtle,
      minimumSize: const Size(40, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    icon: _busy
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.add),
  );
}
