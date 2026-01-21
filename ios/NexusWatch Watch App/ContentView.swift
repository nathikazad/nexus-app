//
//  ContentView.swift
//  NexusWatch Watch App
//
//  Created by Nathik Azad on 1/20/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    @StateObject private var audioRecorder = AudioRecorder()
    
    var body: some View {
        VStack(spacing: 16) {
            // Status indicator
            HStack {
                Circle()
                    .fill(connectivityManager.isReachable ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                Text(connectivityManager.statusMessage)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Mic button
            Button(action: toggleRecording) {
                ZStack {
                    Circle()
                        .fill(audioRecorder.isRecording ? Color.red : Color.blue)
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: audioRecorder.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            .disabled(!connectivityManager.isReachable)
            
            // Recording status
            Text(audioRecorder.statusMessage)
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Packet counter
            if audioRecorder.isRecording || connectivityManager.packetsSent > 0 {
                Text("Packets: \(connectivityManager.packetsSent)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            setupAudioCallback()
        }
    }
    
    private func setupAudioCallback() {
        audioRecorder.onAudioData = { data in
            connectivityManager.sendAudioData(data)
        }
    }
    
    private func toggleRecording() {
        if audioRecorder.isRecording {
            audioRecorder.stopRecording()
            // Send EOF when recording stops
            connectivityManager.sendAudioEOF()
        } else {
            connectivityManager.resetPacketCount()
            audioRecorder.startRecording()
        }
    }
}

#Preview {
    ContentView()
}
