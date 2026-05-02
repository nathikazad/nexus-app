part of '../sprint_cart.dart';

class _SprintGoalField extends ConsumerStatefulWidget {
  const _SprintGoalField({super.key, required this.sprint});

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
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
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
        style: const TextStyle(fontSize: 13, color: AppColors.text),
        cursorColor: AppColors.accent,
        decoration: InputDecoration(
          hintText: "What's the goal for ${widget.sprint.name}?",
          hintStyle: const TextStyle(color: AppColors.dim, fontSize: 12),
          filled: true,
          fillColor: AppColors.panel2,
          contentPadding: const EdgeInsets.all(8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(6)),
            borderSide: BorderSide(color: AppColors.accent),
          ),
        ),
      ),
    );
  }
}
