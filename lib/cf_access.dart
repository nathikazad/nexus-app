import 'package:flutter/foundation.dart';

/// Cloudflare Access service token for [supacharger.ai] tunnel routes.
class CfAccess {
  CfAccess._();

  static const String clientId =
      '6496f268604fc87ea7bcc9bd1b4b4a78.access';
  static const String clientSecret =
      '4bcdc67981628ed79f0295c7213d8cf47043ed1ef295086e5e452cb294aa4d04';

  static Map<String, String> get headers => {
        'CF-Access-Client-Id': clientId,
        'CF-Access-Client-Secret': clientSecret,
      };

  static bool endpointNeedsCfAccess(String url) =>
      url.contains('supacharger.ai');

  /// Attach [headers] only in release/profile — never in debug (local dev).
  static bool shouldAttachHeaders(String url) =>
      !kDebugMode && endpointNeedsCfAccess(url);
}
