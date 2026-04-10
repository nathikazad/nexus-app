//
//  AudioRecorder.swift
//  NexusWatch Watch App
//
//  Handles microphone recording and PCM streaming
//

import Foundation
import AVFoundation

class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var statusMessage = "Ready"
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    
    private let sampleRate: Double = 24000.0
    private let bufferSize: AVAudioFrameCount = 2400 // 100ms of audio at 24kHz
    
    var onAudioData: ((Data) -> Void)?
    
    override init() {
        super.init()
    }
    
    func startRecording() {
        guard !isRecording else { return }
        
        // Request microphone permission
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.setupAndStartRecording()
                } else {
                    self?.statusMessage = "Mic permission denied"
                    print("[AudioRecorder] Microphone permission denied")
                }
            }
        }
    }
    
    private func setupAndStartRecording() {
        do {
            // Configure audio session
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .default)
            try session.setActive(true)
            
            audioEngine = AVAudioEngine()
            guard let audioEngine = audioEngine else {
                statusMessage = "Failed to create audio engine"
                return
            }
            
            inputNode = audioEngine.inputNode
            guard let inputNode = inputNode else {
                statusMessage = "No input node"
                return
            }
            
            // Get the native format
            let nativeFormat = inputNode.outputFormat(forBus: 0)
            print("[AudioRecorder] Native format: \(nativeFormat)")
            
            // Create target format: 24kHz, mono, 16-bit PCM
            guard let targetFormat = AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: sampleRate,
                channels: 1,
                interleaved: true
            ) else {
                statusMessage = "Failed to create target format"
                return
            }
            
            // Create converter
            guard let converter = AVAudioConverter(from: nativeFormat, to: targetFormat) else {
                statusMessage = "Failed to create converter"
                return
            }
            
            // Install tap on input node
            inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: nativeFormat) { [weak self] buffer, time in
                self?.processAudioBuffer(buffer, converter: converter, targetFormat: targetFormat)
            }
            
            // Start the engine
            try audioEngine.start()
            
            isRecording = true
            statusMessage = "Recording..."
            print("[AudioRecorder] Started recording at \(sampleRate)Hz")
            
        } catch {
            statusMessage = "Error: \(error.localizedDescription)"
            print("[AudioRecorder] Error starting recording: \(error)")
        }
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter, targetFormat: AVAudioFormat) {
        // Calculate the capacity needed for the converted buffer
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else {
            return
        }
        
        var error: NSError?
        let status = converter.convert(to: convertedBuffer, error: &error) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        if status == .error {
            print("[AudioRecorder] Conversion error: \(String(describing: error))")
            return
        }
        
        // Extract PCM data as Int16
        guard let int16Data = convertedBuffer.int16ChannelData else { return }
        
        let frameLength = Int(convertedBuffer.frameLength)
        let data = Data(bytes: int16Data[0], count: frameLength * 2) // 2 bytes per Int16
        
        // Send the audio data
        DispatchQueue.main.async {
            self.onAudioData?(data)
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil
        
        isRecording = false
        statusMessage = "Stopped"
        print("[AudioRecorder] Stopped recording")
        
        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("[AudioRecorder] Error deactivating session: \(error)")
        }
    }
}

