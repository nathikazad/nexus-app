// Local simulator entrypoint. Never used by the production main.dart.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_db/person.dart';
import 'package:nx_auth/nx_auth.dart';
import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/features/shell/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const bool release = bool.fromEnvironment('dart.vm.product');
  if (release) throw StateError('Demo entrypoint is debug-only');
  final user = User(
    userId: '3',
    preset: BackendPreset.localhost,
    domainId: 3,
    domainName: 'Calendar demo',
  );
  runApp(
    ProviderScope(
      overrides: [
        authenticatedUserProvider.overrideWith((ref) async => user),
        graphqlClientProvider.overrideWithValue(
          GraphQLClient(
            link: HttpLink('http://127.0.0.1:55440/graphql'),
            cache: GraphQLCache(),
          ),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const AppShell(),
      ),
    ),
  );
}
