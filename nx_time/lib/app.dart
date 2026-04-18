import 'package:flutter/material.dart';

import 'features/shell/app_shell.dart';
import 'theme/app_theme.dart';

class NxTimeApp extends StatelessWidget {
  const NxTimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nexus Time',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AppShell(),
    );
  }
}
