class RemoteRevision {
  const RemoteRevision(this.value) : assert(value != '');

  final String value;

  @override
  bool operator ==(Object other) {
    return other is RemoteRevision && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
