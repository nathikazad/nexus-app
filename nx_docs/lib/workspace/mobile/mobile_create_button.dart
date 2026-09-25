import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_docs/app/theme.dart';
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
      backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create new',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.5,
                ),
              ),
              const SizedBox(height: 20),
              _CreateOption(
                icon: Icons.article_outlined,
                title: 'New document',
                subtitle: 'Write, plan, and collect ideas',
                onTap: () => Navigator.pop(context, DocumentKind.document),
              ),
              const SizedBox(height: 10),
              _CreateOption(
                icon: Icons.menu_book_outlined,
                title: 'New book',
                subtitle: 'Bring your chapters together',
                onTap: () => Navigator.pop(context, DocumentKind.book),
              ),
            ],
          ),
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

class _CreateOption extends StatelessWidget {
  const _CreateOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.subtle.withValues(alpha: .65),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: AppColors.line.withValues(alpha: .6)),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 23, color: AppColors.text),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.muted),
          ],
        ),
      ),
    ),
  );
}
