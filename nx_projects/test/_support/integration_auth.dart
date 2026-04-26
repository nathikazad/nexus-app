import 'dart:io';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:nx_db/auth.dart';

/// Live GraphQL at [kIntegrationTestBackendUrls] (127.0.0.1).
class TestAuthController extends AuthController {
  @override
  Future<User?> build() async {
    return User(userId: '1', preset: BackendPreset.laptop);
  }
}

List<Override> get projectsIntegrationOverrides => [
      authProvider.overrideWith(TestAuthController.new),
      endpointProvider.overrideWith((ref) => kIntegrationTestBackendUrls.graphqlHttp),
      sockWsUrlProvider.overrideWith((ref) => kIntegrationTestBackendUrls.sockWs),
      imageBaseUrlProvider.overrideWith((ref) => kIntegrationTestBackendUrls.imageHttp),
    ];

bool get runProjectsIntegration =>
    Platform.environment['RUN_NX_PROJECTS_INTEGRATION'] == 'true';

const kProjectsIntegrationSkipReason =
    'Set RUN_NX_PROJECTS_INTEGRATION=true and run PGDB on localhost with nx_projects seed (see test/README.md)';
