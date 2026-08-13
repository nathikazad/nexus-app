import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DocumentTextScaleNotifier extends Notifier<double> {
  static const preferenceKey = 'nx_notes.reader.text_scale';
  static const defaultScale = 1.0;
  static const minimumScale = 0.7;
  static const maximumScale = 2.0;
  static const scaleStep = 0.1;

  var _changedInThisSession = false;
  var _disposed = false;

  @override
  double build() {
    ref.onDispose(() => _disposed = true);
    unawaited(_restore());
    return defaultScale;
  }

  void increase() => _setScale(state + scaleStep);

  void decrease() => _setScale(state - scaleStep);

  void _setScale(double value) {
    _changedInThisSession = true;
    state = _normalized(value);
    unawaited(_persist(state));
  }

  Future<void> _restore() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = preferences.getDouble(preferenceKey);
      if (_disposed || _changedInThisSession || saved == null) return;
      state = _normalized(saved);
    } catch (_) {
      // Keep the default scale when local preferences are unavailable.
    }
  }

  Future<void> _persist(double value) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setDouble(preferenceKey, value);
    } catch (_) {
      // The in-memory scale still applies for the current session.
    }
  }

  static double _normalized(double value) {
    final clamped = value.clamp(minimumScale, maximumScale).toDouble();
    return (clamped * 10).roundToDouble() / 10;
  }
}

final documentTextScaleProvider =
    NotifierProvider<DocumentTextScaleNotifier, double>(
      DocumentTextScaleNotifier.new,
    );

class DocumentTextScaleShortcuts extends ConsumerWidget {
  const DocumentTextScaleShortcuts({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.equal, meta: true):
            _IncreaseDocumentTextIntent(),
        SingleActivator(LogicalKeyboardKey.equal, meta: true, shift: true):
            _IncreaseDocumentTextIntent(),
        SingleActivator(LogicalKeyboardKey.add, meta: true):
            _IncreaseDocumentTextIntent(),
        SingleActivator(LogicalKeyboardKey.add, meta: true, shift: true):
            _IncreaseDocumentTextIntent(),
        SingleActivator(LogicalKeyboardKey.numpadAdd, meta: true):
            _IncreaseDocumentTextIntent(),
        SingleActivator(LogicalKeyboardKey.minus, meta: true):
            _DecreaseDocumentTextIntent(),
        SingleActivator(LogicalKeyboardKey.numpadSubtract, meta: true):
            _DecreaseDocumentTextIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _IncreaseDocumentTextIntent:
              CallbackAction<_IncreaseDocumentTextIntent>(
                onInvoke: (_) {
                  ref.read(documentTextScaleProvider.notifier).increase();
                  return null;
                },
              ),
          _DecreaseDocumentTextIntent:
              CallbackAction<_DecreaseDocumentTextIntent>(
                onInvoke: (_) {
                  ref.read(documentTextScaleProvider.notifier).decrease();
                  return null;
                },
              ),
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}

class _IncreaseDocumentTextIntent extends Intent {
  const _IncreaseDocumentTextIntent();
}

class _DecreaseDocumentTextIntent extends Intent {
  const _DecreaseDocumentTextIntent();
}
