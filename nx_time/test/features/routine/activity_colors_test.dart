import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/domain/schedules/schedule_plan.dart';
import 'package:nx_time/features/schedule/schedule_page.dart';

void main() {
  final colors = ModelTypeColors.fromPreference({
    'model_type_colors': {
      'Gym': '#112233',
      'Yoga': '#778899',
      'Consumption': '#BA3BBA',
    },
  });
  test('Exercise inherits Gym, Yoga retains its saved subtype color', () {
    expect(colors.forActivity('Exercise'), const Color(0xFF112233));
    expect(colors.forId(22, name: 'Exercise'), const Color(0xFF112233));
    expect(
      colors.forActivity(
        'Exercise',
        filter: {
          'filters': [
            {'key': 'type', 'op': '=', 'value': 'Yoga'},
          ],
        },
      ),
      const Color(0xFF778899),
    );
    expect(
      colors.forActivity(
        'Exercise',
        filter: {
          'filters': [
            {'key': 'type', 'op': '!=', 'value': 'Yoga'},
          ],
        },
      ),
      const Color(0xFF112233),
    );
    expect(colors.forActivity('Consumption'), const Color(0xFFBA3BBA));
    final explicit = ModelTypeColors.fromPreference({
      'model_type_colors': {'Exercise': '#ABCDEF', 'Gym': '#112233'},
    });
    expect(explicit.forActivity('Exercise'), const Color(0xFFABCDEF));
  });
  testWidgets('schedule uses saved Yoga color from real linked Routine shape', (
    tester,
  ) async {
    final model = Model.fromJson({
      'id': 1,
      'name': 'Yoga schedule',
      'entries': [
        {
          'days': ['monday'],
          'start_time': '07:00',
          'end_time': '07:30',
        },
      ],
      'Routine': [
        {
          'id': 2,
          'model_type': 'Exercise',
          'start_date': '2026-06-01',
          'end_date': '2026-06-10',
          'filter': {
            'filters': [
              {'key': 'type', 'op': '=', 'value': 'Yoga'},
            ],
          },
        },
      ],
    });
    final plan = SchedulePlan.fromModel(model);
    expect(plan.modelType, 'Exercise');
    expect(plan.goalFilter?['filters'], isNotEmpty);
    expect(plan.onDay(DateTime(2026, 6, 15)), isEmpty);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          schedulePlansProvider.overrideWith((ref) async => [plan]),
          scheduleInitialDateProvider.overrideWithValue(DateTime(2026, 6, 1)),
          modelTypeColorsProvider.overrideWith((ref) async => colors),
        ],
        child: const MaterialApp(home: SchedulePage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.text('Yoga schedule')).style?.color,
      const Color(0xFF778899),
    );
    expect(tester.takeException(), isNull);
  });
}
