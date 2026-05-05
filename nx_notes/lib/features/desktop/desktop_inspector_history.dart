part of 'desktop_shell.dart';

class _InspectorHistory extends ConsumerWidget {
  const _InspectorHistory({required this.essay, required this.snaps});

  final Essay essay;
  final List<EssaySnap> snaps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              foregroundColor: AppColors.muted,
              side: const BorderSide(color: AppColors.line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () => _showCreateSnapshotDialog(context, ref, essay),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Create snapshot'),
          ),
        ),
        const SizedBox(height: 14),
        const _TimelineItem(
          title: 'Auto-saved',
          subtitle: 'Current live essay',
          active: true,
        ),
        if (snaps.isEmpty)
          const Padding(
            padding: EdgeInsets.only(left: 22, bottom: 8),
            child: Text(
              'No snapshots yet',
              style: TextStyle(fontSize: 12, color: AppColors.faint),
            ),
          )
        else
          for (final snap in snaps)
            _TimelineItem(
              title: _snapshotTitle(snap),
              subtitle: _snapshotSubtitle(snap),
              onTap: () => _showSnapshotPreview(context, ref, essay, snap),
            ),
      ],
    );
  }
}

Future<void> _showCreateSnapshotDialog(
  BuildContext context,
  WidgetRef ref,
  Essay essay,
) async {
  final controller = TextEditingController();
  final message = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.panel,
      surfaceTintColor: Colors.transparent,
      title: const Text('Create snapshot'),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Snapshot message',
            hintText: 'Before rewriting the introduction',
          ),
          onSubmitted: (_) => Navigator.of(context).pop(controller.text),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Create'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (message == null) return;
  await ref
      .read(essayMutationControllerProvider)
      .createSnapshot(essay.id, source: 'manual', changeSummary: message);
}

Future<void> _showSnapshotPreview(
  BuildContext context,
  WidgetRef ref,
  Essay essay,
  EssaySnap snap,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: AppColors.panel,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _snapshotTitle(snap),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _snapshotSubtitle(snap),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(48, 34, 48, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      essay.title,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SelectableText(
                      snap.document.isEmpty ? 'Empty snapshot' : snap.document,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.62,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: <Widget>[
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back to current'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      await _restoreSnapshot(context, ref, essay, snap);
                    },
                    child: const Text('Restore as current'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _restoreSnapshot(
  BuildContext context,
  WidgetRef ref,
  Essay essay,
  EssaySnap snap,
) async {
  await ref.read(essayMutationControllerProvider).restoreSnapshot(essay, snap);
  if (context.mounted) {
    Navigator.of(context).pop();
  }
}

String _snapshotSubtitle(EssaySnap snap) {
  final message = snap.changeSummary.trim().isEmpty
      ? ''
      : snap.changeSummary.trim();
  final detail = message.isNotEmpty && message != snap.name.trim()
      ? message
      : 'Version ${snap.versionNumber}';
  return '$detail · ${_historyDateLabel(snap.createdAt)}';
}

String _snapshotTitle(EssaySnap snap) {
  final name = snap.name.trim();
  if (name.isNotEmpty && name != snap.source) {
    return name;
  }
  final message = snap.changeSummary.trim();
  if (message.isNotEmpty) {
    return message;
  }
  return 'Version ${snap.versionNumber}';
}

String _historyDateLabel(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${date.month}/${date.day}/${date.year}';
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.title,
    required this.subtitle,
    this.active = false,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Column(
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: active ? AppColors.muted : AppColors.line,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.panel, width: 2),
                ),
              ),
              Expanded(child: Container(width: 1, color: AppColors.line)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: active ? AppColors.text : AppColors.muted,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.faint,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) {
      return content;
    }
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: content,
      ),
    );
  }
}
