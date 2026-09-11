import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_books/data/offline/preferences_download_report_store.dart';
import 'package:nx_books/domain/book/download_report.dart';
import 'package:nx_books/settings/download_report_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'download reports survive reopening and remain account scoped',
    () async {
      final report = DownloadReport(
        phase: DownloadPhase.downloading,
        total: 8,
        verified: 3,
        failed: ['Document/4'],
        updatedAt: DateTime.utc(2026, 9, 9),
      );
      await const PreferencesDownloadReportStore('a').save(report);
      final restored = await const PreferencesDownloadReportStore('a').load();
      expect(restored?.verified, 3);
      expect(restored?.failed, ['Document/4']);
      expect(restored?.phase, DownloadPhase.downloading);
      expect(await const PreferencesDownloadReportStore('b').load(), isNull);
    },
  );

  testWidgets('a persisted partial run is never displayed as complete', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DownloadReportView(
            report: DownloadReport(
              phase: DownloadPhase.downloading,
              total: 8,
              verified: 3,
              failed: ['Document/4'],
              updatedAt: DateTime.utc(2026, 9, 9),
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('3/8 texts verified so far'), findsOneWidget);
    expect(find.textContaining('1 downloads need attention'), findsOneWidget);
  });

  testWidgets(
    'completed verification includes saved chats but excludes images',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DownloadReportView(
              report: DownloadReport(
                phase: DownloadPhase.complete,
                total: 8,
                verified: 8,
                failed: [],
                updatedAt: DateTime.utc(2026, 9, 9),
              ),
            ),
          ),
        ),
      );
      expect(
        find.text('8/8 book and document texts verified.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('texts and saved AI conversations'),
        findsOneWidget,
      );
      expect(find.textContaining('images are not included'), findsOneWidget);
    },
  );
}
