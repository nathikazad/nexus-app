import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import '../../data/devices/device_registry.dart';

final _registryProvider = Provider.autoDispose<DeviceRegistry?>((ref) {
  final user = ref.watch(authProvider).value;
  if (user == null) return null;
  final registry = DeviceRegistry(user);
  ref.onDispose(registry.close);
  return registry;
});
final _devicesProvider = FutureProvider.autoDispose((ref) async =>
    await ref.watch(_registryProvider)?.list() ?? <Map<String, dynamic>>[]);

class DevicesPage extends ConsumerStatefulWidget {
  const DevicesPage({super.key});
  @override
  ConsumerState<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends ConsumerState<DevicesPage> {
  bool _busy = false;
  Map<String, dynamic>? _pairing;
  String? _error;
  Future<void> _run(Future<void> Function(DeviceRegistry) action) async {
    final registry = ref.read(_registryProvider);
    if (registry == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action(registry);
      ref.invalidate(_devicesProvider);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Could not update devices. Please retry.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Clear the short-lived enrollment secret when account/server changes.
    ref.listen(_registryProvider, (previous, next) {
      if (previous != next && mounted) setState(() => _pairing = null);
    });
    final devices = ref.watch(_devicesProvider);
    return Scaffold(
        appBar: AppBar(title: const Text('Wi-Fi devices'), actions: [
          IconButton(
              onPressed: () => ref.invalidate(_devicesProvider),
              icon: const Icon(Icons.refresh))
        ]),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          const Text(
              'Devices belong to your account and can query your accessible domains.'),
          const SizedBox(height: 16),
          for (final type in ['sleepbot_assistant', 'sleepbot_radar'])
            FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run((registry) async {
                          final pairing = await registry.pair(type);
                          if (mounted &&
                              ref.read(_registryProvider) == registry) {
                            setState(() => _pairing = pairing);
                          }
                        }),
                child: Text(type == 'sleepbot_assistant'
                    ? 'Pair SleepBot Assistant'
                    : 'Pair SleepBot Radar')),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          if (_pairing != null)
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Pairing setup • expires in 15 minutes'),
                          const Text(
                              'Copy this setup into the USB provisioning tool for this board. Keep it private. Refresh after pairing to verify Active.'),
                          SelectableText(jsonEncode(_pairing)),
                          TextButton(
                              onPressed: () => setState(() => _pairing = null),
                              child: const Text('Hide setup')),
                        ]))),
          const SizedBox(height: 20),
          ...devices.when(
              data: (rows) => rows
                  .map((row) => ListTile(
                      title: Text(row['name'] as String),
                      subtitle: Text(row['status'] as String),
                      trailing: row['status'] == 'revoked'
                          ? null
                          : PopupMenuButton<String>(
                              enabled: !_busy,
                              onSelected: (action) => _run((registry) async {
                                if (action == 'renew') {
                                  final setup = await registry
                                      .renewPairing(row['id'] as String);
                                  if (mounted &&
                                      ref.read(_registryProvider) == registry) {
                                    setState(() => _pairing = setup);
                                  }
                                } else {
                                  await registry.revoke(row['id'] as String);
                                  if (mounted) setState(() => _pairing = null);
                                }
                              }),
                              itemBuilder: (_) => [
                                if (row['status'] == 'pending')
                                  const PopupMenuItem(
                                      value: 'renew',
                                      child: Text('Refresh pairing setup')),
                                const PopupMenuItem(
                                    value: 'revoke', child: Text('Revoke')),
                              ],
                            )))
                  .toList(),
              loading: () => [const LinearProgressIndicator()],
              error: (e, st) => [
                    const Text('Could not load devices. Tap refresh to retry.')
                  ]),
        ]));
  }
}
