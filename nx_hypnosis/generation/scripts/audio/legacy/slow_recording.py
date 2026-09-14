#!/usr/bin/env python3
"""Render a slower, pitch-preserving copy and extend existing quiet pauses.

Requires ffmpeg on PATH. Does not call ElevenLabs or alter the source recording.
"""
import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import wave


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--tempo', type=float, default=0.75)
    parser.add_argument('--minimum-pause', type=float, default=2.5)
    args = parser.parse_args()
    if not 0.5 <= args.tempo <= 1 or not 0 <= args.minimum_pause <= 10:
        parser.error('Tempo must be 0.5–1; minimum pause must be 0–10 seconds.')
    if not args.source.is_file() or args.output.exists():
        parser.error('Source must exist and output must be a new file.')
    ffmpeg = shutil.which('ffmpeg')
    if ffmpeg is None:
        parser.error('Install ffmpeg first.')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='hypnosis-audio-') as directory:
        slow = Path(directory) / 'slow.wav'
        padded = Path(directory) / 'paused.wav'
        subprocess.run([ffmpeg, '-v', 'error', '-i', str(args.source), '-af',
                        f'atempo={args.tempo}', '-c:a', 'pcm_s16le', str(slow)], check=True)
        detection = subprocess.run([ffmpeg, '-hide_banner', '-i', str(slow), '-af',
                                    'silencedetect=noise=-42dB:d=0.7', '-f', 'null', '-'],
                                   check=True, capture_output=True, text=True)
        # Only extend completed natural silences, never splice inside speech.
        gaps = [(float(end), float(duration)) for end, duration in re.findall(
            r'silence_end: ([\d.]+) \| silence_duration: ([\d.]+)', detection.stderr)]
        with wave.open(str(slow), 'rb') as incoming:
            params = incoming.getparams()
            frames = incoming.readframes(params.nframes)
        frame_size = params.nchannels * params.sampwidth
        rate = params.framerate
        added = 0
        extended = 0
        with wave.open(str(padded), 'wb') as outgoing:
            outgoing.setparams(params)
            outgoing.writeframes(b'\0' * round(1.5 * rate) * frame_size)
            cursor = 0
            for end, duration in gaps:
                boundary = min(round(end * rate), params.nframes) * frame_size
                outgoing.writeframes(frames[cursor:boundary])
                extra = max(0, round((args.minimum_pause - duration) * rate))
                outgoing.writeframes(b'\0' * extra * frame_size)
                added += extra
                extended += bool(extra)
                cursor = boundary
            outgoing.writeframes(frames[cursor:])
            outgoing.writeframes(b'\0' * round(3 * rate) * frame_size)
        subprocess.run([ffmpeg, '-v', 'error', '-n', '-i', str(padded), '-c:a',
                        'libmp3lame', '-b:a', '192k', str(args.output)], check=True)
        report = dict(source=str(args.source.resolve()), output=str(args.output.resolve()),
                      tempo=args.tempo, minimum_pause_seconds=args.minimum_pause,
                      natural_pauses_extended=extended, added_pause_seconds=round(added/rate+4.5,3),
                      duration_seconds=round(params.nframes/rate+added/rate+4.5,3))
        args.output.with_suffix('.json').write_text(json.dumps(report, indent=2)+'\n')
        print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
