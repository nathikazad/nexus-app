import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'reading_companion_controller.dart';
import 'reading_companion_message.dart';

/// Follow a reply only until its beginning reaches the viewport's top.
/// Chronological scrolling then lets further tokens grow below the reader.
class ReadingCompanionConversation extends StatefulWidget {
  const ReadingCompanionConversation({
    required this.messages,
    required this.busy,
    super.key,
  });

  final List<ReadingMessage> messages;
  final bool busy;

  @override
  State<ReadingCompanionConversation> createState() =>
      _ReadingCompanionConversationState();
}

class _ReadingCompanionConversationState
    extends State<ReadingCompanionConversation> {
  final _scroll = ScrollController();
  final _viewport = GlobalKey();
  final _latest = GlobalKey();
  bool _initial = true;
  bool _follow = false;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    _follow = widget.busy;
  }

  @override
  void didUpdateWidget(ReadingCompanionConversation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.busy && !oldWidget.busy) _follow = true;
  }

  void _afterLayout() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || !_scroll.hasClients) return;
      final position = _scroll.position;
      if (_initial && !_follow) {
        _scroll.jumpTo(position.maxScrollExtent);
      } else if (_follow && widget.messages.isNotEmpty) {
        final reply = _latest.currentContext?.findRenderObject() as RenderBox?;
        final viewport =
            _viewport.currentContext?.findRenderObject() as RenderBox?;
        if (reply != null && viewport != null) {
          final start =
              reply.localToGlobal(Offset.zero, ancestor: viewport).dy +
              position.pixels -
              12;
          final target = widget.messages.last.role == 'user'
              ? position.maxScrollExtent
              : math.min(position.maxScrollExtent, math.max(0.0, start));
          // Never pull the reader backwards when Markdown reflows or resizes.
          if (target > position.pixels) _scroll.jumpTo(target);
        }
      }
      _initial = false;
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Widget _message(ReadingMessage message) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message.role == 'user' ? 'You' : 'Companion',
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: 6),
        ReadingCompanionMessage(
          text: message.text,
          fromUser: message.role == 'user',
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    _afterLayout();
    return SizedBox.expand(
      key: _viewport,
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (_) {
          _afterLayout();
          return false;
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollStartNotification &&
                    notification.dragDetails != null ||
                notification is UserScrollNotification &&
                    notification.direction != ScrollDirection.idle) {
              _follow = false;
            }
            return false;
          },
          child: CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                sliver: SliverList.builder(
                  itemCount: math.max(0, widget.messages.length - 1),
                  itemBuilder: (context, index) =>
                      _message(widget.messages[index]),
                ),
              ),
              if (widget.messages.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  // This adapter measures the newest reply even offscreen;
                  // older messages remain lazily built.
                  sliver: SliverToBoxAdapter(
                    child: SizedBox(
                      key: _latest,
                      child: _message(widget.messages.last),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
