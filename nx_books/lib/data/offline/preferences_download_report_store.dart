import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/book/download_report.dart';

class PreferencesDownloadReportStore implements DownloadReportStore {
  const PreferencesDownloadReportStore(this.accountKey);
  final String accountKey;
  String get _key => 'nx_books.offline.$accountKey.download_report';

  @override
  Future<DownloadReport?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (value == null) return null;
    try {
      final json = jsonDecode(value) as Map<String, dynamic>;
      return DownloadReport(
        phase: DownloadPhase.values.byName(json['phase'] as String),
        total: json['total'] as int,
        verified: json['verified'] as int,
        failed: (json['failed'] as List).cast<String>(),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
    } catch (_) {
      return null; // A malformed report cannot certify downloaded content.
    }
  }

  @override
  Future<void> save(DownloadReport report) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(
      _key,
      jsonEncode({
        'phase': report.phase.name,
        'total': report.total,
        'verified': report.verified,
        'failed': report.failed,
        'updatedAt': report.updatedAt.toUtc().toIso8601String(),
      }),
    );
    if (!saved) throw StateError('Could not persist download status');
  }
}
