import 'package:shared_preferences/shared_preferences.dart';

/// Persists the BLE [BluetoothDevice.remoteId] string for the user's Nexus unit.
class PairedDeviceStorage {
  PairedDeviceStorage._();

  static const _keyPairedRemoteId = 'nexux_paired_ble_remote_id';

  static Future<String?> getPairedRemoteId() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_keyPairedRemoteId);
  }

  static Future<void> setPairedRemoteId(String remoteId) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyPairedRemoteId, remoteId);
  }

  static Future<void> clearPairedRemoteId() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_keyPairedRemoteId);
  }
}
