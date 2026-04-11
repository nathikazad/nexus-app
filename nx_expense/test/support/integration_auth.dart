import 'dart:io';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:nx_db/nx_db.dart';

/// Live GraphQL at [kIntegrationTestBackendUrls] (localhost). The app preset
/// [BackendPreset.laptop] targets the LAN host (`10.0.0.90`).
class TestAuthController extends AuthController {
  @override
  Future<User?> build() async {
    return User(userId: '1', preset: BackendPreset.laptop);
  }
}

/// Overrides so integration tests hit localhost while [User.preset] stays [laptop].
List<Override> get expenseIntegrationOverrides => [
      authProvider.overrideWith(() => TestAuthController()),
      endpointProvider.overrideWith((ref) => kIntegrationTestBackendUrls.graphqlHttp),
      sockWsUrlProvider.overrideWith((ref) => kIntegrationTestBackendUrls.sockWs),
      imageBaseUrlProvider.overrideWith((ref) => kIntegrationTestBackendUrls.imageHttp),
    ];

bool get runExpenseIntegration =>
    Platform.environment['RUN_EXPENSE_INTEGRATION'] == 'true';

const kExpenseIntegrationSkipReason =
    'Set RUN_EXPENSE_INTEGRATION=true and run PGDB on localhost (see test/README.md)';
