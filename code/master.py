#!/usr/bin/env python3
"""master.py -- reproduce every asset in the post, end to end.

    python3 code/master.py

Two stages, deliberately separate:

    analysis.py   AEI release + primary calendar -> modified_data/*.csv
                  (all cleaning, panel construction and estimation)
    figures.py    modified_data/*.csv -> output/post/post_NN_*.png

Nothing in analysis.py draws and nothing in figures.py estimates, so a figure
can never quietly disagree with the number it is plotting.

analysis.py checks its own estimates against the R pipeline it replaced and
exits non-zero if they drift, so a failure here is a real failure, not noise.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

CODE = Path(__file__).resolve().parent

for stage in ("analysis.py", "figures.py"):
    print(f"\n=== {stage} ===", flush=True)
    r = subprocess.run([sys.executable, str(CODE / stage)])
    if r.returncode != 0:
        sys.exit(f"[master] {stage} failed with code {r.returncode}")

print("\n[master] post assets rebuilt -> output/post/")
