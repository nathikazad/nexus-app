import Cocoa
import AVFoundation
import FlutterMacOS

/// A small native PCM queue. AVAudioPlayerNode retains scheduled buffers when
/// paused, which gives live-agent playback true resume semantics.
final class LiveAgentPcmPlayer: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
  private let channel: FlutterMethodChannel
  private let outputEngine = AVAudioEngine()
  private let player = AVAudioPlayerNode()
  // CoreAudio can synchronously contact audiohald while resolving inputNode.
  // Doing that on Flutter's platform thread can freeze the entire window.
  private let microphoneQueue = DispatchQueue(
    label: "com.nexus.nxnotes.live-agent-microphone",
    qos: .userInitiated
  )
  private let format = AVAudioFormat(
    commonFormat: .pcmFormatInt16,
    sampleRate: 24_000,
    channels: 1,
    interleaved: true
  )!
  private var pendingBuffers = 0
  private var responseFinished = false
  private var paused = false
  private var announcedPlayback = false
  private var microphoneInstalled = false
  private var microphoneMuted = false
  private var captureSession: AVCaptureSession?
  private var playerConnected = false

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "nx_notes/live_agent_pcm_player",
      binaryMessenger: messenger
    )
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    do {
      switch call.method {
      case "append":
        guard let data = call.arguments as? FlutterStandardTypedData else {
          result(FlutterError(code: "invalid_pcm", message: "PCM bytes are required.", details: nil))
          return
        }
        try append(data.data)
      case "finishResponse":
        responseFinished = true
        reportStoppedIfComplete()
      case "pause":
        paused = true
        player.pause()
      case "resume":
        paused = false
        try startEngineIfNeeded()
        if pendingBuffers > 0 { player.play() }
      case "stop":
        player.stop()
        pendingBuffers = 0
        responseFinished = false
        paused = false
        announcedPlayback = false
      case "startMicrophone":
        microphoneQueue.async { [weak self] in
          do {
            try self?.startMicrophone()
            DispatchQueue.main.async { result(nil) }
          } catch {
            DispatchQueue.main.async {
              result(FlutterError(
                code: "audio_input",
                message: error.localizedDescription,
                details: nil
              ))
            }
          }
        }
        return
      case "setMicrophoneMuted":
        microphoneMuted = (call.arguments as? Bool) ?? false
      case "stopMicrophone":
        microphoneQueue.async { [weak self] in
          self?.stopMicrophone()
          DispatchQueue.main.async { result(nil) }
        }
        return
      default:
        result(FlutterMethodNotImplemented)
        return
      }
      result(nil)
    } catch {
      result(FlutterError(code: "audio_player", message: error.localizedDescription, details: nil))
    }
  }

  private func append(_ data: Data) throws {
    guard !data.isEmpty else { return }
    connectPlayerIfNeeded()
    let frameCount = AVAudioFrameCount(data.count / MemoryLayout<Int16>.size)
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
      throw NSError(domain: "LiveAgentPcmPlayer", code: 1)
    }
    buffer.frameLength = frameCount
    let audioBuffer = buffer.mutableAudioBufferList.pointee.mBuffers
    guard let destination = audioBuffer.mData else {
      throw NSError(domain: "LiveAgentPcmPlayer", code: 2)
    }
    data.copyBytes(to: destination.assumingMemoryBound(to: UInt8.self), count: data.count)
    buffer.mutableAudioBufferList.pointee.mBuffers.mDataByteSize = UInt32(data.count)
    try startEngineIfNeeded()
    responseFinished = false
    pendingBuffers += 1
    player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
      DispatchQueue.main.async {
        guard let self else { return }
        self.pendingBuffers = max(0, self.pendingBuffers - 1)
        self.reportStoppedIfComplete()
      }
    }
    if !announcedPlayback {
      announcedPlayback = true
      channel.invokeMethod("playbackStarted", arguments: nil)
    }
    if !paused { player.play() }
  }

  private func startEngineIfNeeded() throws {
    if !outputEngine.isRunning {
      outputEngine.prepare()
      try outputEngine.start()
    }
  }

  private func connectPlayerIfNeeded() {
    guard !playerConnected else { return }
    outputEngine.attach(player)
    outputEngine.connect(
      player,
      to: outputEngine.mainMixerNode,
      format: format
    )
    playerConnected = true
  }

  private func startMicrophone() throws {
    guard !microphoneInstalled else { return }
    guard let device = AVCaptureDevice.default(for: .audio) else {
      throw NSError(
        domain: "LiveAgentPcmPlayer",
        code: 3,
        userInfo: [NSLocalizedDescriptionKey: "No microphone input device is available."]
      )
    }
    let session = AVCaptureSession()
    let input = try AVCaptureDeviceInput(device: device)
    guard session.canAddInput(input) else {
      throw NSError(
        domain: "LiveAgentPcmPlayer",
        code: 4,
        userInfo: [NSLocalizedDescriptionKey: "Could not attach the microphone input."]
      )
    }
    session.addInput(input)

    let output = AVCaptureAudioDataOutput()
    output.audioSettings = [
      AVFormatIDKey: kAudioFormatLinearPCM,
      AVSampleRateKey: 24_000,
      AVNumberOfChannelsKey: 1,
      AVLinearPCMBitDepthKey: 16,
      AVLinearPCMIsFloatKey: false,
      AVLinearPCMIsBigEndianKey: false,
      AVLinearPCMIsNonInterleaved: false,
    ]
    output.setSampleBufferDelegate(self, queue: microphoneQueue)
    guard session.canAddOutput(output) else {
      throw NSError(
        domain: "LiveAgentPcmPlayer",
        code: 5,
        userInfo: [NSLocalizedDescriptionKey: "Could not configure microphone PCM output."]
      )
    }
    session.addOutput(output)
    captureSession = session
    microphoneInstalled = true
    session.startRunning()
    guard session.isRunning else {
      captureSession = nil
      microphoneInstalled = false
      throw NSError(
        domain: "LiveAgentPcmPlayer",
        code: 6,
        userInfo: [NSLocalizedDescriptionKey: "The microphone capture session did not start."]
      )
    }
  }

  private func stopMicrophone() {
    guard microphoneInstalled else { return }
    captureSession?.stopRunning()
    captureSession = nil
    microphoneInstalled = false
    microphoneMuted = false
  }

  func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard !microphoneMuted,
          let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
    let length = CMBlockBufferGetDataLength(blockBuffer)
    guard length > 0 else { return }
    var data = Data(count: length)
    let status = data.withUnsafeMutableBytes { bytes in
      guard let baseAddress = bytes.baseAddress else { return kCMBlockBufferBadLengthParameterErr }
      return CMBlockBufferCopyDataBytes(
        blockBuffer,
        atOffset: 0,
        dataLength: length,
        destination: baseAddress
      )
    }
    guard status == kCMBlockBufferNoErr else { return }
    DispatchQueue.main.async { [weak self] in
      self?.channel.invokeMethod(
        "microphonePcm",
        arguments: FlutterStandardTypedData(bytes: data)
      )
    }
  }

  private func reportStoppedIfComplete() {
    guard responseFinished && pendingBuffers == 0 && announcedPlayback else { return }
    responseFinished = false
    announcedPlayback = false
    channel.invokeMethod("playbackStopped", arguments: nil)
  }
}

class MainFlutterWindow: NSWindow {
  private var liveAgentPcmPlayer: LiveAgentPcmPlayer?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.setContentSize(NSSize(width: 1280, height: 800))
    self.minSize = NSSize(width: 900, height: 640)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)
    liveAgentPcmPlayer = LiveAgentPcmPlayer(
      messenger: flutterViewController.engine.binaryMessenger
    )

    super.awakeFromNib()
  }
}
