import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_voice_assistant/data/background/background_service.dart';
import 'package:nexus_voice_assistant/data/battery/battery_repository.dart'
    as data_battery;
import 'package:nexus_voice_assistant/data/gps/gps_repository.dart' as data_gps;
import 'package:nexus_voice_assistant/data/hardware/hardware_service.dart';
import 'package:nexus_voice_assistant/data/watch/watch_bridge_service.dart';
import 'package:nexus_voice_assistant/data/watch/watch_voice_relay.dart';
import 'package:nexus_voice_assistant/domain/battery/battery_repository.dart';
import 'package:nexus_voice_assistant/domain/gps/gps_repository.dart';

export 'package:nx_db/nx_db.dart' show imageRepositoryProvider;

export 'package:nexus_voice_assistant/data/schema/kgql_model_type_repository.dart'
    show modelTypeWriteRepositoryProvider;
export 'package:nexus_voice_assistant/data/schema/kgql_model_repository.dart';
export 'package:nexus_voice_assistant/data/schema/kgql_schema_providers.dart';
export 'package:nexus_voice_assistant/data/voice/voice_transcript_notifier.dart';
export 'package:nexus_voice_assistant/data/voice/voice_transcript_source.dart';

/// Central composition root: service and repository providers.
final bleBackgroundServiceProvider = Provider<BleBackgroundService>((ref) {
  return BleBackgroundService();
});

final hardwareServiceProvider = Provider<HardwareService>((ref) {
  final bgService = ref.watch(bleBackgroundServiceProvider);
  return HardwareService(bgService);
});

final watchVoiceRelayProvider = Provider<WatchVoiceRelay>((ref) {
  final relay = WatchVoiceRelay(bridge: WatchBridgeService.instance);
  ref.onDispose(() {
    unawaited(relay.dispose());
  });
  return relay;
});

final batteryRepositoryProvider = Provider<BatteryRepository>((ref) {
  return data_battery.HttpBatteryRepository();
});

final gpsRepositoryProvider = Provider<GpsRepository>((ref) {
  return data_gps.HttpGpsRepository();
});
