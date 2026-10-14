import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_people/core/theme/app_theme.dart';

class PeopleSettingsPage extends ConsumerStatefulWidget {
  const PeopleSettingsPage({super.key});
  @override
  ConsumerState<PeopleSettingsPage> createState() => _PeopleSettingsPageState();
}

class _PeopleSettingsPageState extends ConsumerState<PeopleSettingsPage> {
  bool busy = false;
  String? error;

  Future<void> run(Future<void> Function() action, String failure) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) setState(() => error = failure);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.1,
        color: AppColors.muted,
      ),
    ),
  );

  Widget group(Widget child) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.line),
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Settings', style: peopleEditorialTitle(30)),
        const SizedBox(height: 32),
        label('ACCOUNT'),
        group(
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: Color(0xffe8eae6),
                  child: Icon(Icons.person_outline, color: AppColors.green),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Signed in',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.preset.label ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        label('SWITCH DOMAIN'),
        ref
            .watch(domainMembershipsProvider)
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => TextButton(
                onPressed: () => ref.invalidate(domainMembershipsProvider),
                child: const Text('Could not load domains. Retry'),
              ),
              data: (domains) => group(
                Column(
                  children: [
                    if (domains.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No domains available.'),
                      ),
                    for (var i = 0; i < domains.length; i++) ...[
                      if (i > 0)
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: AppColors.line,
                        ),
                      Material(
                        color: domains[i].id == user?.domainId
                            ? const Color(0xfff6f8f6)
                            : Colors.white,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          leading: Icon(
                            domains[i].kind == 'personal'
                                ? Icons.person_outline
                                : Icons.home_outlined,
                            size: 20,
                            color: domains[i].id == user?.domainId
                                ? AppColors.green
                                : AppColors.muted,
                          ),
                          title: Text(
                            domains[i].name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: domains[i].id == user?.domainId
                                  ? AppColors.green
                                  : null,
                            ),
                          ),
                          trailing: domains[i].id == user?.domainId
                              ? const Icon(
                                  Icons.check_circle_outline,
                                  size: 20,
                                  color: AppColors.green,
                                )
                              : null,
                          onTap: busy || domains[i].id == user?.domainId
                              ? null
                              : () => run(
                                  () => ref
                                      .read(authProvider.notifier)
                                      .selectDomain(domains[i].id),
                                  'Could not switch domain. Please retry.',
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        const SizedBox(height: 32),
        group(
          Material(
            color: Colors.white,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              leading: const Icon(Icons.logout, size: 20, color: AppColors.red),
              title: const Text(
                'Log out',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.red,
                ),
              ),
              onTap: busy
                  ? null
                  : () => run(
                      () => ref.read(authProvider.notifier).logout(),
                      'Could not log out. Please retry.',
                    ),
            ),
          ),
        ),
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(error!, style: const TextStyle(color: AppColors.red)),
          ),
      ],
    );
  }
}
