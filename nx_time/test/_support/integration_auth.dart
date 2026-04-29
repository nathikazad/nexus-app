import 'dart:io';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:nx_db/auth.dart';

/// Live GraphQL at [kIntegrationTestBackendUrls] (localhost). Matches nx_expense tests.
class TestAuthController extends AuthController {
  @override
  Future<User?> build() async {
    return User(
      userId: '1',
      personalDomainId: 1,
      homeDomainId: 1,
      preset: BackendPreset.laptop,
    );
  }
}

/// Overrides so integration tests hit localhost while [User.preset] stays [laptop].
List<Override> get timeIntegrationOverrides => [
      authProvider.overrideWith(() => TestAuthController()),
      endpointProvider.overrideWith((ref) => kIntegrationTestBackendUrls.graphqlHttp),
      sockWsUrlProvider.overrideWith((ref) => kIntegrationTestBackendUrls.sockWs),
      imageBaseUrlProvider.overrideWith((ref) => kIntegrationTestBackendUrls.imageHttp),
    ];

bool get runTimeIntegration =>
    Platform.environment['RUN_NX_TIME_INTEGRATION'] == 'true';

const kTimeIntegrationSkipReason =
    'Set RUN_NX_TIME_INTEGRATION=true and run PGDB on localhost (see test/README.md)';
