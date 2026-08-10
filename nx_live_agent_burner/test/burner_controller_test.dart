import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_live_agent/nx_live_agent.dart';
import 'package:nx_live_agent_burner/burner_controller.dart';
import 'package:nx_live_agent_burner/weather_client.dart';

class _FakeTransport implements LiveAgentTransport {
  final controller = StreamController<LiveAgentEvent>.broadcast();
  final results = <String, Object?>{};
  List<LiveAgentToolDefinition> tools = const [];
  int cancels = 0;

  @override
  Stream<LiveAgentEvent> get events => controller.stream;

  @override
  Future<void> connect({
    required String credential,
    required LiveAgentSpec spec,
    required List<LiveAgentToolDefinition> tools,
  }) async {
    this.tools = tools;
    controller.add(const LiveAgentEvent(LiveAgentEventType.connected));
  }

  void call(String id, String name, Map<String, Object?> arguments) {
    controller.add(
      LiveAgentEvent(
        LiveAgentEventType.toolCall,
        toolCall: LiveAgentToolCall(
          callId: id,
          name: name,
          arguments: arguments,
        ),
      ),
    );
  }

  @override
  Future<void> sendToolResult(String callId, Object? output) async {
    results[callId] = output;
  }

  @override
  Future<void> discardConversation({
    Set<String> keepItemIds = const {},
  }) async {}

  @override
  Future<void> cancelResponse() async => cancels += 1;

  @override
  Future<void> close() async {}

  @override
  Future<void> dispose() async => controller.close();

  @override
  Future<void> requestResponse() async {}

  @override
  Future<void> sendInstruction(
    String text, {
    bool requestResponse = true,
  }) async {}

  @override
  Future<void> setMuted(bool muted) async {}
}

class _FakeWeatherClient extends WeatherClient {
  @override
  Future<CurrentWeather> current(String location) async => const CurrentWeather(
    place: 'Kochi, Kerala, India',
    latitude: 9.94,
    longitude: 76.26,
    temperatureCelsius: 29,
    apparentTemperatureCelsius: 34,
    windSpeedKph: 12,
    weatherCode: 61,
    observedAt: '2026-08-08T12:00',
  );
}

void main() {
  test('registers and executes both burner tools', () async {
    final transport = _FakeTransport();
    final controller = BurnerController(
      session: LiveAgentSession(transport: transport),
      weatherClient: _FakeWeatherClient(),
      random: Random(7),
    );

    await controller.start('test-key');
    expect(
      transport.tools.map((tool) => tool.name),
      containsAll(['check_weather', 'generate_random_number']),
    );

    transport.call('weather', 'check_weather', {'location': 'Kochi'});
    transport.call('random', 'generate_random_number', {
      'minimum': 10,
      'maximum': 20,
    });
    await pumpEventQueue();

    expect((transport.results['weather'] as Map)['conditions'], 'rain');
    expect(
      (transport.results['random'] as Map)['value'],
      inInclusiveRange(10, 20),
    );
    expect(controller.log.join('\n'), contains('check_weather ✓'));
    expect(controller.log.join('\n'), contains('generate_random_number ✓'));

    await controller.interrupt();
    expect(transport.cancels, 1);
    controller.dispose();
  });
}
