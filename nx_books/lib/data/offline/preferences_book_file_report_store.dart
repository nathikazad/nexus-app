import 'dart:convert';

import 'package:nx_books/domain/book/book_file_report.dart';
import 'package:nx_books/domain/book/download_report.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class PreferencesBookFileReportStore implements BookFileReportStore {
  const PreferencesBookFileReportStore(this.accountKey);

  final String accountKey;
  String get _key => 'nx_books.offline.$accountKey.book_file_report';

  @override
  Future<BookFileReport?> load() async {
    final value = (await SharedPreferences.getInstance()).getString(_key);
    if (value == null) return null;
    try {
      final json = jsonDecode(value) as Map<String, dynamic>;
      return BookFileReport(
        phase: DownloadPhase.values.byName(json['phase'] as String),
        total: json['total'] as int,
        verified: json['verified'] as int,
        failed: (json['failed'] as List).cast<String>(),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(BookFileReport report) async {
    final saved = await (await SharedPreferences.getInstance()).setString(
      _key,
      jsonEncode({
        'phase': report.phase.name,
        'total': report.total,
        'verified': report.verified,
        'failed': report.failed,
        'updatedAt': report.updatedAt.toUtc().toIso8601String(),
      }),
    );
    if (!saved) throw StateError('Could not persist book file status');
  }
}
