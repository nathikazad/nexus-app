import 'package:nx_db/auth.dart';

class PeopleAuthController extends AuthController {
  PeopleAuthController({
    this.initialUser,
    super.initialDelay = Duration.zero,
    super.skipBackendPing = true,
  });

  final User? initialUser;

  @override
  Future<User?> build() async {
    if (initialUser != null) return initialUser;
    return super.build();
  }
}
