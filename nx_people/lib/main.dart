import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_people/app.dart';
import 'package:nx_people/data/auth/people_auth_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(PeopleAuthController.new),
        dbAuditSourceKindProvider.overrideWithValue('nx_people'),
      ],
      child: const NexusPeopleApp(),
    ),
  );
}
