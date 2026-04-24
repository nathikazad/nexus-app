import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/core/theme/action_color_palette.dart';

void main() {
  test('hexFromColor and colorFromHex roundtrip', () {
    const c = Color(0xFF0A1B2C);
    expect(colorFromHex(hexFromColor(c)), c);
  });

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
