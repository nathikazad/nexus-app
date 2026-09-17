import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Short, interruptible navigation motion; never animate the monetary values.
abstract final class ExpenseMotion {
  static const enter = Duration(milliseconds: 280);
  static const exit = Duration(milliseconds: 200);
  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.accessibleNavigationOf(context);

  static Page<void> page(
    BuildContext context,
    GoRouterState state,
    Widget child,
  ) {
    if (reduced(context)) {
      return NoTransitionPage(key: state.pageKey, child: child);
    }
    // Retain iOS's interactive swipe-back gesture on compact layouts.
    if (Theme.of(context).platform == TargetPlatform.iOS &&
        MediaQuery.sizeOf(context).width < 1100) {
      return CupertinoPage(key: state.pageKey, child: child);
    }
    final section = state.uri.pathSegments.length == 1;
    return CustomTransitionPage<void>(
      key: state.pageKey,
      transitionDuration: enter,
      reverseTransitionDuration: exit,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (reduced(context)) return child;
        final progress = animation.drive(
          CurveTween(curve: Curves.easeOutCubic),
        );
        return FadeTransition(
          opacity: progress,
          child: SlideTransition(
            position: progress.drive(
              Tween(
                begin: section ? const Offset(0, .018) : const Offset(.045, 0),
                end: Offset.zero,
              ),
            ),
            child: child,
          ),
        );
      },
    );
  }
}

/// Source panes enter without retaining an outgoing copy of editable content.
class PaneEntrance extends StatelessWidget {
  const PaneEntrance({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (ExpenseMotion.reduced(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: ExpenseMotion.enter,
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(10 * (1 - value), 0),
          child: child,
        ),
      ),
    );
  }
}

/// Pointer feedback complements the existing Material press/focus feedback.
class HoverLift extends StatefulWidget {
  const HoverLift({super.key, required this.child});
  final Widget child;
  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool hovering = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => hovering = true),
    onExit: (_) => setState(() => hovering = false),
    child: AnimatedContainer(
      duration: ExpenseMotion.reduced(context)
          ? Duration.zero
          : const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(
        0,
        hovering && !ExpenseMotion.reduced(context) ? -2 : 0,
        0,
      ),
      child: widget.child,
    ),
  );
}
