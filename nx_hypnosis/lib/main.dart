import 'package:nx_voice/background_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_auth/nx_auth.dart';
import 'session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NxBackgroundAudioPlayer.initialize(
    channelId: 'io.kgql.nxHypnosis.playback',
    channelName: 'Hypnosis playback',
  );
  runApp(
    ProviderScope(
      overrides: [
        retainAuthSessionWhenOfflineProvider.overrideWithValue(!kIsWeb),
        nexusClientAppIdProvider.overrideWithValue(
          kIsWeb ? 'nx_hypnosis_web' : 'nx_hypnosis',
        ),
      ],
      child: const HypnosisSession(),
    ),
  );
}
