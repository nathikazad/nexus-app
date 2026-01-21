//
//  WatchConnectivityManager.swift
//  NexusWatch Watch App
//
//  Handles communication between Watch and iPhone
//

import Foundation
import WatchConnectivity

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published var isReachable = false
    @Published var lastSentMessage = ""
    @Published var statusMessage = "Not connected"
    
    private override init() {
        super.init()
        
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
            print("[Watch] WCSession activating...")
        } else {
            print("[Watch] WCSession not supported")
            statusMessage = "WCSession not supported"
        }
    }
    
    func sendMessage(_ text: String) {
        guard WCSession.default.isReachable else {
            print("[Watch] iPhone not reachable")
            statusMessage = "iPhone not reachable"
            return
        }
        
        let message = ["text": text]
        
        WCSession.default.sendMessage(message, replyHandler: { reply in
            DispatchQueue.main.async {
                if let response = reply["status"] as? String {
                    self.statusMessage = "Sent! Response: \(response)"
                    self.lastSentMessage = text
                    print("[Watch] Reply received: \(response)")
                }
            }
        }, errorHandler: { error in
            DispatchQueue.main.async {
                self.statusMessage = "Error: \(error.localizedDescription)"
                print("[Watch] Send error: \(error)")
            }
        })
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            switch activationState {
            case .activated:
                self.statusMessage = "Connected"
                self.isReachable = session.isReachable
                print("[Watch] Session activated, reachable: \(session.isReachable)")
            case .inactive:
                self.statusMessage = "Inactive"
                print("[Watch] Session inactive")
            case .notActivated:
                self.statusMessage = "Not activated"
                print("[Watch] Session not activated")
            @unknown default:
                self.statusMessage = "Unknown state"
            }
            
            if let error = error {
                self.statusMessage = "Error: \(error.localizedDescription)"
                print("[Watch] Activation error: \(error)")
            }
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            self.statusMessage = session.isReachable ? "Connected" : "iPhone not reachable"
            print("[Watch] Reachability changed: \(session.isReachable)")
        }
    }
}

