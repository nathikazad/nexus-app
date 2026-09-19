#!/bin/bash
set -eu
ADB=${ADB:-${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb}
OUT=${1:-/tmp/nx-canvas-diagnostics-$(date +%Y%m%d-%H%M%S)}
mkdir -p "$OUT"
"$ADB" pull /sdcard/Android/data/com.nexus.nx_notes/files/canvas-diagnostics "$OUT/" || true
"$ADB" logcat -d -v threadtime -t 30000 -s NxCanvasDiag:I AndroidRuntime:E > "$OUT/logcat.txt"
"$ADB" shell dumpsys meminfo com.nexus.nx_notes > "$OUT/memory.txt"
"$ADB" shell dumpsys gfxinfo com.nexus.nx_notes > "$OUT/frames.txt"
"$ADB" shell dumpsys activity lastanr > "$OUT/last-anr.txt"
"$ADB" shell dumpsys activity exit-info com.nexus.nx_notes > "$OUT/exit-info.txt"
"$ADB" shell dumpsys package com.nexus.nx_notes > "$OUT/package.txt"
printf 'Saved tablet diagnostics to %s\n' "$OUT"
python3 "$(dirname "$0")/summarize_canvas_transitions.py" "$OUT"
