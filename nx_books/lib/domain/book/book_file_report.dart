import 'download_report.dart';

class BookFileReport {
  const BookFileReport({
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

abstract interface class BookFileReportStore {
  Future<BookFileReport?> load();
  Future<void> save(BookFileReport report);
}
