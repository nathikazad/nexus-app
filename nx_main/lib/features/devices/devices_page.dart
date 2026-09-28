import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import '../../data/devices/device_registry.dart';
import '../../data/devices/necklace_identity.dart';
import '../../data/devices/necklace_enrollment.dart';
import '../../data/hardware/paired_device_storage.dart';
import '../../data/providers.dart';
import '../hardware/device_selection_page.dart';

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
  String? _progress;
  void _stage(String text) {
    if (mounted) setState(() => _progress = text);
  }

  Future<void> _run(Future<void> Function(DeviceRegistry) action) async {
    final registry = ref.read(_registryProvider);
    if (registry == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _progress = null;
    });
    try {
      await action(registry);
      ref.invalidate(_devicesProvider);
    } catch (error) {
      if (mounted && ref.read(_registryProvider) == registry)
        setState(() => _error = error is StateError
            ? error.message.toString()
            : 'Could not update devices. Please retry.');
    } finally {
      if (mounted)
        setState(() {
          _busy = false;
          _progress = null;
        });
    }
  }

  Future<void> _addNecklace(DeviceRegistry registry,
      {String? pendingId}) async {
    final service = ref.read(bleBackgroundServiceProvider);
    service.setDevicePairing(true);
    try {
      await _pairNecklace(registry, pendingId: pendingId);
    } finally {
      service.setDevicePairing(false);
    }
  }

  Future<void> _pairNecklace(DeviceRegistry registry,
      {String? pendingId}) async {
    _stage('Choose your Necklace');
    final selected = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const DeviceSelectionPage()));
    if (selected != true || !mounted || ref.read(_registryProvider) != registry)
      return;
    final service = ref.read(bleBackgroundServiceProvider);
    final remote = await PairedDeviceStorage.getPairedRemoteId();
    if (remote == null) throw StateError('Select a Necklace first');
    _stage('Connecting over Bluetooth…');
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (service.lastKnownBleStatus.name != 'connected' &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted || ref.read(_registryProvider) != registry) return;
    }
    Future<Uint8List> exchange(Uint8List request) {
      if (!mounted || ref.read(_registryProvider) != registry)
        throw StateError('Account changed');
      return service.exchangeIdentity(request, expectedRemoteId: remote);
    }

    final identity = NecklaceIdentity(exchange);
    final existing = await identity.inspect();
    if (!mounted || ref.read(_registryProvider) != registry) return;
    Map<String, dynamic>? setup;
    if (existing == null) {
      setup = pendingId == null
          ? await registry.pair('necklace')
          : await registry.renewPairing(pendingId);
    } else {
      final rows = await registry.list();
      final matches = rows
          .where((r) => r['id'] == existing && r['device_type'] == 'necklace')
          .toList();
      if (matches.isEmpty || matches.single['status'] == 'revoked') {
        throw StateError(
            'This Necklace belongs to a different account or has been revoked.');
      }
      if (matches.single['status'] == 'pending')
        setup = await registry.renewPairing(existing);
    }
    if (!mounted || ref.read(_registryProvider) != registry) return;
    _stage('Linking Necklace to your account…');
    if (setup != null) await identity.provision(setup);
    final id = existing ?? setup!['device_id'] as String;
    final auth = NecklaceDeviceAuth(
        baseUrl: resolve(registry.user.preset).imageHttp,
        deviceId: id,
        exchange: exchange,
        isCurrent: () => mounted && ref.read(_registryProvider) == registry);
    try {
      _stage('Verifying device identity…');
      await auth.headers(true);
      final rows = await registry.list();
      if (!rows.any((r) => r['id'] == id && r['status'] == 'active'))
        throw StateError('Pairing is not active yet');
      if (!mounted || ref.read(_registryProvider) != registry) return;
      if (await PairedDeviceStorage.getPairedRemoteId() != remote)
        throw StateError('Selected device changed');
      await NecklaceEnrollment.save(
          registry.user.preset.key, registry.user.userId, remote, id);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Necklace paired and ready.')));
    } finally {
      auth.close();
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
        appBar: AppBar(title: const Text('Devices'), actions: [
          IconButton(
              onPressed: () => ref.invalidate(_devicesProvider),
              icon: const Icon(Icons.refresh))
        ]),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          const Text(
              'Devices belong to your account and can query your accessible domains.'),
          const SizedBox(height: 16),
          FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run((registry) => _addNecklace(registry)),
              icon: const Icon(Icons.bluetooth),
              label: const Text('Add Necklace')),
          if (_busy) const LinearProgressIndicator(),
          if (_progress != null) Text(_progress!),
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
                    ? 'Add SleepBot Assistant'
                    : 'Add SleepBot Radar')),
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
                                if (row['device_type'] == 'necklace' &&
                                    action == 'renew') {
                                  await _addNecklace(registry,
                                      pendingId: row['id'] as String);
                                } else if (action == 'renew') {
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
