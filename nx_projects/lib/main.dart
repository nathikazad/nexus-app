import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/app.dart';
import 'package:nx_projects/core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeAppThemeMode();
  runApp(const ProviderScope(child: NexusProjectsApp()));
}
