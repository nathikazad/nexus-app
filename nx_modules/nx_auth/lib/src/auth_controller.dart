import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend_presets.dart';
import 'oidc_service.dart';
import 'user.dart';
import 'session_availability.dart';
import 'domain_session.dart';
import 'startup_timing.dart';

typedef OidcSessionRestore =
    Future<NexusIdentity?> Function(BackendPreset preset, String clientAppId);

final oidcSessionRestoreProvider = Provider<OidcSessionRestore>(
  (ref) => nexusOidcService.restore,
);

final oidcSessionRejectionsProvider = Provider<Stream<RejectedOidcSession>>(
  (ref) => nexusOidcService.rejections,
);

final retainAuthSessionWhenOfflineProvider = Provider<bool>((ref) => false);

/// Only apps with an account/domain-scoped offline library may open locally
/// before network validation. Other applications keep their existing policy.
final restoreCachedSessionImmediatelyProvider = Provider<bool>(
  (ref) =>
      !kIsWeb &&
      const {
        'nx_expense',
        'nx_books',
        'nx_cards',
        'nx_docs',
      }.contains(ref.watch(nexusClientAppIdProvider)),
);

/// App cleanup that needs the still-authenticated session (e.g. push tokens).
final beforeLogoutProvider = Provider<Future<void> Function(User)>(
  (ref) => (_) async {},
);

/// Stable identifier used to select this installed app's native OIDC client.
final nexusClientAppIdProvider = Provider<String>((ref) => 'nx_mobile');

class AuthController extends AsyncNotifier<User?> {
  AuthController({
    this.initialDelay = const Duration(seconds: 1),
    this.skipBackendPing = false,
  });

  int _generation = 0;
  final Duration initialDelay;
  final bool skipBackendPing;

  static Future<void> _clearSessionPrefs(SharedPreferences prefs) async {
    await prefs.remove(PrefsKeys.userId);
    await prefs.remove(PrefsKeys.endpoint);
    await prefs.remove(PrefsKeys.backendPreset);
    await prefs.remove(PrefsKeys.sockWsUrl);
  }

  @override
  Future<User?> build() async {
    final generation = ++_generation;
    final subscription = ref.read(oidcSessionRejectionsProvider).listen((
      event,
    ) {
      final user = state.value;
      if (user == null ||
          user.preset != event.preset ||
          ref.read(nexusClientAppIdProvider) != event.clientAppId)
        return;
      unawaited(_rejectCurrentSession(user, _generation));
    });
    ref.onDispose(subscription.cancel);
    final openLocally = ref.read(restoreCachedSessionImmediatelyProvider);
    if (!openLocally && initialDelay > Duration.zero)
      await Future.delayed(initialDelay);
    print('[AuthController] build() - Initializing auth state');

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(PrefsKeys.userId);
      // Migrate the previous session before an expired token can clear it.
      if (userId != null &&
          userId.isNotEmpty &&
          !prefs.containsKey(PrefsKeys.lastUserId)) {
        await prefs.setString(PrefsKeys.lastUserId, userId);
      }
      final presetKey = prefs.getString(PrefsKeys.backendPreset);
      BackendPreset? preset = BackendPreset.fromKey(presetKey);

      if (userId != null &&
          userId.isNotEmpty &&
          preset == null &&
          prefs.getString(PrefsKeys.endpoint) != null) {
        preset = BackendPreset.defaultPreset;
        final urls = resolve(preset);
        await prefs.setString(PrefsKeys.backendPreset, preset.key);
        await prefs.setString(PrefsKeys.endpoint, urls.graphqlHttp);
        await prefs.setString(PrefsKeys.sockWsUrl, urls.sockWs);
        print('[AuthController] Migrated legacy prefs to preset=${preset.key}');
      }

      if (preset != null &&
          userId != null &&
          userId.isNotEmpty &&
          openLocally &&
          ref.read(retainAuthSessionWhenOfflineProvider)) {
        final savedUser = User(userId: userId, preset: preset);
        final domain = prefs.getInt(_domainKey(savedUser));
        if (domain != null) {
          final cached = User(
            userId: userId,
            preset: preset,
            domainId: domain,
            domainName: prefs.getString('${_domainKey(savedUser)}.name'),
          );
          // Configure token access before any data clients can start. Network
          // validation is independent of publishing the exact saved partition.
          if (preset.requiresOidc) {
            nexusOidcService.prepareRestore(
              preset,
              ref.read(nexusClientAppIdProvider),
              userId: userId,
            );
          }
          final restore = ref.read(oidcSessionRestoreProvider);
          final domains = ref.read(domainLoaderProvider);
          final app = ref.read(nexusClientAppIdProvider);
          Timer.run(() {
            if (ref.mounted && generation == _generation) {
              unawaited(
                _validateCached(cached, generation, restore, domains, app),
              );
            }
          });
          StartupTiming.mark('cached_session_ready');
          return cached;
        }
      }

      if (preset != null && preset.requiresOidc) {
        print('[AuthController] Restoring OIDC session for ${preset.key}');
        nexusOidcService.prepareRestore(
          preset,
          ref.read(nexusClientAppIdProvider),
          userId: userId,
        );
        NexusIdentity? identity;
        try {
          identity = await ref.read(oidcSessionRestoreProvider)(
            preset,
            ref.read(nexusClientAppIdProvider),
          );
        } on AuthSessionRejected {
          await _clearSessionPrefs(prefs);
          return null;
        } on AuthServiceUnavailable {
          if (ref.read(retainAuthSessionWhenOfflineProvider) &&
              userId != null &&
              userId.isNotEmpty) {
            return await _restoreDomain(User(userId: userId, preset: preset));
          }
          rethrow;
        }
        if (identity == null) {
          await _clearSessionPrefs(prefs);
          return null;
        }
        await prefs.setString(PrefsKeys.userId, identity.userId);
        await prefs.setString(PrefsKeys.lastUserId, identity.userId);
        return await _restoreDomain(
          User(userId: identity.userId, preset: preset),
        );
      }

      if (userId != null && userId.isNotEmpty && preset != null) {
        print(
          '[AuthController] Found saved credentials: userId=$userId preset=${preset.key}',
        );
        return await _restoreDomain(User(userId: userId, preset: preset));
      }

      print('[AuthController] No saved credentials found');
      return null;
    } catch (e) {
      print('[AuthController] Error loading saved credentials: $e');
      return null;
    }
  }

  Future<void> _rejectCurrentSession(User user, int generation) async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted || generation != _generation || state.value != user)
      return;
    // Publish rejection immediately so routers leave the cached reader.
    // Keep the partition's cached files and pending edits for the next login.
    _generation++;
    state = const AsyncValue.data(null);
    await _clearSessionPrefs(prefs);
  }

  Future<void> _validateCached(
    User cached,
    int generation,
    OidcSessionRestore restore,
    DomainLoader loadDomains,
    String app,
  ) async {
    bool current() =>
        ref.mounted && generation == _generation && state.value == cached;
    try {
      if (cached.preset.requiresOidc) {
        final identity = await restore(cached.preset, app);
        if (!current()) return;
        if (identity == null || identity.userId != cached.userId) {
          throw const AuthSessionRejected();
        }
      }
      final memberships = await loadDomains(cached);
      StartupTiming.mark('session_validated');
      if (!current()) return;
      final selected = memberships
          .where((d) => d.id == cached.domainId)
          .firstOrNull;
      if (selected == null) {
        final prefs = await SharedPreferences.getInstance();
        if (!current()) return;
        await prefs.remove(_domainKey(cached));
        if (!current()) return;
        state = AsyncValue.data(
          User(userId: cached.userId, preset: cached.preset),
        );
      }
    } on AuthSessionRejected {
      if (!current()) return;
      final prefs = await SharedPreferences.getInstance();
      if (!current()) return;
      await _clearSessionPrefs(prefs);
      if (current()) state = const AsyncValue.data(null);
    } catch (_) {
      // Unavailable validation must not discard an explicitly saved local
      // session. Remote transports still require valid tokens and domain access.
      StartupTiming.mark('session_validation_unavailable');
    }
  }

  Future<String?> login(
    String userId,
    BackendPreset preset, {
    AuthLoginProfile? profile,
  }) async {
    final generation = ++_generation;
    print('[AuthController] login() - user: $userId preset: ${preset.key}');
    state = const AsyncValue.loading();

    try {
      if (userId.isEmpty && !preset.requiresOidc) {
        throw Exception('User ID is required');
      }
      final urls = resolve(preset);
      var resolvedUserId = userId;
      if (preset.requiresOidc) {
        final identity = await nexusOidcService.signIn(
          preset,
          ref.read(nexusClientAppIdProvider),
          profile: profile,
        );
        resolvedUserId = identity.userId;
      }

      if (generation != _generation || !ref.mounted) return 'Sign-in cancelled';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PrefsKeys.userId, resolvedUserId);
      await prefs.setString(PrefsKeys.endpoint, urls.graphqlHttp);
      await prefs.setString(PrefsKeys.backendPreset, preset.key);
      await prefs.setString(PrefsKeys.sockWsUrl, urls.sockWs);

      final user = await _restoreDomain(
        User(userId: resolvedUserId, preset: preset),
      );
      if (generation != _generation || !ref.mounted) return 'Sign-in cancelled';
      await prefs.setString(PrefsKeys.lastUserId, resolvedUserId);
      if (generation != _generation || !ref.mounted) return 'Sign-in cancelled';
      state = AsyncValue.data(user);
      print('[AuthController] Login successful');
      return null;
    } catch (e, stackTrace) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      print('[AuthController] Login error: $errorMessage');
      if (generation == _generation && ref.mounted)
        state = AsyncValue.error(e, stackTrace);
      return errorMessage;
    }
  }

  String _domainKey(User user) =>
      'nexus.domain.${user.preset.key}.${user.userId}';

  Future<User> _restoreDomain(User user) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_domainKey(user));
    List<DomainMembership> domains;
    try {
      domains = await ref.read(domainLoaderProvider)(user);
    } on AuthSessionRejected {
      await prefs.remove(_domainKey(user));
      rethrow;
    } on AuthServiceUnavailable {
      if (ref.read(retainAuthSessionWhenOfflineProvider) && saved != null) {
        return User(
          userId: user.userId,
          preset: user.preset,
          domainId: saved,
          domainName: prefs.getString('${_domainKey(user)}.name'),
        );
      }
      return user;
    }
    final candidates = domains.where((d) => d.id == saved).toList();
    // Restore only a previously selected, still accessible domain.
    // Even one membership requires explicit selection on first login.
    final selected = candidates.firstOrNull;
    if (selected == null) {
      await prefs.remove(_domainKey(user));
      return user;
    }
    await prefs.setInt(_domainKey(user), selected.id);
    await prefs.setString('${_domainKey(user)}.name', selected.name);
    return User(
      userId: user.userId,
      preset: user.preset,
      domainId: selected.id,
      domainName: selected.name,
    );
  }

  Future<void> selectDomain(int id) async {
    final user = state.value;
    if (user == null) return;
    final generation = ++_generation;
    final domains = await ref.read(domainLoaderProvider)(user);
    if (!ref.mounted || generation != _generation || state.value != user)
      return;
    final selected = domains.singleWhere((d) => d.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_domainKey(user), id);
    await prefs.setString('${_domainKey(user)}.name', selected.name);
    if (!ref.mounted || generation != _generation || state.value != user)
      return;
    state = AsyncValue.data(
      User(
        userId: user.userId,
        preset: user.preset,
        domainId: id,
        domainName: selected.name,
      ),
    );
  }

  void clearDomain() {
    _generation++;
    final user = state.value;
    if (user != null) {
      state = AsyncValue.data(User(userId: user.userId, preset: user.preset));
    }
  }

  Future<void> logout() async {
    _generation++;
    print('[AuthController] logout() - Logging out user');
    final currentUser = state.value;
    if (currentUser != null) {
      try {
        await ref.read(beforeLogoutProvider)(currentUser);
      } catch (_) {
        // Local logout must remain available when an app cleanup API is offline.
      }
    }
    state = const AsyncValue.loading();
    try {
      if (currentUser?.preset.requiresOidc ?? false) {
        await nexusOidcService.logout();
      }
      final prefs = await SharedPreferences.getInstance();
      await _clearSessionPrefs(prefs);
      state = const AsyncValue.data(null);
      print('[AuthController] Logout successful');
    } catch (e, stackTrace) {
      print('[AuthController] Logout error: $e');
      state = AsyncValue.error(e, stackTrace);
    }
  }
}

final authProvider = AsyncNotifierProvider<AuthController, User?>(
  AuthController.new,
  name: 'authProvider',
);
