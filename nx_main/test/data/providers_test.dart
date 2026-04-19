import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/data/providers.dart';
import 'package:nexus_voice_assistant/domain/battery/battery_repository.dart';
import 'package:nexus_voice_assistant/domain/images/image_repository.dart';

void main() {
  test('provider container resolves image and battery repositories', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(imageRepositoryProvider), isA<ImageRepository>());
    expect(container.read(batteryRepositoryProvider), isA<BatteryRepository>());
    expect(
      container.read(voiceTranscriptSourceProvider),
      isA<VoiceTranscriptSource>(),
    );
    expect(
      container.read(kgqlModelRepositoryProvider),
      isA<KgqlModelRepository>(),
    );
  });
}
