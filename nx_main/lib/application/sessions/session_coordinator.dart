import 'session_identity.dart';

/// Coordinates the foreground's desired session. Adapters retire asynchronous
/// work using their own generation checks; this class never owns transport I/O.
class SessionCoordinator<T> {
  SessionCoordinator(
      {required this.disconnectNecklace,
      required this.configureWatch,
      required this.connectNecklace});
  final void Function() disconnectNecklace;
  final void Function(T?) configureWatch;
  final void Function(T) connectNecklace;
  SessionIdentity? _active;

  void update(SessionIdentity? identity, T? configuration) {
    if (identity == null || configuration == null) {
      _active = null;
      disconnectNecklace();
      configureWatch(null);
      return;
    }
    if (_active == identity) return;
    if (_active != null) disconnectNecklace();
    _active = identity;
    configureWatch(configuration);
    connectNecklace(configuration);
  }
}
