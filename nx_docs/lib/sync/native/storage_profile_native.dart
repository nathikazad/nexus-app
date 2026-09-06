import 'dart:convert';
import 'dart:io';

// Explicit macOS diagnostic mode. Authentication is unchanged; only the local
// document database and content namespace are isolated from the person's data.
bool get _enabled =>
    Platform.isMacOS && Platform.environment['NX_DOCS_STORAGE_PROFILE'] == '1';
String get storageProfileSuffix => _enabled ? '_memory_probe' : '';

void recordStorageMemory(String stage, {int? documents, int? downloaded}) {
  if (!_enabled) return;
  stderr.writeln(
    'NX_STORAGE_MEMORY ${jsonEncode({'stage': stage, 'time': DateTime.now().toUtc().toIso8601String(), 'pid': pid, 'rss_bytes': ProcessInfo.currentRss, 'peak_rss_bytes': ProcessInfo.maxRss, if (documents != null) 'documents': documents, if (downloaded != null) 'downloaded': downloaded})}',
  );
}
