#!/usr/bin/env python3
"""Level an already slowed, pause-smoothed recording without changing its timing."""
import argparse
from array import array
import json
import math
from pathlib import Path
import subprocess
import sys

FILTERS = (
    'highpass=f=120,'
    'bass=g=-5:f=200:t=q:w=0.7,'
    'acompressor=threshold=0.025:ratio=3:attack=30:release=400:knee=2:makeup=1,'
    'dynaudnorm=f=250:g=15:p=0.65:m=10:r=0.1:t=0.01:c=0'
)


def decode(path):
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', str(path),
                          '-ac', '1', '-ar', '16000', '-f', 'f32le', '-'],
                         check=True, capture_output=True).stdout
    samples = array('f', raw)
    if sys.byteorder != 'little':
        samples.byteswap()
    return samples


def db(value):
    return round(20 * math.log10(max(value, 1e-10)), 2)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    if not args.source.is_file() or args.output.exists():
        parser.error('Source must exist and output must be a new file.')
    subprocess.run(['ffmpeg', '-v', 'error', '-n', '-i', str(args.source),
                    '-af', FILTERS, '-c:a', 'libmp3lame', '-b:a', '192k',
                    str(args.output)], check=True)
    before, after = decode(args.source), decode(args.output)
    assert len(before) == len(after), 'Timing changed'
    assert max(abs(x) for x in after) < 0.99, 'Output clips'
    # Compare identical active speech windows; pauses do not bias this measure.
    levels_before, levels_after = [], []
    pause_peaks = []
    for offset in range(0, len(before)-16000, 16000):
        a, b = before[offset:offset+16000], after[offset:offset+16000]
        rms_a = math.sqrt(sum(x*x for x in a)/len(a))
        rms_b = math.sqrt(sum(x*x for x in b)/len(b))
        if rms_a > 0.015:
            levels_before.append(db(rms_a))
            levels_after.append(db(rms_b))
        if max(abs(x) for x in a) < 0.0001:
            pause_peaks.append(max(abs(x) for x in b))
    def spread(values):
        values = sorted(values)
        return round(values[int(len(values)*.9)]-values[int(len(values)*.1)], 2)
    report = {'source': str(args.source.resolve()), 'filters': FILTERS,
              'duration_seconds': len(after)/16000,
              'speech_10th_to_90th_percentile_range_db_before': spread(levels_before),
              'speech_10th_to_90th_percentile_range_db_after': spread(levels_after),
              'peak_dbfs': db(max(abs(x) for x in after)),
              'quiet_pause_windows_checked': len(pause_peaks),
              'quiet_pause_max_peak_dbfs': db(max(pause_peaks, default=0)),
              'timing_unchanged': True}
    args.output.with_suffix('.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
