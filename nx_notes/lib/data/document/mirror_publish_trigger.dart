import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:nx_db/nx_db.dart';

abstract class MirrorPublishTrigger {
  Future<void> trigger({
    required String reason,
    required int documentId,
    required bool immediate,
    bool waitForCompletion = false,
  });
}

class MirrorPublishTriggerService implements MirrorPublishTrigger {
  MirrorPublishTriggerService({
    required String baseUrl,
    required String userId,
    required http.Client client,
  }) : _baseUri = Uri.parse(_trimTrailingSlash(baseUrl)),
       _userId = userId,
       _client = client;

  final Uri _baseUri;
  final String _userId;
  final http.Client _client;

  @override
  Future<void> trigger({
    required String reason,
    required int documentId,
    required bool immediate,
    bool waitForCompletion = false,
  }) async {
    if (documentId <= 0) return;
    final response = await _client.post(
      _resolve('/mirror/publish/trigger'),
      headers: _headers(contentTypeJson: true),
      body: jsonEncode({
        'reason': reason,
        'document_id': documentId,
        'immediate': immediate,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(_httpErrorMessage(response, 'mirror publish trigger'));
    }
    debugMirrorPublish('trigger accepted body=${response.body}');
    if (waitForCompletion) {
      await waitForPublishSync();
    }
  }

  Future<void> waitForPublishSync({
    Duration timeout = const Duration(seconds: 45),
    Duration interval = const Duration(milliseconds: 900),
  }) async {
    final deadline = DateTime.now().add(timeout);
    MirrorPublishStatus? lastStatus;

    while (DateTime.now().isBefore(deadline)) {
      final status = await fetchPublishStatus();
      lastStatus = status;
      debugMirrorPublish(
        'status=${status.status} running=${status.running} '
        'pending=${status.pendingReason}',
      );

      if (status.running || status.pendingReason != null) {
        await Future<void>.delayed(interval);
        continue;
      }
      if (status.status == 'succeeded') {
        return;
      }
      if (status.status == 'failed') {
        throw StateError(status.lastError ?? 'Mirror publish failed');
      }

      await Future<void>.delayed(interval);
    }

    throw StateError(
      lastStatus?.running == true
          ? 'Mirror publish is still running'
          : 'Timed out waiting for mirror publish',
    );
  }

  Future<MirrorPublishStatus> fetchPublishStatus() async {
    final response = await _client.get(
      _resolve('/mirror/publish/status'),
      headers: _headers(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(_httpErrorMessage(response, 'mirror publish status'));
    }
    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      throw StateError('Invalid mirror publish status response');
    }
    return MirrorPublishStatus.fromJson(payload);
  }

  Uri _resolve(String path) => Uri.parse('$normalizedBaseUrl$path');

  String get normalizedBaseUrl {
    var value = _baseUri.toString().replaceFirst(RegExp(r'/+$'), '');
    if (CfAccess.endpointNeedsCfAccess(value) && value.startsWith('http://')) {
      value = value.replaceFirst('http://', 'https://');
    }
    return value;
  }

  Map<String, String> _headers({bool contentTypeJson = false}) {
    final base = normalizedBaseUrl;
    return {
      if (contentTypeJson) 'Content-Type': 'application/json',
      'X-User-Id': _userId,
      if (CfAccess.shouldAttachHeaders(base)) ...CfAccess.headers,
    };
  }

  String _httpErrorMessage(http.Response response, String label) {
    var message = '$label failed (${response.statusCode})';
    try {
      final payload = jsonDecode(response.body);
      if (payload is Map && payload['error'] != null) {
        message = payload['error'].toString();
      }
    } catch (_) {
      // Keep the HTTP status fallback.
    }
    return message;
  }
}

class MirrorPublishStatus {
  const MirrorPublishStatus({
    required this.status,
    required this.running,
    required this.pendingReason,
    required this.lastError,
  });

  final String status;
  final bool running;
  final String? pendingReason;
  final String? lastError;

  factory MirrorPublishStatus.fromJson(Map<String, dynamic> json) {
    return MirrorPublishStatus(
      status: json['status']?.toString() ?? 'unknown',
      running: json['running'] == true,
      pendingReason: json['pending_reason']?.toString(),
      lastError: json['last_error']?.toString(),
    );
  }
}

String _trimTrailingSlash(String value) {
  return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}

void debugMirrorPublish(String message) {
  debugPrint('[nx_notes mirror publish] $message');
}
