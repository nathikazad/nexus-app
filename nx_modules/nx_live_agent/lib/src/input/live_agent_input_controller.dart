import 'dart:async';

import 'package:flutter/foundation.dart';

enum LiveAgentTurnDetectionMode { automatic, manual }

enum LiveAgentInputState { active, muted, inactive, recording, submitting }

/// Owns turn detection and microphone upload state independently of playback.
///
/// The native microphone may stay warm, but [setInputEnabled] is the local
/// privacy/upload gate. No operation in this controller can pause or cancel
/// assistant output.
final class LiveAgentInputController extends ChangeNotifier {
  LiveAgentInputController({
    required Future<void> Function(bool enabled) setInputEnabled,
    required Future<void> Function(bool enabled) setAutomaticTurnDetection,
    required Future<void> Function() clearInputAudio,
    required Future<void> Function() commitInputAudio,
    required Future<void> Function() requestResponse,
  }) : _setInputEnabled = setInputEnabled,
       _setAutomaticTurnDetection = setAutomaticTurnDetection,
       _clearInputAudio = clearInputAudio,
       _commitInputAudio = commitInputAudio,
       _requestResponse = requestResponse;

  final Future<void> Function(bool enabled) _setInputEnabled;
  final Future<void> Function(bool enabled) _setAutomaticTurnDetection;
  final Future<void> Function() _clearInputAudio;
  final Future<void> Function() _commitInputAudio;
  final Future<void> Function() _requestResponse;

  LiveAgentTurnDetectionMode _turnDetection =
      LiveAgentTurnDetectionMode.automatic;
  LiveAgentInputState _inputState = LiveAgentInputState.active;
  bool _automaticMuted = false;
  bool _suspended = false;
  bool _busy = false;
  Future<void> _commandTail = Future<void>.value();

  LiveAgentTurnDetectionMode get turnDetection => _turnDetection;
  LiveAgentInputState get inputState => _inputState;
  bool get automaticMuted => _automaticMuted;
  bool get suspended => _suspended;
  bool get busy => _busy;

  Future<void> toggleTurnDetection() => _run(() async {
    if (_turnDetection == LiveAgentTurnDetectionMode.automatic) {
      await _setInputEnabled(false);
      await _setAutomaticTurnDetection(false);
      await _clearInputAudio();
      _turnDetection = LiveAgentTurnDetectionMode.manual;
      _inputState = LiveAgentInputState.inactive;
      return;
    }

    // Returning to VAD always discards an unfinished manual recording.
    await _setInputEnabled(false);
    await _clearInputAudio();
    await _setAutomaticTurnDetection(true);
    final shouldEnable = !_automaticMuted && !_suspended;
    await _setInputEnabled(shouldEnable);
    _turnDetection = LiveAgentTurnDetectionMode.automatic;
    _inputState = _automaticMuted
        ? LiveAgentInputState.muted
        : LiveAgentInputState.active;
  });

  Future<void> activateMicrophone() => _run(() async {
    if (_turnDetection == LiveAgentTurnDetectionMode.automatic) {
      final nextMuted = !_automaticMuted;
      await _setInputEnabled(!nextMuted && !_suspended);
      _automaticMuted = nextMuted;
      _inputState = nextMuted
          ? LiveAgentInputState.muted
          : LiveAgentInputState.active;
      return;
    }

    switch (_inputState) {
      case LiveAgentInputState.inactive:
        await _clearInputAudio();
        await _setInputEnabled(!_suspended);
        _inputState = LiveAgentInputState.recording;
      case LiveAgentInputState.recording:
        _inputState = LiveAgentInputState.submitting;
        notifyListeners();
        await _setInputEnabled(false);
        await _commitInputAudio();
        await _requestResponse();
        _inputState = LiveAgentInputState.inactive;
      case LiveAgentInputState.active ||
          LiveAgentInputState.muted ||
          LiveAgentInputState.submitting:
        return;
    }
  });

  Future<void> setSuspended(bool suspended) => _run(() async {
    if (_suspended == suspended) return;
    _suspended = suspended;
    if (suspended) {
      await _setInputEnabled(false);
      return;
    }
    final shouldEnable = switch ((_turnDetection, _inputState)) {
      (LiveAgentTurnDetectionMode.automatic, LiveAgentInputState.active) =>
        true,
      (LiveAgentTurnDetectionMode.manual, LiveAgentInputState.recording) =>
        true,
      _ => false,
    };
    await _setInputEnabled(shouldEnable);
  });

  Future<void> _run(Future<void> Function() operation) async {
    final completion = Completer<void>();
    _commandTail = _commandTail.then((_) async {
      _busy = true;
      notifyListeners();
      try {
        await operation();
        completion.complete();
      } catch (error, stackTrace) {
        completion.completeError(error, stackTrace);
      } finally {
        _busy = false;
        notifyListeners();
      }
    });
    return completion.future;
  }

  void reset({
    LiveAgentTurnDetectionMode turnDetection =
        LiveAgentTurnDetectionMode.automatic,
  }) {
    _turnDetection = turnDetection;
    _inputState = turnDetection == LiveAgentTurnDetectionMode.automatic
        ? LiveAgentInputState.active
        : LiveAgentInputState.inactive;
    _automaticMuted = false;
    _suspended = false;
    _busy = false;
    notifyListeners();
  }
}
