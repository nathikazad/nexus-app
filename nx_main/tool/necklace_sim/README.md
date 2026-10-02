# Desktop Necklace phone relay

Runs the actual NX Main `NecklaceDeviceAuth`, `SocketClient`, `NecklaceRelay`,
audio codec and device command handler on the computer using Flutter's desktop
test runtime. `FirmwareProcess` replaces Bluetooth with a serialized pipe to
`nexus_blackbox`, which runs the firmware startup and RTOS tasks. No phone is
required. The normal scripted simulator remains available for repeatable tests.

## Interactive necklace panel

From `mobile/nx_main`, run:

```sh
python3 tool/necklace_sim/run.py --config ../../tmp/live-necklace/hetzner.json --panel
```

Open **http://127.0.0.1:8765**. Click **Enable microphone**, allow the browser's
microphone permission, then hold **Hold to talk** (or the space bar). Speak when
the status says the microphone is running; release to finish the turn. Replies
play through the browser. Try “start recording audio”, “start a new recording”,
and “stop recording audio”. Those tools are deployed on Hetzner.

The panel displays actual firmware state, SD byte counts, camera state and
agent commands. Direct recording buttons use the same production phone command
handler without invoking the AI. A continuously enabled microphone also feeds
background recording; **Turn microphone off** stops browser capture. A missing
microphone feed releases a held button after two seconds. Closing the page
stops capture; the simulator process can be stopped with Ctrl-C. It otherwise
runs for up to 12 hours (override with `--seconds`).

Browser AudioWorklet → PCM16/16 kHz → simulated microphone → Opus encoder →
real nRF task/phone relay → server. The reverse path decodes Opus in the
simulated firmware and plays its PCM in the browser. The WebSocket still only
carries Opus audio. Live microphone buffering is bounded to 500 ms; underruns
produce silence. Use one panel tab per simulator session. Browser capture is
not a bit-for-bit deterministic fixture.

`panel_voice_test.py --wav /path/to/speech.wav --expect audio.start` runs an
explicit live AI test through the very same PCM API (also supports `audio.new`
and `audio.stop`). It requires the panel running and speech that requests the
specified action.

## Computer webcam / phone photo button

The **Simulated phone · Camera** section is a phone control, separate from the
necklace's push-to-talk button. Click **Enable webcam** and grant camera access,
then **Take photo**, or enable the microphone and tell the agent “take a photo”.
The agent's request and the phone button both ask the browser for a fresh frame.
The frame becomes the simulated camera sensor input. Actual camera capture,
SD handling and BLE packet transfer run in the firmware; the panel assembles
those returned packets to display the last received photo. The phone relay also
forwards the photo to the live server. This transmits the captured webcam image
to the configured server. **Turn webcam off** stops the camera tracks.

The browser scales JPEGs to fit the current legacy transfer limit (32 KB).
Missing webcam permission or a frame timeout produces an explicit capture
failure. Periodic webcam photos are not implemented; the live adapter rejects
`start_record` rather than silently reusing an old frame. The scripted simulator
still supports periodic-camera scenarios independently.

The necklace illustration uses the XY outline of the current enclosure's
`print/top.stl` and camera/microphone positions from `source/build_top.py`.
The binary STL is rotated for printing, so its camera ends up at the lower tip
in the worn front view. The underlying CAD/STL files are unchanged.

## WAV / automated run

Build the firmware simulator using its `sim/README.md` instructions. Install the
mobile package dependencies normally. Python needs `cryptography`; the server's
virtual environment already provides it. Flutter must be on PATH.

The local Hetzner enrollment/config is retained in the workspace's
`tmp/live-necklace/hetzner.json`. It belongs to Nathik's separate **Simulated
Necklace**, not a physical board. From `mobile/nx_main`:

```sh
python3 tool/necklace_sim/run.py --config ../../tmp/live-necklace/hetzner.json
```

Each run gets a fresh artifact directory. `firmware/speaker.wav` is the decoded
server response; `firmware/summary.json` and the trace contain firmware state.
The existing config sends a prerecorded test utterance after 500 ms, releases
the simulated button after eight seconds, and requires speaker output.

Use `--wav /absolute/path.wav` for your own PCM16 mono 16 kHz recording. Set
`press_ms`/`hold_ms` in the configuration to fit its duration. `--seconds` sets
run length. `--control-port` sets a stable local control port. Without it, the
runner prints the assigned port. Remove `press_ms` for manual button control:

```sh
curl -X POST http://127.0.0.1:PORT/press
curl -X POST http://127.0.0.1:PORT/release
curl http://127.0.0.1:PORT/state
curl -X POST http://127.0.0.1:PORT/stop
```

Time advances with wall time while network responses arrive. Controls are
bound to loopback only. State is observed from the real firmware, not inferred
from accepted server commands. A normal `audio.start`, `audio.stop` or
`audio.new` request passes through the production phone handler to the nRF
background recording callback. Success means the command was accepted;
completion remains asynchronous.

## Configuration and identity

Configuration fields: `binary`, `output`, `http_url`, `socket_url`, `python`,
`identity_script`, `identity_state`; optional `pairing_setup_file`, `domain_id`,
`microphone_wav`, `press_ms`, `hold_ms`, `duration_seconds`, `control_port`,
`min_speaker_samples`.

For another enrollment, create a `necklace` device through the normal
user-authenticated `/v1/devices` API. Save its returned setup privately, point
`pairing_setup_file` at it, and use a fresh `identity_state` path. The software
identity generates its own persistent P-256 key. The real phone authenticator
performs challenge/signature/token exchange and clears the local pairing
secret after success. Keep the identity file (mode 0600) to reconnect as the
same device. Never commit private state, pairing setup or tokens. Runtime
configuration stores paths, not secrets.

## Repeatable end-to-end check

From the workspace root:

```sh
servers/venv/bin/python mobile/nx_main/tool/necklace_sim/contract_test.py --workspace "$PWD"
```

This local protocol peer uses the server's actual proof verifier and packet
parser/serializers. It verifies signed authentication and WebSocket headers,
real firmware Opus uplink/EOF, downlink decoding into the simulated speaker,
three correlated recording commands, SD writes, final stopped state and a
byte-for-byte JPEG round trip through the real camera/SD/BLE path. It
makes no AI calls. The live runner separately exercises the deployed server.

## Current boundaries

- The panel supports live microphone input and immediate speaker playback.
  Automated runs can use a WAV fixture or deterministic simulator tone.
- BLE/SD remain simulated. The live panel uses a real webcam JPEG as its
  camera sensor input; deterministic tests can load a JPEG fixture. The original
  command-file simulator retains its synthetic byte pattern unless configured.
- Background audio files remain on the simulated SD card. The existing phone
  does not yet implement the simulator's type-3 file sync protocol, so this
  relay does not acknowledge or pretend to upload those files.
- Audio tools are deployed on Hetzner; another server needs the corresponding
  `audio.start`, `audio.new`, and `audio.stop` tool changes.
- Battery, haptic effects and cold resets return unsupported in this adapter.
- Network/AI timing is nondeterministic. Use the original scripted phone mode
  for deterministic fault injection and exact replay.
