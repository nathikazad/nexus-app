# Nx Live Agent Architecture

`nx_live_agent` owns reusable live-conversation behavior. Application widgets
render derived state; transports own OpenAI wire details and platform I/O.

## Dependency direction

```text
Nexus Docs widgets
  -> NoteLiveConversationController (presentation adapter)
    -> LiveAgentSession (session/response lifecycle)
      -> LiveAgentInputController (VAD and input gate)
      -> LiveAgentTransport capabilities
        -> OpenAI WebRTC or WebSocket adapter
          -> platform microphone and playback adapters
```

Input and playback are sibling capabilities. Input code cannot pause, flush, or
cancel assistant output. Playback code cannot change VAD or microphone state.

## Independent state domains

| Domain | Owner | States |
| --- | --- | --- |
| Session/response | `LiveAgentSession` | connecting, listening, thinking, speaking, failed, closed |
| Turn detection | `LiveAgentInputController` | automatic, manual |
| Input upload | `LiveAgentInputController` | active, muted, inactive, recording, submitting |
| Playback | `LiveAgentSession` + playback port | playing, paused |

The native microphone can remain warm for the session. `setInputEnabled` is a
local upload gate, so mute and manual-idle changes are immediate and never
touch the output player.

## Input transitions and command order

| User action | Commands | Result |
| --- | --- | --- |
| VAD on -> off | close input gate -> disable server VAD -> clear buffer | manual, inactive |
| Start recording | clear buffer -> open input gate | manual, recording |
| Send recording | close input gate -> commit -> create response | manual, inactive |
| VAD off -> on | close gate -> clear/discard -> enable VAD -> restore mute gate | automatic |
| Mute/unmute | close/open input gate | playback and AI response unchanged |

Manual Send deliberately leaves VAD off. Turning VAD on during a recording
discards that recording. All operations are serialized by the input controller.
Starting a manual recording while the assistant is speaking or paused first
cancels the active response, restores playback readiness for the next response,
then opens the input gate.

Pause is an explicit cross-domain user action: it pauses output and suspends
the input gate; resume restores the gate implied by the existing input state.

## Where to investigate

| Symptom | Start here |
| --- | --- |
| Wrong Mac/iPhone controls | `nx_docs/.../live_conversation_platform_policy.dart` |
| Wrong icon, tooltip, or enabled state | `nx_docs/.../widgets/` |
| VAD/mute/manual-record transition | `src/input/live_agent_input_controller.dart` |
| Listening/thinking/speaking lifecycle | `src/live_agent.dart` |
| Wrong OpenAI command or event | `src/openai_realtime*_transport.dart` |
| Mac capture or queued playback | `MacLiveAudioPlayer` and `MainFlutterWindow.swift` |

## Platform composition

- macOS uses the Realtime WebSocket transport, native `AVCaptureSession` input,
  and a separate `AVAudioPlayerNode` output queue for true pause/resume.
- iOS uses the WebRTC transport and currently presents automatic mute/unmute
  plus Stop. The transport implements the same semantic input capability.

Pure controller tests require no microphone, network, credential, or platform
channel. Protocol payloads and widgets are tested at their own boundaries.
