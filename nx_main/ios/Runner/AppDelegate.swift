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
    print("[WatchBridge] Received message from Watch (with reply): \(message)")
    
    // Check for typed messages first
    if let type = message["type"] as? String {
      switch type {
      case "audioEOF":
        let totalPackets = message["totalPackets"] as? Int ?? 0
        print("[WatchBridge] Received audio EOF after \(totalPackets) packets")
        sendAudioEOFToFlutter(totalPackets: totalPackets)
        replyHandler(["status": "received"])
        return
      default:
        break
      }
    }
    
    // Handle text messages
    if let text = message["text"] as? String {
      sendMessageToFlutter(text)
      replyHandler(["status": "received"])
    } else {
      replyHandler(["status": "error", "message": "Invalid message format"])
    }
  }
  
  // Handle messages without reply handler (used for audio streaming)
  func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
    guard let type = message["type"] as? String else { return }
    
    switch type {
    case "audio":
      if let audioData = message["data"] as? Data,
         let sampleRate = message["sampleRate"] as? Int {
        print("[WatchBridge] Received audio packet: \(audioData.count) bytes at \(sampleRate)Hz")
        sendAudioDataToFlutter(audioData, sampleRate: sampleRate)
      }
      
    case "audioEOF":
      let totalPackets = message["totalPackets"] as? Int ?? 0
      print("[WatchBridge] Received audio EOF after \(totalPackets) packets")
      sendAudioEOFToFlutter(totalPackets: totalPackets)
      
    default:
      print("[WatchBridge] Unknown message type: \(type)")
    }
  }
  
  private func sendAudioDataToFlutter(_ data: Data, sampleRate: Int) {
    DispatchQueue.main.async {
      // Convert Data to FlutterStandardTypedData for efficient transfer
      let flutterData = FlutterStandardTypedData(bytes: data)
      let payload: [String: Any] = [
        "data": flutterData,
        "sampleRate": sampleRate,
        "size": data.count
      ]
      self.watchChannel?.invokeMethod("audioFromWatch", arguments: payload)
    }
  }
  
  private func sendAudioEOFToFlutter(totalPackets: Int) {
    DispatchQueue.main.async {
      let payload: [String: Any] = [
        "totalPackets": totalPackets
      ]
      self.watchChannel?.invokeMethod("audioEOFFromWatch", arguments: payload)
    }
  }
}
