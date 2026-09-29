"""The 1:30 cut of the 3:29 song -> public/trailer.wav + data/edit.json.

Suno's take is phrased in 4-bar units (the bass drops out on the 4th bar of each phrase), so every
splice sits on a phrase boundary downbeat and the loop continues as if it were written that way.
Each segment carries the act it scores (docs/TREATMENT.md); the acts are the director's cut, the
bars are the song's.

  bars  0-12   intro (piano alone) -> the kick on bar 8 is the tap      reflex, tap, leave
  bars 20-24   end of groove A, bar 23 is the drum stop                 leave ("Not yet." on the stop)
  bars 64-72   build: drums, no bass, thinning towards the drop         time (dial + the world outside)
  bars 72-80   the drop, bass back at full                              walkback (gate passes on bar 72)
  bars 80-84   drop continued                                           card (montage)
  bars 91-end  piano motif alone, decay                                 card (wordmark)

Output is re-timed: data/edit.json holds beats, downbeats, onsets and envelopes in *trailer* time,
so the video never needs to know where in the song a moment came from.

Run:  uv run python edit.py        (after prep.py, beats.py, analyze.py)
"""
import common
import json

import numpy as np
import soundfile as sf

# (first bar, end bar or None = end of song, section name for the video)
SEGMENTS = [
    (0, 12, "open"),
    (20, 24, "stop"),
    (64, 72, "build"),
    (72, 80, "drop"),
    (80, 84, "montage"),
    (91, None, "outro"),
]
# Where the acts start, in *trailer* bars (bar 0 = first downbeat of the cut).
ACTS = [("reflex", 0), ("tap", 4), ("leave", 10), ("time", 16), ("walkback", 24), ("card", 32)]

# Splices sit this far ahead of the downbeat, on both sides, so the crossfade finishes before the
# kick's attack instead of shaving it off. Durations are unchanged: every cut point moves together.
LEAD = 0.060
XFADE = 0.030          # equal-power crossfade at an in-groove splice
XFADE_OUTRO = 0.180    # the groove -> solo piano cut gets a longer one so the kick's tail doesn't click


def main():
    audio = json.loads((common.DATA / "audio.json").read_text())
    mix, sr = sf.read(common.WORK / "mix.wav", dtype="float32", always_2d=True)
    db = audio["downbeats"]
    dur = audio["duration"]
    bar_t = lambda k: dur if k is None else float(db[k]) - LEAD

    # librosa's grid sits a little after the kick attacks (it follows the onset envelope's peak, the
    # eye wants the transient). Shift it onto the attacks so a hit drawn on a downbeat lands with
    # the sound, not 1-2 frames behind it.
    kicks = np.array([t for t, _ in audio["onsets"]["kick"]])
    near = [kicks[np.argmin(np.abs(kicks - t))] - t for t in db if np.abs(kicks - t).min() < 0.08]
    shift = float(np.median(near))
    print(f"grid -> kick attack shift {shift * 1000:.1f} ms over {len(near)} bars")

    segs = []
    for i, (a, b, name) in enumerate(SEGMENTS):
        # The song's first downbeat is 0.158 s in: keep the pickup before it.
        s0 = 0.0 if a == 0 else bar_t(a)
        segs.append(dict(name=name, src_start=s0, src_end=bar_t(b), bars=[a, b]))

    out = np.zeros((0, mix.shape[1]), dtype=np.float32)
    for i, s in enumerate(segs):
        x = mix[int(round(s["src_start"] * sr)):int(round(s["src_end"] * sr))].copy()
        splice = len(out)
        if i > 0:
            xf = XFADE_OUTRO if s["name"] == "outro" else XFADE
            n = int(xf * sr)
            # Crossfade centred on the splice: the tail of the previous segment runs n/2 past its
            # end, the head of this one starts n/2 early, so the downbeat stays exactly on time.
            pre = mix[int(round(s["src_start"] * sr)) - n // 2:int(round(s["src_start"] * sr))]
            post = mix[int(round(segs[i - 1]["src_end"] * sr)):int(round(segs[i - 1]["src_end"] * sr)) + n // 2]
            x = np.concatenate([pre, x])
            out = np.concatenate([out, post])
            ramp = np.linspace(0, np.pi / 2, n, dtype=np.float32)[:, None]
            head = x[:n] * np.sin(ramp)
            tail = out[-n:] * np.cos(ramp)
            out[-n:] = head + tail
            x = x[n:]
        s["out_start"] = round(splice / sr, 4)
        out = np.concatenate([out, x])
        s["out_end"] = round(len(out) / sr, 4)
    # The song's own ending decays to silence; make sure the last sample is silent.
    fade = int(0.05 * sr)
    out[-fade:] *= np.linspace(1, 0, fade, dtype=np.float32)[:, None]
    wav = common.PROJECT / "public" / "trailer.wav"
    sf.write(wav, out, sr, subtype="PCM_24")
    duration = len(out) / sr

    def remap_times(ts):
        r = []
        for s in segs:
            for t in ts:
                if s["src_start"] <= t < s["src_end"]:
                    r.append(round(t - s["src_start"] + s["out_start"], 3))
        return sorted(r)

    def remap_onsets(os_):
        r = []
        for s in segs:
            for t, v in os_:
                if s["src_start"] <= t < s["src_end"]:
                    r.append([round(t - s["src_start"] + s["out_start"], 3), v])
        return sorted(r)

    fps = audio["fps"]
    env = {}
    for k in ("rms", "low", "mid", "high", "drums", "bass", "other"):
        e = []
        for s in segs:
            e += audio[k][int(round(s["src_start"] * fps)):int(round(s["src_end"] * fps))]
        env[k] = e

    beats = remap_times([t + shift for t in audio["beats"]])
    downbeats = remap_times([t + shift for t in audio["downbeats"]])
    # The cut's first segment starts before the song's first downbeat, so trailer bar 0 is its
    # first downbeat, not t = 0.
    acts = []
    for j, (name, k) in enumerate(ACTS):
        end = ACTS[j + 1][1] if j + 1 < len(ACTS) else None
        acts.append(dict(name=name, start=0.0 if k == 0 else downbeats[k],
                         end=round(duration, 3) if end is None else downbeats[end]))

    doc = dict(
        source=str(common.AUDIO.name),
        duration=round(duration, 3),
        bpm=audio["bpm"],
        grid_shift=round(shift, 4),
        beat_period=audio["beat_period"],
        beats=beats,
        downbeats=downbeats,
        sections=acts,
        segments=segs,
        fps=fps,
        onsets={k: remap_onsets(v) for k, v in audio["onsets"].items() if k != "vocal"},
        **env,
    )
    (common.DATA / "edit.json").write_text(json.dumps(doc, separators=(",", ":")))
    print(f"wrote {wav.name} {duration:.2f}s, {len(downbeats)} bars")
    for s in segs:
        print(f"  {s['name']:8s} song {s['src_start']:7.2f}-{s['src_end']:7.2f}  ->  trailer {s['out_start']:6.2f}-{s['out_end']:6.2f}")
    for a in acts:
        print(f"  act {a['name']:9s} {a['start']:6.2f}-{a['end']:6.2f}")


if __name__ == "__main__":
    main()
