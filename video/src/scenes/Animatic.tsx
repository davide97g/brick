import React from "react";
import { AbsoluteFill, interpolate, Sequence, staticFile, useCurrentFrame } from "remotion";
import { Audio } from "@remotion/media";
import { audio, bar, env, sec, section } from "../lib/timeline";
import { C, MONO, SANS } from "../lib/theme";

// Stand-in for the trailer until acts are built: each act is a titled card on the real cut of the
// song, with the kick, the bar count and the story beats marked, so the director's cut can be
// watched (and heard) for pacing before any art exists.
const ACTS: Record<string, { title: string; line: string }> = {
  reflex: { title: "0 · Reflex", line: "Willpower loses at three seconds." },
  tap: { title: "1 · The tap", line: "Instant to enter." },
  leave: { title: "2 · Leave it", line: "Expensive to leave." },
  time: { title: "3 · Time, and the world outside", line: "15 minutes minimum." },
  walkback: { title: "4 · Walk back", line: "The only way out is the walk back." },
  card: { title: "5 · Everything else", line: "A session you walk away from." },
};

// Story beats pinned to trailer bars (see analysis/edit.py for which song bars they are).
const CUES: [number, string][] = [
  [8, "TAP · first kick"],
  [15, "NOT YET · drum stop"],
  [16, "WORLD CUTS · build"],
  [24, "GATE · drop, walk back"],
  [32, "MONTAGE"],
  [36, "CARD · piano motif"],
];

const Meter: React.FC = () => {
  const frame = useCurrentFrame();
  const t = frame / 60;
  const lastKick = [...audio.onsets.kick].reverse().find(([k]) => k <= t);
  const kick = lastKick ? interpolate(t - lastKick[0], [0, 0.18], [1, 0], { extrapolateRight: "clamp" }) : 0;
  const k = audio.downbeats.findLastIndex((d) => d <= t);
  const b = audio.beats.findLastIndex((x) => x <= t);
  const beatInBar = k >= 0 ? audio.beats.slice(0, b + 1).filter((x) => x >= audio.downbeats[k]).length : 0;
  return (
    <div style={{ position: "absolute", bottom: 80, left: 120, right: 120, display: "flex", gap: 28, alignItems: "center" }}>
      <div style={{ width: 26, height: 26, borderRadius: 13, background: C.chalk, opacity: 0.15 + kick * 0.85 }} />
      <div style={{ fontFamily: MONO, fontSize: 28, color: C.ash, width: 360 }}>
        bar {Math.max(0, k)} · beat {beatInBar}
      </div>
      <div style={{ flex: 1, height: 6, background: C.graphite, borderRadius: 3, overflow: "hidden" }}>
        <div style={{ width: `${env("low", frame) * 100}%`, height: "100%", background: C.ash }} />
      </div>
      <div style={{ fontFamily: MONO, fontSize: 28, color: C.ash, width: 160, textAlign: "right" }}>
        {t.toFixed(2)}s
      </div>
    </div>
  );
};

export const ActCard: React.FC<{ name: string }> = ({ name }) => (
  <AbsoluteFill style={{ backgroundColor: C.ink, alignItems: "center", justifyContent: "center", gap: 28 }}>
    <div style={{ fontFamily: MONO, fontSize: 30, color: C.ash, letterSpacing: 6, textTransform: "uppercase" }}>{ACTS[name].title}</div>
    <div style={{ fontFamily: SANS, fontWeight: 300, fontSize: 88, letterSpacing: -2, color: C.chalk }}>{ACTS[name].line}</div>
  </AbsoluteFill>
);

export const Animatic: React.FC = () => (
  <AbsoluteFill style={{ backgroundColor: C.ink }}>
    <Audio src={staticFile("trailer.wav")} />
    {audio.sections.map((s) => {
      const act = ACTS[s.name];
      return (
        <Sequence key={s.name} {...section(s.name)}>
          <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", gap: 28 }}>
            <div style={{ fontFamily: MONO, fontSize: 30, color: C.ash, letterSpacing: 6, textTransform: "uppercase" }}>
              {act.title}
            </div>
            <div style={{ fontFamily: SANS, fontWeight: 300, fontSize: 88, letterSpacing: -2, color: C.chalk }}>
              {act.line}
            </div>
          </AbsoluteFill>
        </Sequence>
      );
    })}
    {CUES.map(([k, label]) => (
      <Sequence key={label} from={bar(k)} durationInFrames={sec(1.6)} layout="none">
        <div style={{ position: "absolute", top: 90, width: "100%", textAlign: "center", fontFamily: MONO, fontSize: 34, letterSpacing: 4, color: C.chalk }}>
          ▼ {label}
        </div>
      </Sequence>
    ))}
    <Meter />
  </AbsoluteFill>
);
