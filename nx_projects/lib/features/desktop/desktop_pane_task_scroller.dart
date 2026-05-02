import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class DesktopPaneTaskScroller {
  final ScrollController controller = ScrollController();
  final Map<int, GlobalKey> _rowKeys = <int, GlobalKey>{};

  GlobalKey rowKeyFor(int taskId) {
    return _rowKeys.putIfAbsent(taskId, () => GlobalKey());
  }

  void scrollToTask(int taskId, {required bool Function() isMounted}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isMounted()) return;
      final context = _rowKeys[taskId]?.currentContext;
      if (context == null) return;
      final target = context.findRenderObject();
      if (target == null || !controller.hasClients) return;
      final viewport = RenderAbstractViewport.of(target);
      final revealed = viewport.getOffsetToReveal(target, 0.2).offset;
      final position = controller.position;
      final offset = revealed
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      controller.animateTo(
        offset,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void dispose() {
    controller.dispose();
  }
}
