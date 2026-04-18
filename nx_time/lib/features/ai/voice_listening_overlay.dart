import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Voice mode UI (`overlay-voice` in reference). Dimmed region stops above the ~80px bottom nav.
Future<void> showVoiceListeningOverlay(BuildContext context) {
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, _) {
        return FadeTransition(
          opacity: animation,
          child: const SizedBox.expand(child: _VoiceOverlayBody()),
        );
      },
    ),
  );
}

class _VoiceOverlayBody extends StatelessWidget {
  const _VoiceOverlayBody();

  static const double _navReserve = 80;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          bottom: _navReserve + bottom,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(color: const Color(0x660F172A)),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: _navReserve + bottom + 8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _VoiceMessagePair(),
              const SizedBox(height: 24),
              Center(child: _ListeningPill()),
            ],
          ),
        ),
      ],
    );
  }
}

class _VoiceMessagePair extends StatelessWidget {
  const _VoiceMessagePair();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.85),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(4),
              ),
              boxShadow: [BoxShadow(color: Color(0x26000000), blurRadius: 8)],
            ),
            child: const Text(
              'Move the blog post task to Monday',
              style: TextStyle(fontSize: 14, height: 1.45, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.85),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Done — moved 'Draft blog post outline' from today to Monday, Apr 20.",
                  style: TextStyle(fontSize: 14, height: 1.45, color: AppColors.slate900),
                ),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: AppColors.accent,
                  ),
                  child: const Text('Undo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ListeningPill extends StatefulWidget {
  @override
  State<_ListeningPill> createState() => _ListeningPillState();
}

class _ListeningPillState extends State<_ListeningPill> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            const Text(
              'Listening...',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.slate600),
            ),
            const SizedBox(width: 10),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(4, (i) {
                    final t = (_controller.value + i * 0.15) % 1.0;
                    final h = 6.0 + 8 * (0.5 + 0.5 * (t < 0.5 ? t * 2 : 2 - t * 2));
                    return Padding(
                      padding: const EdgeInsets.only(left: 3),
                      child: Container(
                        width: 2,
                        height: h,
                        decoration: BoxDecoration(
                          color: AppColors.slate300,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
