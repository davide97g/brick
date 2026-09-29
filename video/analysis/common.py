"""Shared paths / cache setup for the trailer analysis scripts (ported from riddle's
apps/video/analysis, itself from mexicat/pdoom-video).

Import this module FIRST (before torch / huggingface / mlx imports) so that all
model downloads land in the cache below.

Everything these scripts write except data/*.json is regenerable and large
(model weights, stems, intermediates, QA plots), so it lives under the repo's
var/video/analysis/: gitignored whole,
and deleting it is a legitimate fix.
"""
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parent          # video/analysis/
PROJECT = ROOT.parent                            # video/
VAR = PROJECT.parent / "var" / "video" / "analysis"
CACHE = VAR / ".cache"
for var, sub in [("TORCH_HOME", "torch"), ("HF_HOME", "hf"), ("HF_HUB_CACHE", "hf/hub"),
                 ("XDG_CACHE_HOME", "xdg"), ("HUGGINGFACE_HUB_CACHE", "hf/hub"),
                 ("TRANSFORMERS_CACHE", "hf/transformers"), ("MPLCONFIGDIR", "mpl"),
                 ("NUMBA_CACHE_DIR", "numba"), ("UV_CACHE_DIR", "uv")]:
    os.environ.setdefault(var, str(CACHE / sub))
    (CACHE / sub).mkdir(parents=True, exist_ok=True)

AUDIO = PROJECT / "song" / "piano-motif.mp3"
STEMS = VAR / "stems" / "htdemucs_ft" / "piano-motif"
DATA = PROJECT / "data"
QA = VAR / "qa"
WORK = VAR / "work"          # intermediate results (whisper json, alignments)
QA.mkdir(parents=True, exist_ok=True)
WORK.mkdir(parents=True, exist_ok=True)
DATA.mkdir(exist_ok=True)


# Demucs runs on work/mix.wav, the gapless ffmpeg decode of the mp3 (the same
# timeline a browser plays), so the stems need no shift.
STEM_OFFSET_SAMPLES = 0
STEM_OFFSET_SEC = STEM_OFFSET_SAMPLES / 44100


def load_stem(name, sr=None, mono=True):
    """Load a Demucs stem, time-aligned to the gapless mp3 decode."""
    import soundfile as sf
    import numpy as np
    y, s = sf.read(STEMS / f"{name}.wav", dtype="float32", always_2d=True)
    assert s == 44100
    y = y[STEM_OFFSET_SAMPLES:]
    y = y.mean(axis=1) if mono else y.T
    if sr and sr != s:
        import soxr
        y = soxr.resample(y, s, sr) if mono else np.stack([soxr.resample(c, s, sr) for c in y])
        s = sr
    return y, s



def load_mix(sr=44100, mono=True):
    import librosa
    y, s = librosa.load(str(AUDIO), sr=sr, mono=mono)
    return y, s
