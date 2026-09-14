import 'package:flutter/material.dart';
import 'desires.dart';
import 'listening.dart';

/// Displays the recording's own transcript, never timings applied to edited prose.
class TimedStory extends StatefulWidget {
  const TimedStory({
    super.key,
    required this.tape,
    required this.listening,
    required this.follow,
  });
  final Tape tape;
  final Listening listening;
  final ValueNotifier<bool> follow;
  @override
  State<TimedStory> createState() => _TimedStoryState();
}

class _TimedStoryState extends State<TimedStory> {
  late final keys = List.generate(
    widget.tape.timeline!.segments.length,
    (_) => GlobalKey(),
  );
  int active = -1;
  bool scheduled = false;
  bool get matches =>
      widget.listening.tape?.id == widget.tape.id &&
      widget.listening.tape?.audioRevision == widget.tape.audioRevision;
  @override
  void initState() {
    super.initState();
    widget.listening.addListener(update);
    widget.follow.addListener(followChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) update();
    });
  }

  void update() {
    if (!mounted) return;
    final next = matches
        ? widget.tape.timeline!.indexAt(widget.listening.position)
        : -1;
    final changed = next != active;
    if (changed) setState(() => active = next);
    if (!widget.follow.value || next < 0 || scheduled) return;
    // Scroll only on a segment transition or when following is explicitly resumed.
    if (!changed && lastScrolled == next) return;
    scheduled = true;
    WidgetsBinding.instance.ensureVisualUpdate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scheduled = false;
      if (!mounted || !widget.follow.value || !matches || active < 0) return;
      final target = keys[active].currentContext;
      if (target == null) return;
      lastScrolled = active;
      Scrollable.ensureVisible(
        target,
        alignment: .2,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 300),
      );
    });
  }

  int? lastScrolled;
  void followChanged() {
    lastScrolled = null;
    update();
  }

  @override
  void dispose() {
    widget.listening.removeListener(update);
    widget.follow.removeListener(followChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Padding(
        padding: EdgeInsets.only(bottom: 18),
        child: Text(
          'Recorded transcript',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ),
      for (var i = 0; i < keys.length; i++)
        Semantics(
          key: keys[i],
          selected: i == active,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: i == active ? const Color(0xffeeeeec) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.tape.timeline!.segments[i].text,
              style: const TextStyle(fontSize: 16, height: 1.85),
            ),
          ),
        ),
    ],
  );
}
