part of 'nx_appflowy_blocks.dart';

/// Owns the editor's one active picker. OverlayPortal ties its lifetime to this
/// editor, so leaving a document cannot strand a menu in the app's root overlay.
class NxElementPickerScope extends StatefulWidget {
  const NxElementPickerScope({
    required this.child,
    this.enabled = true,
    super.key,
  });

  final Widget child;
  final bool enabled;

  @override
  State<NxElementPickerScope> createState() => _NxElementPickerScopeState();
}

class _NxElementPickerScopeState extends State<NxElementPickerScope> {
  final _portal = OverlayPortalController();
  Widget? _menu;
  Offset _anchor = Offset.zero;

  void open(Offset anchor, Widget menu) {
    if (!mounted || !widget.enabled) return;
    setState(() {
      _anchor = anchor;
      _menu = menu;
    });
    _portal.show();
  }

  void close() {
    if (!mounted) return;
    _portal.hide();
    setState(() => _menu = null);
  }

  @override
  void didUpdateWidget(NxElementPickerScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _menu = null;
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      // Building only lays out the existing session. Resources, focus, and the
      // AppFlowy service adapter belong to the menu's State, never this builder.
      overlayChildBuilder: (context) {
        final menu = _menu;
        if (menu == null) return const SizedBox.shrink();
        final viewport = MediaQuery.of(context);
        final left = (_anchor.dx + 8).clamp(
          8.0,
          math.max(8.0, viewport.size.width - 348),
        );
        final top = (_anchor.dy + 28).clamp(
          viewport.padding.top + 8,
          math.max(
            viewport.padding.top + 8,
            viewport.size.height - viewport.viewInsets.bottom - 328,
          ),
        );
        return Positioned(
          left: left.toDouble(),
          top: top.toDouble(),
          child: TapRegion(onTapOutside: (_) => close(), child: menu),
        );
      },
      child: widget.child,
    );
  }
}
