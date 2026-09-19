#!/usr/bin/env python3
"""Print recent canvas transition timelines from a capture directory (local logs)."""
import argparse
import json
from collections import defaultdict
from pathlib import Path


def summarize(directory, latest=3):
    groups = defaultdict(list)
    for path in Path(directory).rglob('events*.jsonl'):
        for line in path.read_text().splitlines():
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue  # A capture can end during the last write.
            trace = row.get('trace_id') or row.get('transition')
            if trace:
                groups[(row.get('run'), trace)].append(row)
    ordered = sorted(groups.items(), key=lambda pair: max(r['time_ms'] for r in pair[1]))
    for (_, trace), rows in ordered[-latest:]:
        print(f'\nTrace {trace}')
        for row in sorted(rows, key=lambda r: r.get('dart_time_ms', r['time_ms'])):
            if row.get('phase') == 'begin':
                continue
            stage = row.get('stage', row['event'])
            duration = row.get('wall_ms')
            if duration is None and 'duration_us' in row:
                duration = row['duration_us'] / 1000
            timing = f'{duration:9.1f} ms' if duration is not None else '            '
            total = ' total' if stage.startswith('transition.') and duration is not None else ''
            print(f'  {timing}  {stage}{total}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory')
    parser.add_argument('--latest', type=int, default=3)
    args = parser.parse_args()
    summarize(args.directory, args.latest)
