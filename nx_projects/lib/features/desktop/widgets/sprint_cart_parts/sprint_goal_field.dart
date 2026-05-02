part of '../sprint_cart.dart';

class _SprintGoalField extends ConsumerStatefulWidget {
  _SprintGoalField({super.key, required this.sprint});

  final Sprint sprint;

  @override
  ConsumerState<_SprintGoalField> createState() => _SprintGoalFieldState();
}

class _SprintGoalFieldState extends ConsumerState<_SprintGoalField> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.sprint.goal);
  }

  @override
  void didUpdateWidget(covariant _SprintGoalField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sprint.id != widget.sprint.id) {
      _c.text = widget.sprint.goal;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(6, 4, 6, 8),
      child: TextField(
        controller: _c,
        onChanged: (v) {
          ref
              .read(sprintRepositoryProvider)
              .update(widget.sprint.copyWith(goal: v));
          ref.invalidate(sprintsListAsyncProvider);
        },
        minLines: 2,
        maxLines: 4,
        style: TextStyle(fontSize: 13, color: context.colors.text),
        cursorColor: context.colors.accent,
        decoration: InputDecoration(
          hintText: "What's the goal for ${widget.sprint.name}?",
          hintStyle: TextStyle(color: context.colors.dim, fontSize: 12),
          filled: true,
          fillColor: context.colors.panel2,
          contentPadding: EdgeInsets.all(8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: context.colors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: context.colors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(6)),
            borderSide: BorderSide(color: context.colors.accent),
          ),
        ),
      ),
    );
  }
}
