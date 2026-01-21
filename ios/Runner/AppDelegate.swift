import Flutter
import UIKit
import flutter_background_service_ios
import WatchConnectivity

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var watchChannel: FlutterMethodChannel?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Optional: customize BGTask identifier (must match Info.plist if changed)
    SwiftFlutterBackgroundServicePlugin.taskIdentifier = "dev.flutter.background.refresh"
    GeneratedPluginRegistrant.register(with: self)
    
    // Set up the watch bridge method channel
    setupWatchBridge()
    
    // Set up WatchConnectivity
    setupWatchConnectivity()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func setupWatchBridge() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      print("[WatchBridge] Failed to get FlutterViewController")
      return
    }
    
    watchChannel = FlutterMethodChannel(
      name: "com.nexus/watch_bridge",
      binaryMessenger: controller.binaryMessenger
    )
    
    watchChannel?.setMethodCallHandler { [weak self] (call, result) in
      switch call.method {
      case "ping":
        print("[WatchBridge] Received ping from Flutter")
        result("pong")
      case "sendToWatch":
        if let message = call.arguments as? String {
          self?.sendMessageToWatch(message)
          result(true)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Expected string argument", details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    
    print("[WatchBridge] Method channel set up successfully")
  }
  
  private func setupWatchConnectivity() {
    if WCSession.isSupported() {
      WCSession.default.delegate = self
      WCSession.default.activate()
      print("[WatchBridge] WCSession activating...")
    } else {
      print("[WatchBridge] WCSession not supported")
    }
  }
  
  private func sendMessageToWatch(_ message: String) {
    guard WCSession.default.isReachable else {
      print("[WatchBridge] Watch not reachable")
      return
    }
    
    WCSession.default.sendMessage(["text": message], replyHandler: nil) { error in
      print("[WatchBridge] Error sending to watch: \(error)")
    }
  }
  
  // Method to send messages from iOS to Flutter
  func sendMessageToFlutter(_ message: String) {
    DispatchQueue.main.async {
      self.watchChannel?.invokeMethod("messageFromWatch", arguments: message)
    }
  }
}

// MARK: - WCSessionDelegate
extension AppDelegate: WCSessionDelegate {
  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    print("[WatchBridge] WCSession activation: \(activationState.rawValue), error: \(String(describing: error))")
  }
  
  func sessionDidBecomeInactive(_ session: WCSession) {
    print("[WatchBridge] WCSession became inactive")
  }
  
  func sessionDidDeactivate(_ session: WCSession) {
    print("[WatchBridge] WCSession deactivated")
    // Reactivate for switching between watches
    WCSession.default.activate()
  }
  
  func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
    print("[WatchBridge] Received message from Watch: \(message)")
    
    if let text = message["text"] as? String {
      // Forward the message to Flutter
      sendMessageToFlutter(text)
      
      // Send reply back to watch
      replyHandler(["status": "received"])
    } else {
      replyHandler(["status": "error", "message": "Invalid message format"])
    }
  }
}
