class DocumentKey {
  const DocumentKey({required this.localId, this.remoteId});

  final String localId;
  final int? remoteId;

  DocumentKey withRemoteId(int value) {
    if (value <= 0) {
      throw ArgumentError.value(value, 'value', 'must be positive');
    }
    return DocumentKey(localId: localId, remoteId: value);
  }

  @override
  bool operator ==(Object other) {
    return other is DocumentKey && other.localId == localId;
  }

  @override
  int get hashCode => localId.hashCode;

  @override
  String toString() => 'DocumentKey(localId: $localId, remoteId: $remoteId)';
}
