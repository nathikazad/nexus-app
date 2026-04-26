import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';

import 'package:nx_projects/app.dart';
import 'package:nx_projects/bootstrap/projects_auth.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(ProjectsAuthController.new),
      ],
      child: const NexusProjectsApp(),
    ),
  );
}
