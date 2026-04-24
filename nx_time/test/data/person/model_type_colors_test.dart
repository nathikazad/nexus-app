import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nx_db/person.dart' show Person, PersonRepository;
import 'package:nx_time/core/theme/action_color_palette.dart';
import 'package:nx_time/data/person/model_type_colors.dart';
import 'package:nx_time/domain/action/action_subtype_option.dart';

class _MockPersonRepository extends Mock implements PersonRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const Person(id: 0, name: 'fallback', preference: {}),
    );
    registerFallbackValue(<String, dynamic>{});
  });

  test('kPrefModelTypeColors and readModelTypeColorHexByName are stable', () {
    expect(kPrefModelTypeColors, 'model_type_colors');
    final m = readModelTypeColorHexByName({
      kPrefModelTypeColors: {
        'A': '#111111',
        'B': 2,
      },
    });
    expect(m['A'], '#111111');
    expect(m['B'], '2');
  });

  test('setModelTypeColor calls updatePreference with merged map', () async {
    final repo = _MockPersonRepository();
    const person = Person(
      id: 1,
      name: 'U',
      preference: <String, dynamic>{'x': 1, kPrefModelTypeColors: {'A': '#AAAAAA'}},
    );
    when(() => repo.updatePreference(any(), any()))
        .thenAnswer((i) async => (i.positionalArguments[0] as Person)
            .copyWith(preference: i.positionalArguments[1] as Map<String, dynamic>));

    final out = await setModelTypeColor(
      repo: repo,
      person: person,
      modelTypeName: 'B',
      hex: '#BBBBBB',
    );
    final captured = verify(() => repo.updatePreference(captureAny(), captureAny()));
    captured.called(1);
    final argPref = (captured.captured[1] as Map<String, dynamic>)[kPrefModelTypeColors]
        as Map<String, dynamic>?;
    expect(argPref!['A'], '#AAAAAA');
    expect(argPref['B'], '#BBBBBB');
    expect(out.preference[kPrefModelTypeColors], isNotNull);
  });

  test('seedMissingModelTypeColors adds defaults for missing subtypes', () async {
    final repo = _MockPersonRepository();
    const person = Person(
      id: 1,
      name: 'U',
      preference: <String, dynamic>{},
    );
    when(() => repo.updatePreference(any(), any())).thenAnswer(
      (i) async => (i.positionalArguments[0] as Person)
          .copyWith(preference: i.positionalArguments[1] as Map<String, dynamic>),
    );
    final sub = [
      const ActionSubtypeOption(id: 3, name: 'Alpha'),
    ];
    final out = await seedMissingModelTypeColors(
      repo: repo,
      person: person,
      subtypes: sub,
    );
    verify(() => repo.updatePreference(any(), any())).called(1);
    final hex = readModelTypeColorHexByName(out.preference)['Alpha'];
    expect(hex, isNotNull);
    expect(colorFromHex(hex!), barColorForModelTypeId(3));
  });

  test('forId uses hex override for Sleep, falls back for Yoga', () {
    final pref = <String, dynamic>{
      kPrefModelTypeColors: {
        'Sleep': '#112233',
      },
    };
    final c = ModelTypeColors.fromPreference(pref);
    expect(
      c.forId(10, name: 'Sleep'),
      const Color(0xFF112233),
    );
    final yoga = c.forId(11, name: 'Yoga');
    expect(yoga, barColorForModelTypeId(11));
  });
}
