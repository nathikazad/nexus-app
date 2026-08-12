import 'package:flutter_test/flutter_test.dart';
import 'package:nx_live_agent/nx_live_agent.dart';

void main() {
  test('manual record and send preserves manual VAD mode', () async {
    final calls = <String>[];
    final controller = _controller(calls);

    await controller.toggleTurnDetection();
    expect(calls, ['input:false', 'vad:false', 'clear']);
    expect(controller.turnDetection, LiveAgentTurnDetectionMode.manual);
    expect(controller.inputState, LiveAgentInputState.inactive);

    calls.clear();
    await controller.activateMicrophone();
    expect(calls, ['clear', 'input:true']);
    expect(controller.inputState, LiveAgentInputState.recording);

    calls.clear();
    await controller.activateMicrophone();
    expect(calls, ['input:false', 'commit', 'response']);
    expect(controller.inputState, LiveAgentInputState.inactive);
    expect(controller.turnDetection, LiveAgentTurnDetectionMode.manual);
  });

  test('returning to VAD discards a manual recording', () async {
    final calls = <String>[];
    final controller = _controller(calls);
    await controller.toggleTurnDetection();
    await controller.activateMicrophone();
    calls.clear();

    await controller.toggleTurnDetection();

    expect(calls, ['input:false', 'clear', 'vad:true', 'input:true']);
    expect(controller.turnDetection, LiveAgentTurnDetectionMode.automatic);
    expect(controller.inputState, LiveAgentInputState.active);
  });

  test('automatic mute only changes the input gate', () async {
    final calls = <String>[];
    final controller = _controller(calls);

    await controller.activateMicrophone();
    await controller.activateMicrophone();

    expect(calls, ['input:false', 'input:true']);
    expect(controller.inputState, LiveAgentInputState.active);
  });

  test('rapid manual record and send actions execute in order', () async {
    final calls = <String>[];
    final controller = _controller(calls);
    await controller.toggleTurnDetection();
    calls.clear();

    final record = controller.activateMicrophone();
    final send = controller.activateMicrophone();
    await Future.wait([record, send]);

    expect(calls, ['clear', 'input:true', 'input:false', 'commit', 'response']);
    expect(controller.inputState, LiveAgentInputState.inactive);
  });
}

LiveAgentInputController _controller(List<String> calls) =>
    LiveAgentInputController(
      setInputEnabled: (enabled) async => calls.add('input:$enabled'),
      setAutomaticTurnDetection: (enabled) async => calls.add('vad:$enabled'),
      clearInputAudio: () async => calls.add('clear'),
      commitInputAudio: () async => calls.add('commit'),
      requestResponse: () async => calls.add('response'),
    );
