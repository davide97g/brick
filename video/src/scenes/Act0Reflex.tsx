import React from "react";
import { AbsoluteFill, useCurrentFrame } from "remotion";
import { PhoneFront } from "../components/PhoneFront";
import { HomeScreen } from "../components/HomeScreen";
import { C, SANS } from "../lib/theme";
import { ease, hash, prog } from "../lib/motion";
import { barf } from "../lib/timeline";

// Bars 0–4, piano alone. The phone wakes, a notification lands, the grid opens, it goes dark —
// three times, each faster, and nobody is holding it. The reflex is the phone's, not a person's.
type Cycle = { wake: number; note?: number; bloom: [number, number]; dim: [number, number] };
const CYCLES: Cycle[] = [
  { wake: 1, note: 1.5, bloom: [2.5, 3.75], dim: [6.25, 7.5] },
  { wake: 8, note: 8.25, bloom: [8.75, 9.6], dim: [10.5, 11.25] },
  { wake: 12, bloom: [12.25, 12.85], dim: [13.5, 13.9] },
];

export const Act0Reflex: React.FC = () => {
  const f = useCurrentFrame(); // the act starts at frame 0 of the film
  const b = (x: number) => barf(0, x);

  let screenOn = 0;
  let note = 0;
  let bloom = 0;
  let buzz = 0;
  for (const c of CYCLES) {
    if (f < b(c.wake) - 1) continue;
    screenOn = prog(f, b(c.wake), b(c.wake) + 9, ease.out) * (1 - prog(f, b(c.dim[0]), b(c.dim[1]), ease.in));
    note = c.note === undefined ? 0 : prog(f, b(c.note), b(c.note) + 20, ease.out);
    bloom = prog(f, b(c.bloom[0]), b(c.bloom[1]), ease.linear);
    // a notification is a buzz: the only thing that moves the phone is the phone
    buzz = c.note !== undefined && f >= b(c.note) ? 1 - prog(f, b(c.note), b(c.note) + 16, ease.linear) : 0;
  }
  const jitter = buzz > 0 ? hash(f) * 3 * buzz : 0;
  const line = prog(f, b(8), b(9), ease.out);

  // The phone holds the centre alone until the line arrives, then gives the line its slot.
  const slide = prog(f, b(7.5), b(9), ease.inOut);
  return (
    <AbsoluteFill style={{ backgroundColor: C.ink, flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 150 }}>
      <div style={{ translate: `${jitter + (1 - slide) * 455}px 0px` }}>
        <PhoneFront scale={0.98} screenOn={screenOn}>
          <HomeScreen scale={0.98} note={note} bloom={bloom} />
        </PhoneFront>
      </div>
      <div
        style={{
          width: 760,
          fontFamily: SANS,
          fontWeight: 300,
          fontSize: 92,
          lineHeight: 1.08,
          letterSpacing: -2.2,
          color: C.chalk,
          opacity: line,
          translate: `${(1 - slide) * 455}px ${(1 - line) * 18}px`,
        }}
      >
        Willpower loses at three seconds.
      </div>
    </AbsoluteFill>
  );
};
