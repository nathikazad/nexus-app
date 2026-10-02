"""Launch the desktop phone with a saved server/device config and fresh artifacts."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import subprocess
import uuid

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--config', type=Path, required=True)
parser.add_argument('--wav', type=Path, help='PCM16 mono 16 kHz microphone fixture')
parser.add_argument('--seconds', type=float)
parser.add_argument('--panel', action='store_true', help='Interactive microphone/control panel; no automatic utterance')
parser.add_argument('--control-port', type=int)
args = parser.parse_args()
config = json.loads(args.config.read_text())
artifact_root = Path(config['output']).parent
run = artifact_root / ('run-' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S') + '-' + uuid.uuid4().hex[:6])
run.mkdir(parents=True)
config['output'] = str(run / 'firmware')
if args.panel:
    for key in ('press_ms', 'hold_ms', 'microphone_wav'):
        config.pop(key, None)
    config['duration_seconds'] = 12 * 60 * 60
    config['min_speaker_samples'] = 0
    config['live_microphone'] = True
    config['control_port'] = args.control_port or 8765
if args.wav:
    config['microphone_wav'] = str(args.wav.resolve())
if args.seconds is not None:
    config['duration_seconds'] = args.seconds
if args.control_port is not None:
    config['control_port'] = args.control_port
runtime = run / 'config.json'
runtime.write_text(json.dumps(config, indent=2))
print(f'Run artifacts: {run}', flush=True)
result = subprocess.run(['flutter', 'test', 'tool/necklace_sim/live_test.dart', '--reporter', 'expanded'],
                        cwd=Path(__file__).resolve().parents[2],
                        env={**os.environ, 'NEXUS_SIM_CONFIG': str(runtime)})
raise SystemExit(result.returncode)
