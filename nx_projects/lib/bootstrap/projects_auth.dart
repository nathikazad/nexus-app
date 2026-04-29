import 'package:nx_db/auth.dart';

/// Development default: user `1` on [BackendPreset.localhost] (Docker PGDB / `127.0.0.1` GraphQL).
class ProjectsAuthController extends AuthController {
  ProjectsAuthController()
      : super(initialDelay: Duration.zero, skipBackendPing: true);

  @override
  Future<User?> build() async {
    return User(
      userId: '1',
      personalDomainId: 1,
      homeDomainId: 1,
      preset: BackendPreset.localhost,
    );
  }
}
