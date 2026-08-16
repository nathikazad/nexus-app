import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_books/app.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_db/auth.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      overrides: [
        dbAuditSourceKindProvider.overrideWithValue('nx_books'),
        nexusClientAppIdProvider.overrideWithValue('nx_books'),
      ],
      child: const NexusBooksApp(),
    ),
  );
}
