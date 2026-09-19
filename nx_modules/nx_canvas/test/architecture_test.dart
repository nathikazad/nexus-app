import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('model and engine have no platform, firmware, or host dependencies', () {
    for (final module in ['model', 'engine']) {
      for (final file
          in Directory('android/$module/src/main')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.kt'))) {
        final text = file.readAsStringSync();
        for (final forbidden in [
          'import android.',
          'import io.flutter.',
          'com.xrz.',
          'CanvasServices',
          'CanvasDiagnostics.',
          'CanvasRepository',
          'org.json',
        ]) {
          expect(
            text.contains(forbidden),
            isFalse,
            reason: '${file.path} depends on $forbidden',
          );
        }
      }
    }
  });
  test('module dependency graph is explicit and acyclic', () {
    final allowed = <String, Set<String>>{
      'model': {},
      'engine': {'model'},
      'platform': {'model', 'engine'},
      'recovery': {'model', 'engine'},
      'diagnostics': {'model', 'engine'},
      'rendering': {'model', 'engine', 'platform', 'diagnostics'},
      'firmware': {'model', 'engine', 'platform', 'diagnostics'},
      'editor': {
        'model',
        'engine',
        'recovery',
        'diagnostics',
        'firmware',
        'rendering',
      },
    };
    for (final entry in allowed.entries) {
      final text = File(
        'android/${entry.key}/build.gradle.kts',
      ).readAsStringSync();
      final actual = RegExp(
        r'project\(":canvas-([^"\)]+)"\)',
      ).allMatches(text).map((m) => m[1]!).toSet();
      expect(
        actual,
        entry.value,
        reason:
            'Dependencies changed for ${entry.key}; review the architecture contract.',
      );
    }
  });
  test('Docs consumes the plugin rather than shared source directories', () {
    final gradle = File(
      '../../nx_docs/android/app/build.gradle.kts',
    ).readAsStringSync();
    expect(gradle, isNot(contains('nx_canvas/android')));
    final main = File(
      '../../nx_docs/android/app/src/main/kotlin/com/nexus/nx_notes/MainActivity.kt',
    ).readAsStringSync();
    expect(main, isNot(contains('MethodChannel')));
    expect(main, isNot(contains('NativeEditor')));
    final session = File(
      '../../nx_docs/lib/documents/editor/nx_canvas_session.dart',
    ).readAsStringSync();
    expect(session, isNot(contains('invokeMethod')));
    expect(session, isNot(contains('invokeMapMethod')));
  });
  test('vendor reflection stays inside firmware adapter', () {
    for (final module in [
      'editor',
      'rendering',
      'engine',
      'model',
      'recovery',
    ]) {
      for (final file
          in Directory('android/$module/src/main')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.kt'))) {
        expect(
          file.readAsStringSync(),
          isNot(contains('com.xrz.')),
          reason: file.path,
        );
        expect(
          file.readAsStringSync(),
          isNot(contains('getMethod(')),
          reason: file.path,
        );
      }
    }
  });
}
