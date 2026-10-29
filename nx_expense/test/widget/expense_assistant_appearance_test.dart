import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nx_expense/core/theme/app_theme.dart';
import 'package:nx_expense/features/ai/expense_assistant_page.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final brightness in Brightness.values) {
    testWidgets('Tell AI is legible in ${brightness.name} appearance', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final input = TextEditingController();
      addTearDown(input.dispose);
      final boundary = GlobalKey();
      var sent = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildExpenseTheme(),
          home: RepaintBoundary(
            key: boundary,
            child: ExpenseCaptureView(
              domain: 'Home',
              controller: input,
              onBack: () {},
              onSend: () => sent = true,
              onVoice: () {},
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        final loader = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await loader.load();
        await GoogleFonts.pendingFonts();
      });
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField));
      final scheme = Theme.of(
        tester.element(find.byType(TextField)),
      ).colorScheme;
      expect(scheme.brightness, brightness);
      double contrast(Color a, Color b) {
        final x = a.computeLuminance(), y = b.computeLuminance();
        return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
      }

      expect(
        contrast(field.style!.color!, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(field.decoration!.hintStyle!.color!, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      final preview = Platform.environment['NX_PREVIEW_DIR'];
      if (preview != null) {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '$preview/tell-ai-${brightness.name}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.enterText(
        find.byType(TextField),
        'Coffee and lunch, about \$20',
      );
      await tester.pump();
      await tester.tap(find.text('Send note'));
      expect(sent, isTrue);
      tester.view.physicalSize = const Size(320, 568);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
