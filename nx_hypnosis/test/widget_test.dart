import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_auth/nx_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_hypnosis/app.dart';
import 'package:nx_hypnosis/desires.dart';

HypnosisCollection sample() => HypnosisCollection(
  [
    Desire(
      id: 'wealth',
      title: 'Wealth through service',
      belief: 'I create useful things.',
    ),
    Desire(id: 'family', title: 'A loving family', belief: 'I am present.'),
  ],
  [
    Tape(
      id: 'one',
      desireId: 'wealth',
      title: 'A quiet morning',
      story: 'Let your hands rest.\n\nYou take your time.',
      audioAsset: 'assets/hypnotizer.mp3',
    ),
  ],
  'A sample story.',
);

void main() {
  for (final width in [320.0, 390.0, 1280.0]) {
    testWidgets('Tapes and transcript fit at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(testApp(sample()));
      expect(find.text('Tapes'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      await tester.tap(find.text('A quiet morning'));
      await tester.pumpAndSettle();
      expect(find.text('Let your hands rest.'), findsOneWidget);
      expect(find.text('Edit story'), findsNothing);
      expect(find.byTooltip('Play A quiet morning'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Desire creation and editing update the in-memory record', (
    tester,
  ) async {
    final data = sample();
    await tester.pumpWidget(testApp(data));
    await tester.tap(find.byTooltip('Desires'));
    await tester.pumpAndSettle();
    expect(find.text('I create useful things.'), findsNothing);
    await tester.tap(find.byTooltip('Add desire'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Patience');
    await tester.enterText(find.byType(TextFormField).at(1), 'I allow time.');
    await tester.tap(find.text('Save desire'));
    await tester.pumpAndSettle();
    expect(data.desires.last.title, 'Patience');
    expect(find.text('I allow time.'), findsOneWidget);
    await tester.tap(find.byTooltip('Desire options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit desire'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'I listen patiently.',
    );
    await tester.tap(find.text('Save desire'));
    await tester.pumpAndSettle();
    expect(data.desires.last.belief, 'I listen patiently.');
  });
  test(
    'Deleting a desire moves its tapes or removes them explicitly',
    () async {
      final data = sample();
      await data.removeDesire(data.desire('wealth'), moveTo: 'family');
      expect(data.tapes.single.desireId, 'family');
      expect(
        data.removeDesire(data.desire('family'), moveTo: 'missing'),
        throwsArgumentError,
      );
      expect(data.desires.length, 1);
      await data.removeDesire(data.desire('family'));
      expect(data.tapes, isEmpty);
    },
  );
}

class _TestAuth extends AuthController {
  @override
  Future<User?> build() async => null;
}

Widget testApp(HypnosisCollection data) => ProviderScope(
  overrides: [authProvider.overrideWith(_TestAuth.new)],
  child: HypnosisApp(collection: data),
);
