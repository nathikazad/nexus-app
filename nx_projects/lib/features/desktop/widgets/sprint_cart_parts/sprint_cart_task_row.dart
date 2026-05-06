part of '../sprint_cart.dart';

class _CartTaskRow extends ConsumerStatefulWidget {
  _CartTaskRow({
    required this.task,
    required this.surface,
    required this.onUnpin,
  });

  final Task task;
  final SprintCartSurface surface;
  final VoidCallback onUnpin;

  @override
  ConsumerState<_CartTaskRow> createState() => _CartTaskRowState();
}

class _CartTaskRowState extends ConsumerState<_CartTaskRow> {
  bool _rowHover = false;
  bool _xHover = false;

  void _locateTask() {
    final surface = widget.surface == SprintCartSurface.sprint
        ? DesktopTaskLocatorSurface.sprint
        : DesktopTaskLocatorSurface.planner;
    ref
        .read(desktopTaskLocatorProvider.notifier)
        .locate(
          source: DesktopTaskLocateSource.sprintCart,
          surface: surface,
          taskId: widget.task.id,
        );
  }

  void _openTask() {
    ref.read(desktopDrawerControllerProvider).viewTask(widget.task.id);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final g = _cartGlyph(t);
    final gColor = kindColor(context, t.kind);
    final hStr = t.estimate % 1 == 0
        ? '${t.estimate.toInt()}h'
        : '${t.estimate}h';
    Widget buildRow() {
      return MouseRegion(
        onEnter: (_) {
          setState(() => _rowHover = true);
          ref.read(desktopTaskLocatorProvider.notifier).hover(t.id);
        },
        onExit: (_) {
          setState(() => _rowHover = false);
          ref.read(desktopTaskLocatorProvider.notifier).hover(null);
        },
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 2),
          child: Material(
            color: _rowHover ? context.colors.panel2 : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            child: InkWell(
              onTap: _locateTask,
              onDoubleTap: _openTask,
              borderRadius: BorderRadius.circular(5),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                child: Row(
                  children: [
                    SizedBox(
                      width: 14,
                      child: Text(
                        g,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: gColor),
                      ),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.text,
                        ),
                      ),
                    ),
                    SizedBox(width: 6),
                    SizedBox(
                      width: 36,
                      child: Text(
                        hStr,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.muted,
                        ),
                      ),
                    ),
                    // Temporarily hidden to match the reference cart row shape.
                    // SizedBox(width: 4),
                    // SizedBox(
                    //   width: 62,
                    //   child: SprintDayPickerButton(
                    //     task: t,
                    //     child: _CartDayChip(task: t),
                    //   ),
                    // ),
                    SizedBox(width: 4),
                    if (widget.surface == SprintCartSurface.planner)
                      SizedBox(
                        width: 16,
                        child: MouseRegion(
                          onEnter: (_) => setState(() => _xHover = true),
                          onExit: (_) => setState(() => _xHover = false),
                          child: InkWell(
                            onTap: widget.onUnpin,
                            child: Center(
                              child: Text(
                                '×',
                                style: TextStyle(
                                  fontSize: 16,
                                  height: 1,
                                  color: _xHover
                                      ? Color(0xFFF87171)
                                      : context.colors.dim,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      SizedBox(width: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return buildRow();
  }
}

// Temporarily hidden to match the reference cart row shape.
// class _CartDayChip extends StatelessWidget {
//   _CartDayChip({required this.task});
//
//   final Task task;
//
//   @override
//   Widget build(BuildContext context) {
//     final planned = task.plannedFor;
//     final label = planned == null || planned.isEmpty
//         ? 'day'
//         : planned.substring(planned.length - 5);
//     return Container(
//       padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//       decoration: BoxDecoration(
//         color: context.colors.panel2,
//         border: Border.all(color: context.colors.border),
//         borderRadius: BorderRadius.circular(999),
//       ),
//       child: Text(
//         label,
//         textAlign: TextAlign.center,
//         style: TextStyle(fontSize: 10, color: context.colors.muted),
//       ),
//     );
//   }
// }
