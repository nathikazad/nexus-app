part of 'desktop_workspace.dart';

class _CollapsedInspector extends ConsumerWidget {
  const _CollapsedInspector({this.onExpand});

  final VoidCallback? onExpand;

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
              onPressed:
                  onExpand ??
                  () => ref
                      .read(desktopWorkspaceProvider.notifier)
                      .toggleInspector(),
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
