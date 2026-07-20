class DocumentAsset {
  const DocumentAsset({
    required this.uri,
    required this.contentHash,
    required this.byteLength,
    this.remoteUrl,
  });

  final String uri;
  final String contentHash;
  final int byteLength;
  final String? remoteUrl;

  bool get pendingUpload => remoteUrl == null;

  DocumentAsset withRemoteUrl(String value) => DocumentAsset(
    uri: uri,
    contentHash: contentHash,
    byteLength: byteLength,
    remoteUrl: value,
  );
}
