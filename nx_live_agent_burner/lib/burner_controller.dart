import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:nx_live_agent/nx_live_agent.dart';

import 'weather_client.dart';

class BurnerController extends ChangeNotifier {
  BurnerController({
    LiveAgentSession? session,
    WeatherClient? weatherClient,
    Random? random,
  }) : _session =
           session ?? LiveAgentSession(transport: OpenAiRealtimeTransport()),
       _weatherClient = weatherClient ?? WeatherClient(),
       _random = random ?? Random.secure() {
    _lastInterruptionCount = _session.interruptionCount;
    _lastPhase = _session.phase;
    _session.addListener(_syncSession);
  }

  final LiveAgentSession _session;
  final WeatherClient _weatherClient;
  final Random _random;
  final List<String> _log = [];
  late int _lastInterruptionCount;
  late LiveAgentPhase _lastPhase;
  String? _lastError;

  LiveAgentPhase get phase => _session.phase;
  bool get muted => _session.muted;
  String get transcript => _session.transcript;
  String? get error => _session.error;
  List<String> get log => List.unmodifiable(_log);
  int get bargeInCount => _session.interruptionCount;
  bool get isRunning => switch (phase) {
    LiveAgentPhase.connecting ||
    LiveAgentPhase.listening ||
    LiveAgentPhase.thinking ||
    LiveAgentPhase.speaking ||
    LiveAgentPhase.paused => true,
    _ => false,
  };

  Future<void> start(String apiKey) async {
    _log.clear();
    _lastInterruptionCount = 0;
    _writeLog('session: starting');
    await _session.start(
      credentialProvider: StaticLiveAgentCredentialProvider(apiKey),
      spec: const LiveAgentSpec(
        instructions: '''
You are a cheerful, concise voice-stack test assistant.

This session validates uninterrupted conversation, background audio, user
barge-in, and function calling. Obey these rules:
- For any current-weather request, always call check_weather. Never invent live
  conditions. Include a country or region in ambiguous location names; in this
  test, plain "Kochi" means Kochi, Kerala, India.
- For any random-number request, always call generate_random_number. Never pick
  the number yourself.
- Read tool results naturally and mention that the tool succeeded.
- The user may interrupt at any time. Stop the old thought and answer the new
  request without complaining or restarting the session.
- Keep normal answers brief. Only give a deliberately long answer when asked so
  the user can test interruption.
''',
        initialContext:
            'Greet the user briefly, then immediately call '
            'generate_random_number for an integer from 1 through 100 and '
            'speak the result. This is the automatic startup validation.',
      ),
      tools: [
        CallbackLiveAgentTool(
          definition: const LiveAgentToolDefinition(
            name: 'check_weather',
            description:
                'Look up live current weather for a city or named location.',
            parameters: {
              'type': 'object',
              'properties': {
                'location': {
                  'type': 'string',
                  'description':
                      'City and country or region, such as Kochi, India.',
                },
              },
              'required': ['location'],
              'additionalProperties': false,
            },
          ),
          onInvoke: _checkWeather,
        ),
        CallbackLiveAgentTool(
          definition: const LiveAgentToolDefinition(
            name: 'generate_random_number',
            description:
                'Generate a cryptographically strong random integer in an '
                'inclusive range.',
            parameters: {
              'type': 'object',
              'properties': {
                'minimum': {
                  'type': 'integer',
                  'description': 'Inclusive lower bound. Defaults to 1.',
                },
                'maximum': {
                  'type': 'integer',
                  'description': 'Inclusive upper bound. Defaults to 100.',
                },
              },
              'additionalProperties': false,
            },
          ),
          onInvoke: _generateRandomNumber,
        ),
      ],
    );
  }

  Future<LiveAgentToolResult> _checkWeather(
    Map<String, Object?> arguments,
  ) async {
    final location = arguments['location']?.toString().trim() ?? '';
    _writeLog('tool check_weather: $location');
    try {
      final weather = await _weatherClient.current(location);
      _writeLog(
        'tool check_weather ✓ ${weather.place}, '
        '${weather.temperatureCelsius}°C ${weather.description}',
      );
      return LiveAgentToolResult({'ok': true, ...weather.toJson()});
    } catch (error) {
      _writeLog('tool check_weather ✗ $error');
      return LiveAgentToolResult({'ok': false, 'error': error.toString()});
    }
  }

  LiveAgentToolResult _generateRandomNumber(Map<String, Object?> arguments) {
    final minimum = _integer(arguments['minimum'], fallback: 1);
    final maximum = _integer(arguments['maximum'], fallback: 100);
    if (minimum < -1000000 || maximum > 1000000 || minimum > maximum) {
      _writeLog('tool generate_random_number ✗ invalid range');
      return const LiveAgentToolResult({
        'ok': false,
        'error': 'Use an ordered range between -1000000 and 1000000.',
      });
    }
    final value = minimum + _random.nextInt(maximum - minimum + 1);
    _writeLog('tool generate_random_number ✓ $minimum…$maximum → $value');
    return LiveAgentToolResult({
      'ok': true,
      'minimum': minimum,
      'maximum': maximum,
      'value': value,
    });
  }

  Future<void> askWeather() => _session.sendInstruction(
    'The user tapped a test shortcut. Call check_weather for Kochi, India, then '
    'speak the result.',
  );

  Future<void> askRandom() => _session.sendInstruction(
    'The user tapped a test shortcut. Call generate_random_number for an integer '
    'from 1 through 100, then speak the result.',
  );

  Future<void> askLongAnswer() => _session.sendInstruction(
    'Give a deliberately long spoken explanation of how rainbows form so the '
    'user has time to interrupt you.',
  );

  Future<void> interrupt() async {
    _writeLog('response: manually interrupted');
    await _session.interruptResponse();
  }

  Future<void> toggleMuted() => _session.toggleMuted();

  Future<void> stop() async {
    _writeLog('session: ended');
    await _session.stop();
  }

  void noteLifecycle(String state) {
    _writeLog('app lifecycle: $state');
  }

  void _syncSession() {
    if (phase != _lastPhase) {
      _lastPhase = phase;
      _writeLog('session phase: ${phase.name}');
    }
    if (error != null && error != _lastError) {
      _lastError = error;
      _writeLog('session error: $error');
    }
    if (_session.interruptionCount > _lastInterruptionCount) {
      _lastInterruptionCount = _session.interruptionCount;
      _writeLog('barge-in: detected while assistant was speaking');
    }
    notifyListeners();
  }

  void _writeLog(String value) {
    final now = DateTime.now();
    final timestamp =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    _log.add('[$timestamp] $value');
    developer.log(value, name: 'nx_live_agent_burner');
    stderr.writeln('nx_live_agent_burner: $value');
    notifyListeners();
  }

  int _integer(Object? value, {required int fallback}) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  @override
  void dispose() {
    _session.removeListener(_syncSession);
    _session.dispose();
    _weatherClient.dispose();
    super.dispose();
  }
}
