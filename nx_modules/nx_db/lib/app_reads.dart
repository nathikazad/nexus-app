import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:nx_data/nx_data.dart';
import 'nx_db.dart';

final appReadsProvider = Provider.family<AppReads?, String>((ref, app) {
  final user = ref.watch(authProvider).value;
  final client = ref.watch(nexusHttpClientProvider);
  if (user == null || client == null) return null;
  final reads = AppReads(
    client,
    Uri.parse(resolve(user.preset).imageHttp),
    app,
    cacheResponses: !AppDataPolicy.current.storesOfflineData,
  );
  ref.onDispose(() => unawaited(reads.close()));
  return reads;
});

final class AppReadException implements Exception {
  const AppReadException(this.statusCode, this.app, this.view);
  final int statusCode;
  final String app, view;
  @override
  String toString() => 'Could not load $app ($view): $statusCode';
}

/// Small live views; independent of manifests, offline stores and file queues.
final class AppReads {
  AppReads(this.client, this.origin, this.app, {bool cacheResponses = true})
    : cache = DataCache(retainCompleted: cacheResponses);
  final http.Client client;
  final Uri origin;
  final String app;
  final DataCache cache;
  final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;
  Future<void> close() => _changes.close();

  Future<Map<String, dynamic>> read(
    String view, [
    Map<String, String> query = const {},
  ]) {
    final uri = origin
        .resolve('/apps/$app/$view')
        .replace(queryParameters: query.isEmpty ? null : query);
    return cache.read(uri.toString(), () async {
      final response = await client
          .get(uri)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw AppReadException(response.statusCode, app, view);
      }
      return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    });
  }

  Future<List<Map<String, dynamic>>> items({
    Map<String, String> query = const {},
    int? limit,
  }) async {
    if (limit != null && limit <= 0) return [];
    final result = <Map<String, dynamic>>[];
    String? cursor;
    do {
      final remaining = limit == null
          ? 50
          : (limit - result.length).clamp(1, 200);
      final page = await read('items', {
        ...query,
        'limit': '$remaining',
        if (cursor != null) 'cursor': cursor,
      });
      result.addAll([
        for (final row in page['items'] as List)
          Map<String, dynamic>.from(row as Map),
      ]);
      final next = page['next_cursor'] as String?;
      if (next != null && next == cursor)
        throw StateError('Page did not advance');
      cursor = next;
    } while (cursor != null && (limit == null || result.length < limit));
    return result;
  }

  /// Invalidate the affected cached views. Visible repositories can refresh all
  /// their listeners; unchanged collection reads then reuse session memory.
  void invalidateChanges(
    Map<String, dynamic> previous,
    Map<String, dynamic> current,
  ) {
    if (previous.isEmpty) {
      invalidate();
      return;
    }
    final changed = <String>{
      for (final key in {...previous.keys, ...current.keys})
        if (previous[key]?['hash'] != current[key]?['hash']) key,
    };
    bool tagChanged(String system, String name) => changed.any((key) {
      for (final source in [previous, current]) {
        final metadata = source[key]?['metadata'];
        if (metadata?['kind'] == system && metadata?['name'] == name)
          return true;
      }
      return false;
    });
    cache.invalidateWhere((key) {
      final uri = Uri.parse(key);
      final view = uri.pathSegments.last;
      if (view == 'initial') return true;
      if (view == 'batch') {
        return uri.queryParameters['ids']!
            .split(',')
            .any((id) => changed.contains('document:$id'));
      }
      if (view != 'items') {
        return current.keys.any((k) => k.startsWith('document:'))
            ? changed.contains('document:$view')
            : true;
      }
      final query = uri.queryParameters;
      if (query['book_id'] case final book?)
        return changed.contains('book:$book');
      if (query['tag_system'] == 'Language' && query['tag'] != null) {
        return tagChanged('Language', query['tag']!);
      }
      // Hierarchical topics and arbitrary searches can gain or lose members.
      return true;
    });
    if (!_changes.isClosed) _changes.add(null);
  }

  void invalidate() {
    cache.invalidate();
    if (!_changes.isClosed) _changes.add(null);
  }
}
