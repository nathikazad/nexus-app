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
        ScrollView {
            VStack(spacing: 12) {
                // Status indicator
                HStack {
                    Circle()
                        .fill(connectivityManager.isReachable ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    Text(connectivityManager.statusMessage)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Mic button
                Button(action: toggleRecording) {
                    ZStack {
                        Circle()
                            .fill(audioRecorder.isRecording ? Color.red : Color.blue)
                            .frame(width: 70, height: 70)
                        
                        Image(systemName: audioRecorder.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .disabled(!connectivityManager.isReachable)
                
                // Recording status
                if audioRecorder.isRecording {
                    Text(audioRecorder.statusMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                // AI Response text
                if !connectivityManager.receivedText.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(connectivityManager.receivedText)
                            .font(.body)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(8)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
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
            // Clear previous response and start new recording
            connectivityManager.clearReceivedText()
            connectivityManager.resetPacketCount()
            audioRecorder.startRecording()
        }
    }
}

#Preview {
    ContentView()
}
