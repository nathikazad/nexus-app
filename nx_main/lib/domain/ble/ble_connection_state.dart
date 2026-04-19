/// BLE connection state machine (UI / services; driver lives in `data/ble/`).
///
/// Transitions:
///   idle -> scanning (startScan — first-time discovery only)
///   idle -> connecting (reconnect via autoConnect)
///   scanning -> idle (stopScan / error)
///   scanning -> connecting (device found)
///   connecting -> connected (success)
///   connecting -> idle (failure — autoConnect stays registered with OS)
///   connected -> connecting (disconnect + autoConnect reconnect)
enum BleConnectionState {
  idle,
  scanning,
  connecting,
  connected,
}
