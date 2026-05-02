part of '../sprint_cart.dart';

class _CartFooter extends StatelessWidget {
  _CartFooter({required this.surface, required this.onPressed});

  final SprintCartSurface surface;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = surface == SprintCartSurface.planner
        ? 'Sprint View'
        : 'Planner View';
    return Container(
      padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.colors.border)),
      ),
      child: Material(
        color: context.colors.accent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: context.colors.bg,
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
  _TinyDateChip({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('MMM d').format(date);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: context.colors.panel2,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: context.colors.border, width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          color: context.colors.muted,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (label) {
      'active' => (context.colors.accent, context.colors.bg),
      'planned' => (Color(0x2EC084FC), context.colors.pMobile),
      _ => (Color(0x338A93A6), context.colors.muted),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
