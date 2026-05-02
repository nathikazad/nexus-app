part of '../planner_view.dart';

class _PlannerAddMenuButton extends StatefulWidget {
  _PlannerAddMenuButton({
    required this.onNewProject,
    required this.onNewTask,
    required this.onNewSprint,
  });

  final VoidCallback onNewProject;
  final VoidCallback onNewTask;
  final VoidCallback onNewSprint;

  @override
  State<_PlannerAddMenuButton> createState() => _PlannerAddMenuButtonState();
}

class _PlannerAddMenuButtonState extends State<_PlannerAddMenuButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      alignmentOffset: Offset(-186, 6),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(context.colors.panel),
        elevation: WidgetStatePropertyAll(12),
        padding: WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 6)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: context.colors.border),
          ),
        ),
        minimumSize: WidgetStatePropertyAll(Size(210, 0)),
      ),
      menuChildren: [
        _PlannerAddMenuItem(
          icon: Icons.folder_open_outlined,
          title: 'Project',
          subtitle: 'Create a root project',
          onPressed: widget.onNewProject,
        ),
        _PlannerAddMenuItem(
          icon: Icons.check_circle_outline,
          title: 'Task',
          subtitle: 'Add work to the backlog',
          onPressed: widget.onNewTask,
        ),
        _PlannerAddMenuItem(
          icon: Icons.calendar_month_outlined,
          title: 'Sprint',
          subtitle: 'Plan a new sprint',
          onPressed: widget.onNewSprint,
        ),
      ],
      builder: (context, controller, child) {
        return MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _hover ? context.colors.panel2 : context.colors.panel,
                  border: Border.all(
                    color: _hover
                        ? context.colors.border2
                        : context.colors.border,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.add, size: 18, color: context.colors.accent),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlannerAddMenuItem extends StatelessWidget {
  _PlannerAddMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return MenuItemButton(
      onPressed: onPressed,
      style: ButtonStyle(
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        backgroundColor: WidgetStatePropertyAll(Colors.transparent),
        overlayColor: WidgetStatePropertyAll(
          context.colors.panel3.withValues(alpha: 0.55),
        ),
        foregroundColor: WidgetStatePropertyAll(context.colors.text),
      ),
      child: SizedBox(
        width: 190,
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: context.colors.panel3,
                border: Border.all(color: context.colors.border),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, size: 16, color: context.colors.accent),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                      color: context.colors.text,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.1,
                      color: context.colors.dim,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
