import 'package:flutter/material.dart';

/// Each list owns its controller so adjacent tabs never share a scrollbar.
class ScrollPositionIndicator extends StatefulWidget {
  const ScrollPositionIndicator({super.key, required this.builder});

  final Widget Function(ScrollController controller) builder;

  @override
  State<ScrollPositionIndicator> createState() =>
      _ScrollPositionIndicatorState();
}

class _ScrollPositionIndicatorState extends State<ScrollPositionIndicator> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScrollConfiguration(
    behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
    child: Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      interactive: false,
      thickness: 6,
      radius: const Radius.circular(3),
      child: widget.builder(_controller),
    ),
  );
}
