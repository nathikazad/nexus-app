import 'dart:async';
import 'dart:math';

const _dbAuditContextZoneKey = #nxDbAuditContext;

class DbAuditContext {
  const DbAuditContext({
    required this.operationId,
    required this.sourceKind,
    this.sourceId,
    this.sourceLabel,
  });

  factory DbAuditContext.create({
    required String sourceKind,
    String? sourceId,
    String? sourceLabel,
  }) {
    return DbAuditContext(
      operationId: _uuidV4(),
      sourceKind: sourceKind,
      sourceId: sourceId,
      sourceLabel: sourceLabel,
    );
  }

  final String operationId;
  final String sourceKind;
  final String? sourceId;
  final String? sourceLabel;

  Map<String, String> toHeaders({String? fallbackSourceKind}) {
    final effectiveSourceKind =
        sourceKind.trim().isNotEmpty ? sourceKind : fallbackSourceKind;
    return {
      'X-Nexus-Operation-Id': operationId,
      if (_hasValue(effectiveSourceKind))
        'X-Nexus-Source-Kind': effectiveSourceKind!.trim(),
      if (_hasValue(sourceId)) 'X-Nexus-Source-Id': sourceId!.trim(),
      if (_hasValue(sourceLabel)) 'X-Nexus-Source-Label': sourceLabel!.trim(),
    };
  }

  static bool _hasValue(String? value) =>
      value != null && value.trim().isNotEmpty;
}

DbAuditContext? currentDbAuditContext() {
  final value = Zone.current[_dbAuditContextZoneKey];
  return value is DbAuditContext ? value : null;
}

Future<T> runWithDbAuditContext<T>(
  DbAuditContext context,
  Future<T> Function() body,
) {
  return runZoned(body, zoneValues: {_dbAuditContextZoneKey: context});
}

String _uuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int byte) => byte.toRadixString(16).padLeft(2, '0');
  final parts = [
    bytes.sublist(0, 4),
    bytes.sublist(4, 6),
    bytes.sublist(6, 8),
    bytes.sublist(8, 10),
    bytes.sublist(10, 16),
  ];
  return parts.map((part) => part.map(hex).join()).join('-');
}
