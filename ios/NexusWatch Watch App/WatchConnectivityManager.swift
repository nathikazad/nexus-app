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
    @Published var statusMessage = "Not connected"
    @Published var packetsSent = 0
    
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
    
    func sendAudioData(_ data: Data) {
        guard WCSession.default.isReachable else {
            return
        }
        
        // Send audio data as message with Data payload
        let message: [String: Any] = [
            "type": "audio",
            "data": data,
            "sampleRate": 24000,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // Use sendMessage for real-time streaming (no reply handler for speed)
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("[Watch] Audio send error: \(error.localizedDescription)")
        }
        
        DispatchQueue.main.async {
            self.packetsSent += 1
        }
    }
    
    func sendAudioEOF() {
        guard WCSession.default.isReachable else {
            print("[Watch] Cannot send EOF - iPhone not reachable")
            return
        }
        
        let message: [String: Any] = [
            "type": "audioEOF",
            "totalPackets": packetsSent,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        WCSession.default.sendMessage(message, replyHandler: { reply in
            print("[Watch] EOF acknowledged: \(reply)")
        }) { error in
            print("[Watch] EOF send error: \(error.localizedDescription)")
        }
        
        print("[Watch] Sent EOF after \(packetsSent) packets")
    }
    
    func resetPacketCount() {
        DispatchQueue.main.async {
            self.packetsSent = 0
        }
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

