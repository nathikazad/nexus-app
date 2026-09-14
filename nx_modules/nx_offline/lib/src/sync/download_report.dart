enum DownloadPhase { checking, downloading, complete, incomplete }

/// Text-document readiness. Asset readiness is deliberately a separate concern.
class DownloadReport {
  const DownloadReport({
    required this.phase,
    required this.total,
    required this.verified,
    required this.failed,
    required this.updatedAt,
  });

  final DownloadPhase phase;
  final int total;
  final int verified;
  final List<String> failed;
  final DateTime updatedAt;
}

abstract interface class DownloadReportStore {
  Future<DownloadReport?> load();
  Future<void> save(DownloadReport report);
}
