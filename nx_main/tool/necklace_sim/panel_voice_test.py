"""Send a WAV through the panel's live PCM microphone API and assert an AI action.

Explicit live test: invokes the configured server's agent. Start the panel first.
"""
import argparse
import json
import time
import urllib.request
import wave

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--url', default='http://127.0.0.1:8765')
parser.add_argument('--wav', required=True)
parser.add_argument('--expect', choices=['audio.start', 'audio.stop', 'audio.new', 'take_photo'], required=True)
args = parser.parse_args()

def request(path, data=None):
    with urllib.request.urlopen(urllib.request.Request(args.url + path, data=data), timeout=5) as response:
        body = response.read()
        return json.loads(body) if path == '/state' else body

before = request('/state')
last_event = max((e['id'] for e in before['events']), default=0)
with wave.open(args.wav) as wav:
    assert (wav.getnchannels(), wav.getsampwidth(), wav.getframerate()) == (1, 2, 16000)
    pcm = wav.readframes(wav.getnframes())
request('/microphone/on', b'')
try:
    request('/press', b'')
    # Match the real wake delay before speaking, then provide 100 ms PCM batches.
    audio = bytes(32000) + pcm + bytes(6400)
    start = time.monotonic()
    for offset in range(0, len(audio), 3200):
        request('/pcm', audio[offset:offset+3200])
        time.sleep(max(0, start + (offset + 3200) / 32000 - time.monotonic()))
finally:
    request('/release', b'')
    request('/microphone/off', b'')
for _ in range(150):
    state = request('/state')
    invoked = any(e['id'] > last_event and e['text'] == 'Agent → ' + args.expect for e in state['events'])
    enabled = (state['camera_done'] > before['camera_done'] if args.expect == 'take_photo'
               else state['background_enabled'] == (0 if args.expect == 'audio.stop' else 1))
    if invoked and enabled and state['speaker_samples'] > before['speaker_samples']:
        print(f"PASS: live streamed speech → Hetzner → {args.expect} → firmware state, speaker reply")
        break
    time.sleep(.2)
else:
    raise AssertionError(f'Expected {args.expect}; recent events: {state["events"][-8:]}')
