#!/usr/bin/env python3
"""Compare activity / add / edit screenshots to HTML reference captures.

Usage (from `mobile/nx_time`):
  python3 tests/compare_activity_refs.py

Expects in `tests/screenshots/`:
  activity_detail.png vs reference_activity_detail.png
  add_time_block.png vs reference_add_time_block.png
  edit_activity.png vs reference_edit_activity.png
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
    ("activity_detail", "reference_activity_detail"),
    ("add_time_block", "reference_add_time_block"),
    ("edit_activity", "reference_edit_activity"),
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
