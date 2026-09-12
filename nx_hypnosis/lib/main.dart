import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_auth/nx_auth.dart';
import 'session.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      overrides: [
        nexusClientAppIdProvider.overrideWithValue(
          kIsWeb ? 'nx_hypnosis_web' : 'nx_hypnosis',
        ),
      ],
      child: const HypnosisSession(),
    ),
  );
}
