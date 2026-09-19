#!/usr/bin/env python3
"""Button-only Android open/return benchmark; requires an existing visible canvas.
Never draws, erases, edits text or acknowledges Android dialogs. Uses fresh UI
bounds before every click and waits for app trace milestones, not fixed sleeps.
"""
import argparse
import json
import os
from pathlib import Path
import queue
import re
import subprocess
import threading
import time
import xml.etree.ElementTree as ET


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cycles', type=int, default=3)
    parser.add_argument('--output', required=True)
    parser.add_argument('--return-first', action='store_true')
    args = parser.parse_args()
    adb = os.environ.get('ADB', str(Path.home() / 'Library/Android/sdk/platform-tools/adb'))
    events = queue.Queue()
    records = []
    log = subprocess.Popen([adb, 'logcat', '-T', '1', '-v', 'raw', '-s', 'NxCanvasDiag:I', '*:S'], stdout=subprocess.PIPE, text=True)
    def read():
        for line in log.stdout:
            try:
                row = json.loads(line)
                records.append(row)
                events.put(row)
            except json.JSONDecodeError:
                pass
    threading.Thread(target=read, daemon=True).start()
    def shell(*cmd):
        return subprocess.check_output([adb, 'shell', *cmd], text=True, timeout=30)
    def click(label, expected_activity):
        current = shell('dumpsys', 'activity', 'activities')
        resumed = next((line for line in current.splitlines() if 'mResumedActivity' in line), '')
        if expected_activity not in resumed:
            raise RuntimeError(f'Expected {expected_activity}, got {resumed}')
        for attempt in range(5):
            shell('input', 'keyevent', '224')
            shell('rm', '-f', '/sdcard/nx-benchmark-ui.xml')
            dump = shell('uiautomator', 'dump', '/sdcard/nx-benchmark-ui.xml')
            if 'UI hierchary dumped to' in dump:
                break
        else:
            raise RuntimeError('No fresh UI tree after five attempts')
        root = ET.fromstring(shell('cat', '/sdcard/nx-benchmark-ui.xml'))
        nodes = [n for n in root.iter('node') if (n.get('text') == label or n.get('content-desc') == label)]
        if len(nodes) != 1:
            raise RuntimeError(f'Expected exactly one {label!r} control, found {len(nodes)}')
        current = shell('dumpsys', 'activity', 'activities')
        resumed = next((line for line in current.splitlines() if 'mResumedActivity' in line), '')
        if expected_activity not in resumed:
            raise RuntimeError(f'Activity changed before click: {resumed}')
        x1,y1,x2,y2 = map(int, re.findall(r'\d+', nodes[0].get('bounds', '')))
        # Some e-ink firmware drops zero-duration injected taps. Use a short,
        # stationary press, only inside a verified button/preview on the expected screen.
        shell('input', 'keyevent', '224')
        shell('input', 'touchscreen', 'swipe', str((x1+x2)//2), str((y1+y2)//2), str((x1+x2)//2), str((y1+y2)//2), '150')
    def wait(stage, trace=None):
        deadline = time.monotonic()+90
        while time.monotonic()<deadline:
            try: row = events.get(timeout=1)
            except queue.Empty: continue
            if (row.get('stage') or row.get('event')) == stage and (trace is None or row.get('trace_id') == trace):
                return row
        raise RuntimeError(f'Timed out waiting for {stage}')
    try:
        if args.return_first:
            click('‹ Document', 'NativeEditorActivity')
            wait('transition.return.frame')
        for cycle in range(args.cycles):
            click('Canvas', 'MainActivity')
            opened = wait('transition.open.input_enabled')
            trace = opened['trace_id']
            click('‹ Document', 'NativeEditorActivity')
            returned = wait('transition.return.frame', trace)
            print(json.dumps({'cycle':cycle+1,'trace_id':trace,'open_ms':opened['wall_ms'],'return_ms':returned['duration_us']/1000}), flush=True)
    finally:
        log.terminate()
        log.wait(timeout=5)
        Path(args.output).write_text(''.join(json.dumps(r)+'\n' for r in records))


if __name__ == '__main__':
    main()
