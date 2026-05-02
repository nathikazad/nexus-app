part of '../sprint_cart.dart';

class _CartFooter extends StatelessWidget {
  const _CartFooter({required this.surface, required this.onPressed});

  final SprintCartSurface surface;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = surface == SprintCartSurface.planner
        ? 'Sprint View'
        : 'Planner View';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Material(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.bg,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TinyDateChip extends StatelessWidget {
  const _TinyDateChip({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('MMM d').format(date);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          color: AppColors.muted,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (label) {
      'active' => (AppColors.accent, AppColors.bg),
      'planned' => (const Color(0x2EC084FC), AppColors.pMobile),
      _ => (const Color(0x338A93A6), AppColors.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: fg,
        ),
      ),
    );
  }
}
