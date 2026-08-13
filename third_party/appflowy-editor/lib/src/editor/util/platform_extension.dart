import 'package:flutter/foundation.dart';

// TODO(Xazin): Refactor to honor `Theme.platform`
extension PlatformExtension on Object {
  /// Returns true if the operating system is macOS and not running on Web platform.
  static bool get isMacOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  /// Returns true if the operating system is Windows and not running on Web platform.
  static bool get isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  /// Returns true if the operating system is Linux and not running on Web platform.
  static bool get isLinux =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

  /// Returns true if the operating system is iOS and not running on Web platform.
  static bool get isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Returns true if the operating system is Android and not running on Web platform.
  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Returns true if the operating system is macOS and running on Web platform.
  static bool get isWebOnMacOS =>
      kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  /// Returns true if the operating system is Windows and running on Web platform.
  static bool get isWebOnWindows =>
      kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  /// Returns true if the operating system is Linux and running on Web platform.
  static bool get isWebOnLinux =>
      kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

  static bool get isDesktopOrWeb => kIsWeb || isDesktop;

  static bool get isDesktop => isMacOS || isWindows || isLinux;

  static bool get isMobile => isIOS || isAndroid;

  static bool get isNotMobile => !isMobile;
}
