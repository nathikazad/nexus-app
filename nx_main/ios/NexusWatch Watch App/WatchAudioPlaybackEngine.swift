//
//  WatchAudioPlaybackEngine.swift
//  NexusWatch Watch App
//
//  Plays PCM streamed from the iPhone.
//

import AVFoundation
import Foundation

final class WatchAudioPlaybackEngine {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var isAttached = false
    private var currentSampleRate: Double?

    func playPcm16(_ data: Data, sampleRate: Int) {
        guard !data.isEmpty else { return }

        do {
            try ensureStarted(sampleRate: Double(sampleRate))
            guard let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: Double(sampleRate),
                channels: 1,
                interleaved: false
            ) else {
                print("[WatchAudioPlayback] Failed to create playback format")
                return
            }

            let frameCount = data.count / MemoryLayout<Int16>.size
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(frameCount)
            ) else {
                print("[WatchAudioPlayback] Failed to create playback buffer")
                return
            }
            buffer.frameLength = AVAudioFrameCount(frameCount)

            guard let floatChannel = buffer.floatChannelData?[0] else {
                print("[WatchAudioPlayback] Missing float channel")
                return
            }

            data.withUnsafeBytes { rawBuffer in
                let samples = rawBuffer.bindMemory(to: Int16.self)
                for index in 0..<frameCount {
                    let sample = Int16(littleEndian: samples[index])
                    floatChannel[index] = max(-1.0, min(1.0, Float(sample) / 32768.0))
                }
            }

            player.scheduleBuffer(buffer, completionHandler: nil)
            if !player.isPlaying {
                player.play()
            }
        } catch {
            print("[WatchAudioPlayback] Playback error: \(error.localizedDescription)")
        }
    }

    func finishTurn() {
        if !player.isPlaying {
            player.play()
        }
    }

    func stop() {
        player.stop()
    }

    private func ensureStarted(sampleRate: Double) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)

        if !isAttached {
            engine.attach(player)
            isAttached = true
        }

        if currentSampleRate != sampleRate || !engine.isRunning {
            if engine.isRunning {
                engine.stop()
            }
            engine.disconnectNodeOutput(player)
            guard let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: sampleRate,
                channels: 1,
                interleaved: false
            ) else {
                throw PlaybackError.formatCreationFailed
            }
            engine.connect(player, to: engine.mainMixerNode, format: format)
            engine.prepare()
            try engine.start()
            currentSampleRate = sampleRate
        }
    }
}

private enum PlaybackError: Error {
    case formatCreationFailed
}
