import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_auth/nx_auth.dart';
import 'package:nx_db/riverpod.dart';

import '../../domain/account/account.dart';
import '../../domain/account/account_repository.dart';
import 'kgql_account_repository.dart';

/// Resolves only when auth has loaded a non-null user.
final authenticatedUserProvider = FutureProvider<User>((ref) async {
  final user = await ref.watch(authProvider.future);
  if (user == null) {
    throw StateError('Not authenticated');
  }
  return user;
});

/// KGQL [AccountProfile] fetch with account preferences stored on `users.preferences`.
final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return KgqlAccountRepository(
    client: ref.watch(graphqlClientProvider),
    loadAuthenticatedUser: () => ref.read(authenticatedUserProvider.future),
  );
});

/// Current user's account row plus `users.preferences` JSON.
final currentAccountProvider = FutureProvider<AccountProfile?>((ref) async {
  await ref.watch(authenticatedUserProvider.future);
  return ref.watch(accountRepositoryProvider).getCurrent();
});
