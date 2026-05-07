import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/features/daily/desktop_daily_body.dart';
import 'package:nx_projects/features/daily/widgets/dd_task_row.dart';
import 'package:nx_projects/features/shell/selection_providers.dart';
import '../../_support/seed_test_overrides.dart';

void main() {
  testWidgets('DesktopDailyBody builds', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...nxProjectsTestSeedOverrides,
          dailyDateProvider.overrideWith(_ReferenceDailyDate.new),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: DesktopDailyBody(
              onOpenTaskMenu: (c, r, t) {},
              onOpenTask: (c, r, t) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('JOURNAL'), findsOneWidget);
  });

  testWidgets('DesktopDailyBody opens task from today row', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Task? opened;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...nxProjectsTestSeedOverrides,
          dailyDateProvider.overrideWith(_ReferenceDailyDate.new),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: DesktopDailyBody(
              onOpenTaskMenu: (c, r, t) {},
              onOpenTask: (c, r, t) => opened = t,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byWidgetPredicate((w) => w is DdTaskRow && w.task.id == 305),
    );
    await tester.pump();

    expect(opened?.id, 305);
  });
}

class _ReferenceDailyDate extends DailyDate {
  @override
  String build() => '2026-04-23';
}
