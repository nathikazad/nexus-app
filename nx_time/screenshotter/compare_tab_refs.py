#!/usr/bin/env python3
"""Resize reference PNGs to match captured tab screenshots and print per-channel RMS.

Usage (from repo `mobile/nx_time`):
  python3 tests/compare_tab_refs.py

Expects (optional) in `tests/screenshots/`:
  reference_today.png / today_tab.png, reference_tasks.png / tasks_tab.png, etc.
Missing pairs are skipped.
"""

from __future__ import annotations

import math
import os
from pathlib import Path

try:
    from PIL import Image, ImageChops, ImageStat
except ImportError:
    print("Install Pillow: pip install pillow")
    raise SystemExit(1)

BASE = Path(__file__).resolve().parent / "screenshots"

PAIRS = [
    ("today_tab", "reference_today"),
    ("tasks_tab", "reference_tasks"),
    ("goals_tab", "reference_goals"),
    ("calendar_tab", "reference_calendar"),
]


def main() -> None:
    for shot, ref in PAIRS:
        p_shot = BASE / f"{shot}.png"
        p_ref = BASE / f"{ref}.png"
        if not p_shot.exists():
            print(f"skip {shot}: missing {p_shot.name}")
            continue
        if not p_ref.exists():
            print(f"skip {shot}: no reference {p_ref.name}")
            continue

        i1 = Image.open(p_shot).convert("RGB")
        i2 = Image.open(p_ref).convert("RGB").resize(i1.size, Image.Resampling.LANCZOS)
        diff = ImageChops.difference(i1, i2)
        st = ImageStat.Stat(diff)
        rms = [math.sqrt(s / len(diff.getdata())) for s in st.sum2]
        mean = sum(rms) / 3
        print(f"{shot} vs {ref}: mean RMS={mean:.2f} (lower is closer; 0=identical)")


if __name__ == "__main__":
    os.chdir(Path(__file__).resolve().parents[1])
    main()
