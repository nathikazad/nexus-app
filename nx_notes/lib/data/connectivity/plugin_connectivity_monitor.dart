import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:nx_notes/application/ports/connectivity_monitor.dart';

class PluginConnectivityMonitor implements ConnectivityMonitor {
  PluginConnectivityMonitor({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Stream<bool> get onlineChanges => _connectivity.onConnectivityChanged
      .map(
        (results) => results.any((result) => result != ConnectivityResult.none),
      )
      .distinct();
}
