import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/data/domains/domain_workspace.dart';
import 'package:nx_time/features/domains/time_domain_gate.dart';
import 'package:nx_time/features/settings/action_colors_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(timeDomainsProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          ListTile(
            leading: const Icon(
              Icons.layers_outlined,
              color: AppColors.slate500,
            ),
            title: const Text('Domain'),
            subtitle: Text(
              workspace == null
                  ? 'Loading…'
                  : workspace.name(workspace.selectedId),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: workspace == null
                ? null
                : () async {
                    try {
                      await showTimeDomains(context, ref);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Could not switch domain: $e'),
                          ),
                        );
                      }
                    }
                  },
          ),
          ListTile(
            leading: const Icon(
              Icons.palette_outlined,
              color: AppColors.slate500,
            ),
            title: const Text('Colors'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const ActionColorsPage()),
            ),
          ),
          const Divider(indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.slate500),
            title: const Text('Logout'),
            onTap: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
          ),
        ],
      ),
    );
  }
}
