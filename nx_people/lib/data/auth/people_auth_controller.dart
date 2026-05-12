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
  Future<String?> login(
    String userId,
    BackendPreset preset,
    int personalDomainId,
    int homeDomainId,
  ) async {
    state = const AsyncValue.loading();
    try {
      if (userId.isEmpty) {
        throw Exception('User ID is required');
      }
      if (personalDomainId <= 0 || homeDomainId <= 0) {
        throw Exception(
          'Personal and home domain IDs must be positive integers',
        );
      }

      final urls = resolve(preset);
      if (!skipBackendPing) {
        await pingGraphqlBackend(
          graphqlHttpUrl: urls.graphqlHttp,
          userId: userId,
        );
      }

      final user = User(
        userId: userId,
        personalDomainId: personalDomainId,
        homeDomainId: homeDomainId,
        preset: preset,
      );
      state = AsyncValue.data(user);
      return null;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return error.toString().replaceFirst('Exception: ', '');
    }
  }

  @override
  Future<void> logout() async {
    state = const AsyncValue.data(null);
  }
}
