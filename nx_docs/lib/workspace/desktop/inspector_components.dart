part of 'desktop_workspace.dart';

class _CollapsedInspector extends ConsumerWidget {
  const _CollapsedInspector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.sidebar,
        border: Border(left: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            const SizedBox(height: 6),
            IconButton(
              tooltip: 'Expand inspector',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              onPressed: () =>
                  ref.read(desktopWorkspaceProvider.notifier).toggleInspector(),
              icon: Icon(Icons.chevron_left, size: 18, color: AppColors.faint),
            ),
            const SizedBox(height: 8),
            RotatedBox(
              quarterTurns: 1,
              child: Text(
                'INSPECTOR',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.faint,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InspectorSection extends StatelessWidget {
  const _InspectorSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 15, color: AppColors.faint),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InspectorPair extends StatelessWidget {
  const _InspectorPair({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          Text(label, style: TextStyle(fontSize: 12, color: AppColors.muted)),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 12, color: AppColors.text)),
        ],
      ),
    );
  }
}

class _InspectorStatusPair extends ConsumerWidget {
  const _InspectorStatusPair({required this.document, required this.statuses});

  final NxDocument document;
  final List<String> statuses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final values = statuses.contains(document.status)
        ? statuses
        : <String>[document.status, ...statuses];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          Text(
            'Status',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const Spacer(),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.subtle,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: 8, right: 4),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: document.status,
                  isDense: true,
                  icon: Icon(
                    Icons.keyboard_arrow_down,
                    size: 15,
                    color: AppColors.muted,
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                  dropdownColor: AppColors.panel,
                  borderRadius: BorderRadius.circular(6),
                  items: [
                    for (final status in values)
                      DropdownMenuItem<String>(
                        value: status,
                        child: Text(status),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null || value == document.status) return;
                    _saveDocumentMetadata(
                      ref,
                      document.copyWith(
                        status: value,
                        tagsBySystem: <String, List<String>>{
                          ...document.tagsBySystem,
                          'Status': <String>[value],
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
