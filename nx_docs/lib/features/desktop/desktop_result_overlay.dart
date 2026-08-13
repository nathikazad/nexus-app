part of 'desktop_shell.dart';

class _DesktopResultOverlay extends ConsumerWidget {
  const _DesktopResultOverlay({required this.workspace});

  final DesktopWorkspaceState workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = workspace.overlayResults;
    return Positioned.fill(
      left: workspace.sidebarCollapsed ? _collapsedSidebarWidth : _sidebarWidth,
      child: Material(
        color: AppColors.panel.withValues(alpha: 0.96),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(48, 34, 48, 48),
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    workspace.overlayTitle ?? 'Results',
                    style: TextStyle(
                      fontSize: 24,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                ),
                Text(
                  '${rows.length} documents',
                  style: TextStyle(fontSize: 14, color: AppColors.muted),
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: () =>
                      ref.read(desktopWorkspaceProvider.notifier).hideOverlay(),
                  icon: Icon(Icons.close, color: AppColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              children: <Widget>[
                _TagPill(label: workspace.overlayTitle ?? 'Results'),
                const _TagPill(label: 'Sort: recently updated'),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Pick a row to open it in an document tab. Press Esc to close.',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 12),
            for (final document in rows)
              _OverlayResultRow(
                document: document,
                onTap: () => ref
                    .read(desktopWorkspaceProvider.notifier)
                    .openDocument(document.id, fromOverlay: true),
              ),
          ],
        ),
      ),
    );
  }
}

class _OverlayResultRow extends StatelessWidget {
  const _OverlayResultRow({required this.document, required this.onTap});

  final NxDocument document;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  StatusDot(status: document.status),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      document.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${document.status} · edited ${document.updatedLabel}',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                document.excerpt,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
