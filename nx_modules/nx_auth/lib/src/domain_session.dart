import 'dart:convert';
import 'dart:async';
import 'session_availability.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'auth_controller.dart';
import 'backend_presets.dart';
import 'oidc_service.dart';
import 'user.dart';

class DomainMembership {
  const DomainMembership({
    required this.id,
    required this.name,
    required this.role,
  });
  final int id;
  final String name;
  final String role;
  bool get writable => role == 'owner' || role == 'member';
  factory DomainMembership.fromJson(Map<String, dynamic> json) =>
      DomainMembership(
        id: json['id'] as int,
        name: json['name'] as String,
        role: json['role'] as String,
      );
}

typedef DomainLoader = Future<List<DomainMembership>> Function(User user);
final domainLoaderProvider = Provider<DomainLoader>(
  (ref) => (user) async {
    final response = await withAuthAvailability(
      () async => http
          .get(
            Uri.parse('${resolve(user.preset).imageHttp}/v1/domains'),
            headers: await nexusAuthHeaders(user.preset, user.userId),
          )
          .timeout(const Duration(seconds: 15)),
    );
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const AuthSessionRejected();
    }
    if (response.statusCode >= 500) throw const AuthServiceUnavailable();
    if (response.statusCode != 200) {
      throw StateError('Could not load domains (${response.statusCode})');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return (json['domains'] as List)
        .map(
          (e) => DomainMembership.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  },
);

final domainMembershipsProvider = FutureProvider<List<DomainMembership>>((
  ref,
) async {
  final user = ref.watch(authProvider).value;
  if (user == null) return const [];
  return ref.watch(domainLoaderProvider)(user);
});

/// Blocks application data until a domain has been selected.
class DomainSessionGate extends ConsumerWidget {
  const DomainSessionGate({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    if (user == null) return child;
    if (user.domainId == null) {
      final domains = ref.watch(domainMembershipsProvider);
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Choose a domain',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    domains.when(
                      loading: () => const CircularProgressIndicator(),
                      error: (error, stack) => TextButton(
                        onPressed: () =>
                            ref.invalidate(domainMembershipsProvider),
                        child: const Text('Could not load domains. Retry'),
                      ),
                      data: (items) => Column(
                        children: [
                          if (items.isEmpty)
                            const Text(
                              'Your account has no domain memberships.',
                            ),
                          for (final domain in items)
                            ListTile(
                              title: Text(domain.name),
                              subtitle: Text(
                                domain.writable ? 'Can edit' : 'Read only',
                              ),
                              onTap: () async {
                                try {
                                  await ref
                                      .read(authProvider.notifier)
                                      .selectDomain(domain.id);
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Could not select this domain. Please retry.',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => ref.read(authProvider.notifier).logout(),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return KeyedSubtree(key: ValueKey(user.sessionKey), child: child);
  }
}

/// Account settings entry; the login gate owns the actual membership picker.
class DomainSettingsTile extends ConsumerWidget {
  const DomainSettingsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    if (user?.domainId == null) return const SizedBox.shrink();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.folder_outlined, size: 18),
      title: const Text('Domain'),
      subtitle: Text(user!.domainName ?? 'Domain ${user.domainId}'),
      trailing: TextButton(
        onPressed: () {
          final auth = ref.read(authProvider.notifier);
          Navigator.of(context).pop();
          auth.clearDomain();
        },
        child: const Text('Switch'),
      ),
    );
  }
}
