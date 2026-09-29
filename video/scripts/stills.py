#!/usr/bin/env python3
"""Render review stills at song positions and tile them into one contact sheet.

  scripts/stills.py <out-name> label=bar:beats [label=bar:beats ...] [--scale 0.5]

Positions are trailer bars (and fractional beats) from data/edit.json, the same clock the scenes
use, so "8:0.6" is 0.6 beats after the tap whatever the song's tempo. Written because a shell loop
over "name frame" pairs doesn't word-split in zsh and silently renders frame 0.

Stills go to var/video/look/<out-name>/, the sheet to var/video/look/<out-name>.png.
"""
import json
import math
import subprocess
import sys
from pathlib import Path

VIDEO = Path(__file__).resolve().parent.parent
OUT = VIDEO.parent / "var" / "video" / "look"


def frame_at(bar, beats):
    d = json.loads((VIDEO / "data" / "edit.json").read_text())
    B, D = d["beats"], d["downbeats"]
    i = min(range(len(B)), key=lambda j: abs(B[j] - D[bar])) + beats
    k = int(math.floor(i))
    t = B[k] + (B[k + 1] - B[k]) * (i - k)
    return round(t * 60)


def main():
    args = sys.argv[1:]
    scale = "0.5"
    if "--scale" in args:
        j = args.index("--scale")
        scale = args[j + 1]
        del args[j:j + 2]
    name, shots = args[0], args[1:]
    d = OUT / name
    d.mkdir(parents=True, exist_ok=True)
    paths = []
    for s in shots:
        label, pos = s.split("=")
        bar, _, beats = pos.partition(":")
        f = frame_at(int(bar), float(beats or 0))
        p = d / f"{label}.png"
        subprocess.run(["bunx", "remotion", "still", "Trailer", str(p), f"--frame={f}", f"--scale={scale}", "--log=error"],
                       cwd=VIDEO, check=True)
        print(f"{label:14s} bar {pos:8s} frame {f}")
        paths.append(p)
    n = len(paths)
    if n == 1:
        import shutil
        shutil.copy(paths[0], OUT / f"{name}.png")
        print(OUT / f"{name}.png")
        return
    cols = 2 if n > 1 else 1
    rows = math.ceil(n / cols)
    while len(paths) < rows * cols:
        paths.append(paths[-1])
    inputs = sum((["-i", str(p)] for p in paths), [])
    layout = "|".join(f"{'+'.join(['w0'] * (i % cols)) or '0'}_{'+'.join(['h0'] * (i // cols)) or '0'}" for i in range(len(paths)))
    subprocess.run(["ffmpeg", "-v", "error", "-y", *inputs, "-filter_complex",
                    f"{''.join(f'[{i}]' for i in range(len(paths)))}xstack=inputs={len(paths)}:layout={layout}",
                    str(OUT / f"{name}.png")], check=True)
    print(OUT / f"{name}.png")


if __name__ == "__main__":
    main()
