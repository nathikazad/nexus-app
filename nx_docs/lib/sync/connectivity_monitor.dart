abstract interface class ConnectivityMonitor {
  Stream<bool> get onlineChanges;
}
