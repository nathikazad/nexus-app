import 'package:flutter/foundation.dart';

/// Application data policy. Browser views read from the server on demand;
/// installed apps retain their library and download content for offline use.
/// Authentication tokens and small UI preferences are not library data.
final class AppDataPolicy {
  const AppDataPolicy({required this.isWeb});

  static const current = AppDataPolicy(isWeb: kIsWeb);
  final bool isWeb;
  bool get storesOfflineData => !isWeb;
  bool get downloadsLibrary => storesOfflineData;

  /// Lazy branches prevent native stores and download workers being created
  /// at all in a browser, even when their constructors have side effects.
  T select<T>({required T Function() native, required T Function() web}) =>
      storesOfflineData ? native() : web();
}
