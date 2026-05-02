part of '../sprint_cart.dart';

class _CartTaskRow extends ConsumerStatefulWidget {
  const _CartTaskRow({
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
    final gColor = kindColor(t.kind);
    final hStr = t.estimate % 1 == 0
        ? '${t.estimate.toInt()}h'
        : '${t.estimate}h';
    final scheduled = t.plannedFor != null;
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
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Material(
            color: _rowHover ? AppColors.panel2 : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            child: InkWell(
              onTap: _locateTask,
              onDoubleTap: _openTask,
              borderRadius: BorderRadius.circular(5),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
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
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 36,
                      child: Text(
                        hStr,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    // Temporarily hidden to match the reference cart row shape.
                    // const SizedBox(width: 4),
                    // SizedBox(
                    //   width: 62,
                    //   child: SprintDayPickerButton(
                    //     task: t,
                    //     child: _CartDayChip(task: t),
                    //   ),
                    // ),
                    const SizedBox(width: 4),
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
                                      ? const Color(0xFFF87171)
                                      : AppColors.dim,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        width: 40,
                        child: !scheduled
                            ? Center(
                                child: Tooltip(
                                  message: 'No day assigned',
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: AppColors.warn,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              )
                            : Align(
                                alignment: Alignment.centerRight,
                                child: _TinyDateChip(
                                  date: parseLocalDate(t.plannedFor!),
                                ),
                              ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (scheduled) {
      return buildRow();
    }
    return Draggable<Task>(
      data: t,
      maxSimultaneousDrags: 1,
      feedback: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Card(
            color: AppColors.panel2,
            child: ListTile(
              dense: true,
              title: Text(
                t.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                hStr,
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: buildRow()),
      child: buildRow(),
    );
  }
}

// Temporarily hidden to match the reference cart row shape.
// class _CartDayChip extends StatelessWidget {
//   const _CartDayChip({required this.task});
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
//       padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//       decoration: BoxDecoration(
//         color: AppColors.panel2,
//         border: Border.all(color: AppColors.border),
//         borderRadius: BorderRadius.circular(999),
//       ),
//       child: Text(
//         label,
//         textAlign: TextAlign.center,
//         style: const TextStyle(fontSize: 10, color: AppColors.muted),
//       ),
//     );
//   }
// }
