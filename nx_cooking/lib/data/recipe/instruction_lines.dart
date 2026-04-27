library;

/// Splits stored recipe instructions into display lines.
///
/// Handles real newlines, Windows `\\r\\n`, lone `\\r`, and escaped `\\n` as
/// two characters (common when instructions are saved in a single-line JSON field).
List<String> instructionLinesFromRaw(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return const [];
  }
  var s = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  s = s.replaceAll(r'\n', '\n');
  return s
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}
