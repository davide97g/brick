import React from "react";
import { AbsoluteFill, useCurrentFrame } from "remotion";
import { FloorPlan, PLAN_H, PLAN_W, BRICK_AT, PX_PER_M, walkedMetres } from "../components/FloorPlan";
import { PhoneFront } from "../components/PhoneFront";
import { HomeScreen } from "../components/HomeScreen";
import { Shield } from "../components/Shield";
import { C, SANS, engraved, readout } from "../lib/theme";
import { ease, lerp, prog } from "../lib/motion";
import { barf, section } from "../lib/timeline";

// Bars 10–16. From above: the flat. The brick stays on the desk; the phone walks away from it,
// a step a beat, and the distance between them is the only number that matters. Then the reflex
// from Act 0 again — an app opens — and the shield answers. The song's drum stop is "Not yet."

const WALK_FROM = 11; // bar
const STEPS = 10; // beats of walking

/** A step per beat: each beat eases one step forward, so the phone walks rather than glides. */
const walking = (f: number) => {
  const start = barf(WALK_FROM);
  if (f < start) return 0;
  let k = 0;
  while (k < STEPS && f >= barf(WALK_FROM, k + 1)) k++;
  if (k >= STEPS) return 1;
  const a = barf(WALK_FROM, k);
  const b = barf(WALK_FROM, k + 1);
  return (k + ease.inOut((f - a) / (b - a))) / STEPS;
};

const Headline: React.FC<{ o: number; children: React.ReactNode }> = ({ o, children }) => (
  <div style={{ fontFamily: SANS, fontWeight: 300, fontSize: 92, lineHeight: 1.08, letterSpacing: -2.2, color: C.inkOnPaper, textWrap: "balance", opacity: o, translate: `0px ${(1 - o) * 18}px` }}>
    {children}
  </div>
);

export const Act2Leave: React.FC = () => {
  const f = useCurrentFrame() + section("leave").from;
  const shieldCut = barf(14);

  if (f < shieldCut) {
    const draw = prog(f, barf(10), barf(11), ease.out);
    // Crane up: start close on the brick, pull out to the whole flat as the walls draw in.
    const pull = prog(f, barf(10), barf(11, 1), ease.inOut);
    const zoom = lerp(3.4, 1, pull);
    const walk = walking(f);
    const line = prog(f, barf(12), barf(12, 1), ease.out);
    const metres = walkedMetres(walk);
    // origin of the zoom: the brick, so the pull-out starts where Act 1 left the object
    const ox = BRICK_AT[0] * PX_PER_M + 20;
    const oy = BRICK_AT[1] * PX_PER_M + 20;
    return (
      <AbsoluteFill style={{ backgroundColor: C.paper, flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 90 }}>
        <div style={{ width: PLAN_W + 40, height: PLAN_H + 40, scale: String(zoom), transformOrigin: `${ox}px ${oy}px` }}>
          <FloorPlan draw={draw} walk={walk} trail={1} phone={prog(f, barf(10, 2), barf(10, 3), ease.out)} />
        </div>
        <div style={{ width: 560, display: "flex", flexDirection: "column", gap: 56, opacity: pull }}>
          <Headline o={line}>Expensive to leave.</Headline>
          <div style={{ display: "flex", flexDirection: "column", gap: 10, opacity: prog(f, barf(WALK_FROM), barf(WALK_FROM, 1)) }}>
            <div style={readout(C.inkOnPaper, 96)}>{metres.toFixed(1)} m</div>
            <div style={engraved(C.ashOnPaper, 20)}>from the brick</div>
          </div>
        </div>
      </AbsoluteFill>
    );
  }

  // The phone, front-on, on ink: an app opens by reflex, the shield answers.
  const press = prog(f, barf(14, 1.5), barf(14, 1.75), ease.out) * (1 - prog(f, barf(14, 1.75), barf(14, 2), ease.out));
  const shield = prog(f, barf(14, 2), barf(14, 2.6), ease.out);
  const notYet = prog(f, barf(15), barf(15) + 6, ease.out);
  const grid = <HomeScreen scale={0.98} note={0} bloom={1} press={press} />;
  return (
    <AbsoluteFill style={{ backgroundColor: C.ink, flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 150 }}>
      <PhoneFront scale={0.98}>
        {grid}
        <Shield scale={0.98} show={shield} title="1h 16m left" subtitle="desk slab, on your desk." backdrop={grid} />
      </PhoneFront>
      <div style={{ width: 760, fontFamily: SANS, fontWeight: 300, fontSize: 92, letterSpacing: -2.2, color: C.chalk, opacity: notYet }}>Not yet.</div>
    </AbsoluteFill>
  );
};
