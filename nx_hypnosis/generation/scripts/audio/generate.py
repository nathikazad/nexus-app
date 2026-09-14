#!/usr/bin/env python3
"""Generate the approved female narration and extend phrase pauses, keeping raw audio."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
SCRIPTS = Path(__file__).resolve().parent


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('transcript', type=Path, help='UTF-8 narration text (optional SSML breaks)')
    p.add_argument('--name', help='Output stem; defaults to a timestamped transcript name')
    p.add_argument('--seconds', type=float, help='Optional total duration, e.g. 366; never stretches speech')
    p.add_argument('--pause-seconds', type=float, default=1.65)
    p.add_argument('--from-audio', type=Path, help='Reuse an existing raw take without an API request')
    p.add_argument('--dry-run', action='store_true', help='Validate without generating or writing audio')
    p.add_argument('--output-group', default='', help='Subfolder within generation/outputs')
    a = p.parse_args()
    import math
    if not math.isfinite(a.pause_seconds) or not .25 <= a.pause_seconds <= 4:
        p.error('Pause length must be between 0.25 and 4 seconds')
    if a.seconds is not None and (not math.isfinite(a.seconds) or a.seconds <= 0):
        p.error('Target duration must be positive and finite')
    text = a.transcript.read_text(encoding='utf-8').strip()
    if not text or len(text) > 10000:
        p.error('Transcript must contain 1–10,000 characters')
    if a.from_audio and not a.from_audio.is_file():
        p.error('Raw audio file does not exist')
    name = a.name or (a.transcript.stem + '-' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ'))
    if not name or Path(name).name != name or name in {'.', '..'}:
        p.error('Name must be a filename stem, without directory components')
    out = (ROOT / 'outputs' / a.output_group).resolve()
    if not out.is_relative_to((ROOT / 'outputs').resolve()):
        p.error('Output group must stay within outputs')
    final, raw = out / (name+'.mp3'), out / (name+'.raw.mp3')
    if any(path.exists() for path in (final, raw, final.with_suffix('.json'), raw.with_suffix('.json'), out/(name+'.txt'))):
        p.error('Output name already exists; choose a new name')
    for binary in ('ffmpeg', 'ffprobe'):
        if not shutil.which(binary):
            p.error(f'{binary} must be installed before generating')
    if a.dry_run:
        print(json.dumps({'voice_id':'Njn5qkKYqadqLJNsoRoL', 'characters':len(text),
                          'output':str(final), 'target_seconds':a.seconds,
                          'pause_seconds':a.pause_seconds, 'api_request':False}, indent=2))
        return
    out.mkdir(parents=True, exist_ok=True)
    (out/(name+'.txt')).write_text(text+'\n')
    if a.from_audio:
        shutil.copyfile(a.from_audio, raw)
        raw.with_suffix('.json').write_text(json.dumps({'reused_from':str(a.from_audio.resolve())},indent=2)+'\n')
    else:
        subprocess.run([sys.executable, str(SCRIPTS/'elevenlabs.py'), '--text-file', str(a.transcript.resolve()),
                        '--output', str(raw)], check=True)
    cmd = [sys.executable, str(SCRIPTS/'pauses.py'), str(raw), str(final), '--pause-seconds',str(a.pause_seconds)]
    if a.seconds is not None:
        cmd += ['--seconds', str(a.seconds)]
    subprocess.run(cmd, check=True)
    subprocess.run(['ffmpeg','-v','error','-i',str(final),'-f','null','-'],check=True)
    print(f'Audio ready: {final}')
    print(f'Raw take and settings retained: {raw}')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError) as exc:
        print(f'Generation stopped: {exc}. Reuse a saved raw take with --from-audio; do not automatically regenerate.',file=sys.stderr)
        sys.exit(1)
