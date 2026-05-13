import 'package:nx_db/auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PeopleAuthController extends AuthController {
  PeopleAuthController({
    this.initialUser,
    super.initialDelay = Duration.zero,
    super.skipBackendPing = false,
  });

  final User? initialUser;

  @override
  Future<User?> build() async {
    if (initialDelay > Duration.zero) {
      await Future<void>.delayed(initialDelay);
    }
    return initialUser;
  }

  @override
  Future<void> logout() async {
    state = const AsyncValue.data(null);
  }
}
