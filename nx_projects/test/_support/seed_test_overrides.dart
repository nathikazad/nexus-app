import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:nx_db/auth.dart';

import 'package:nx_projects/bootstrap/projects_auth.dart';
import 'package:nx_projects/data/fake/seed_data.dart';
import 'package:nx_projects/data/providers.dart';

/// Fakes in-memory data + dev auth so widget tests do not call GraphQL.
List<Override> get nxProjectsTestSeedOverrides => [
      authProvider.overrideWith(ProjectsAuthController.new),
      allProjectsAsyncProvider.overrideWith(
        (ref) async => buildSeedProjects(),
      ),
      tasksListAsyncProvider.overrideWith(
        (ref) async => buildSeedTasks(),
      ),
      sprintsListAsyncProvider.overrideWith(
        (ref) async => buildSeedSprints(),
      ),
    ];
