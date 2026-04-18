import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/core/theme/action_color_palette.dart';

void main() {
  test('same modelTypeId → same bar color', () {
    expect(barColorForModelTypeId(42), barColorForModelTypeId(42));
  });

  test('pill derivation is deterministic', () {
    final bar = barColorForModelTypeId(7);
    final a = categoryPillStyleFromBarColor(bar);
    final b = categoryPillStyleFromBarColor(bar);
    expect(a.background, b.background);
    expect(a.foreground, b.foreground);
    expect(a.dot, b.dot);
  });
}
