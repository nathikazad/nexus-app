import Flutter
import UIKit
import flutter_background_service_ios

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Optional: customize BGTask identifier (must match Info.plist if changed)
    SwiftFlutterBackgroundServicePlugin.taskIdentifier = "dev.flutter.background.refresh"
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
