import React from "react";
import { AbsoluteFill, useCurrentFrame } from "remotion";
import { PhoneFront } from "../components/PhoneFront";
import { AppScreen } from "../components/AppScreen";
import { WORLD } from "../components/World";
import { C, SANS } from "../lib/theme";
import { ease, lerp, prog } from "../lib/motion";
import { barf, section } from "../lib/timeline";
import { hms, MINIMUM_S, SESSION_S } from "./Act1Tap";

// Bars 16–24, the build (drums, no bass). The session's clock runs fast and the world outside
// comes in cuts that speed up with the hats: two beats, then one, then half. When the build thins
// (bars 21–23) the film is back on the dial: one tick lights per beat towards the gate, and a
// thumb-less hold on the emergency pill starts, fills a third, and lets go. The gate itself is
// reached on the downbeat of bar 24 — the drop — where Act 4 begins.

const START = 20 * 3600 + 10 * 60; // 20:10, when the session began

const clock = (s: number) => {
  const t = Math.floor(s);
  const h = Math.floor(t / 3600);
  const m = Math.floor((t % 3600) / 60);
  return `${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")}`;
};

type Cut = { bar: number; beat: number; len: number; plate: "dial" | number };
// bar 17: two beats a cut · bar 18: one · bar 19: dial for two, then one · bar 20: half
const CUTS: Cut[] = [
  { bar: 16, beat: 0, len: 4, plate: "dial" },
  { bar: 17, beat: 0, len: 2, plate: 0 },
  { bar: 17, beat: 2, len: 2, plate: 1 },
  { bar: 18, beat: 0, len: 1, plate: 2 },
  { bar: 18, beat: 1, len: 1, plate: 3 },
  { bar: 18, beat: 2, len: 1, plate: 4 },
  { bar: 18, beat: 3, len: 1, plate: 5 },
  { bar: 19, beat: 0, len: 2, plate: "dial" },
  { bar: 19, beat: 2, len: 1, plate: 0 },
  { bar: 19, beat: 3, len: 1, plate: 1 },
  ...[2, 3, 4, 5, 0, 1, 2, 5].map((p, i) => ({ bar: 20, beat: i * 0.5, len: 0.5, plate: p as number })),
  { bar: 21, beat: 0, len: 12, plate: "dial" },
];

/**
 * The session clock, in seconds since midnight, as a function of the film's frame. Three regimes:
 * the tail of the shield scene into bar 16 (20:24 → 20:27), the world cuts (→ 20:40), and the last
 * three bars, where it runs one dial tick (75 s) per beat so the gate lands on the drop at 20:55.
 */
const sessionClock = (f: number) => {
  const gate = START + MINIMUM_S;
  if (f < barf(17)) return lerp(START + 14 * 60, START + 17 * 60, prog(f, barf(16), barf(17), ease.linear));
  if (f < barf(21)) return lerp(START + 17 * 60, gate - 15 * 60, prog(f, barf(17), barf(21), ease.linear));
  // a tick per beat, eased into each beat like a clock's second hand
  const i = Math.floor((f - barf(21)) / (barf(21, 1) - barf(21)));
  const k = Math.min(12, i);
  const a = barf(21, k);
  const b = barf(21, k + 1);
  const within = k >= 12 ? 0 : ease.out(Math.min(1, (f - a) / Math.max(1, (b - a) * 0.35)));
  return gate - 15 * 60 + (k + within) * 75;
};

const Headline: React.FC<{ o: number; children: React.ReactNode }> = ({ o, children }) => (
  <div style={{ width: 760, fontFamily: SANS, fontWeight: 300, fontSize: 92, lineHeight: 1.08, letterSpacing: -2.2, color: C.chalk, opacity: o, translate: `0px ${(1 - o) * 18}px`, textWrap: "balance" }}>
    {children}
  </div>
);

export const Act3Time: React.FC = () => {
  const f = useCurrentFrame() + section("time").from;
  const cut = [...CUTS].reverse().find((c) => f >= barf(c.bar, c.beat)) ?? CUTS[0];
  const from = barf(cut.bar, cut.beat);
  const now = sessionClock(f);
  const elapsed = now - START;

  if (cut.plate !== "dial") {
    const V = WORLD[cut.plate];
    return <V t={(f - from) / 60} draw={prog(f, from, from + Math.min(10, (barf(cut.bar, cut.beat + cut.len) - from) * 0.6), ease.out)} time={clock(now)} />;
  }

  const late = f >= barf(21);
  // The emergency beat: the pill appears on bar 21, a hold starts on 21:2, fills a third of its
  // ten seconds (sped up), and is released on 22:2 — it drains back and the session carries on.
  const show = prog(f, barf(21), barf(21, 1), ease.out);
  const fill = prog(f, barf(21, 2), barf(22, 2), ease.linear) * 0.34 * (1 - prog(f, barf(22, 2), barf(22, 2.5), ease.out));
  const lineA = prog(f, barf(16), barf(16, 1), ease.out) * (1 - prog(f, barf(16, 3.5), barf(17), ease.in));
  // The last bar before the drop is the dial's alone: the line clears, the ticks walk to the gate.
  const lineB = prog(f, barf(21, 2), barf(21, 3), ease.out) * (1 - prog(f, barf(23), barf(23, 1), ease.in));
  return (
    <AbsoluteFill style={{ backgroundColor: C.ink, flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 150 }}>
      <PhoneFront scale={0.98} statusTime={clock(now)}>
        <AppScreen
          scale={0.98}
          run={1}
          sweep={1}
          progress={elapsed / SESSION_S}
          gate={MINIMUM_S / SESSION_S}
          remaining={hms(SESSION_S - elapsed)}
          until="until 21:40"
          opensAt="20:55"
          where="desk slab, on your desk."
          showEmergency={late ? show : 0}
          emergencyFill={fill}
        />
      </PhoneFront>
      {late ? (
        <Headline o={lineB}>Emergency: hold for ten seconds. Three a week.</Headline>
      ) : (
        <Headline o={cut.bar === 16 ? lineA : 0}>Until 20:55, the brick does nothing.</Headline>
      )}
    </AbsoluteFill>
  );
};
