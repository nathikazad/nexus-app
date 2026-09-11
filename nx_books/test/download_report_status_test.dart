import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_books/domain/book/download_report.dart';
import 'package:nx_books/settings/download_report_view.dart';

void main() {
  testWidgets(
    'stale persisted progress does not claim a live sync is running',
    (tester) async {
      final report = DownloadReport(
        phase: DownloadPhase.downloading,
        total: 758,
        verified: 750,
        failed: const [],
        updatedAt: DateTime.utc(2026),
      );
      Widget view(bool syncing) => MaterialApp(
        home: Scaffold(
          body: DownloadReportView(report: report, syncing: syncing),
        ),
      );
      await tester.pumpWidget(view(true));
      expect(find.textContaining('Sync is running.'), findsOneWidget);
      await tester.pumpWidget(view(false));
      expect(find.textContaining('Sync is running.'), findsNothing);
      expect(find.textContaining('750/758'), findsOneWidget);
    },
  );
}
