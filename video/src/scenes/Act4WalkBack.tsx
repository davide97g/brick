import React from "react";
import { AbsoluteFill, useCurrentFrame } from "remotion";
import { FloorPlan, PLAN_H, PLAN_W, walkedMetres } from "../components/FloorPlan";
import { PhoneFront } from "../components/PhoneFront";
import { AppScreen } from "../components/AppScreen";
import { C, SANS, engraved, readout } from "../lib/theme";
import { ease, prog } from "../lib/motion";
import { barf, section } from "../lib/timeline";
import { hms, MINIMUM_S, SESSION_S, Table } from "./Act1Tap";

// Bars 24–32, the drop. The gate tick lights on the downbeat; the locked pill becomes "Tap your
// brick to end". Then the same flat, the same path, walked back — a step on every kick, the
// distance counting down to nothing. The same tap as Act 1, and the app returns to Ready.

const WALK_FROM = 25;
const STEPS = 14;
const TAP_BAR = 30;
const START = 20 * 3600 + 10 * 60;

const steps = (f: number) => {
  if (f < barf(WALK_FROM)) return 0;
  let k = 0;
  while (k < STEPS && f >= barf(WALK_FROM, k + 1)) k++;
  if (k >= STEPS) return 1;
  const a = barf(WALK_FROM, k);
  const b = barf(WALK_FROM, k + 1);
  return (k + ease.inOut((f - a) / (b - a))) / STEPS;
};

const Line: React.FC<{ o: number; color: string; children: React.ReactNode }> = ({ o, color, children }) => (
  <div style={{ fontFamily: SANS, fontWeight: 300, fontSize: 92, lineHeight: 1.08, letterSpacing: -2.2, color, textWrap: "balance", opacity: o, translate: `0px ${(1 - o) * 18}px` }}>
    {children}
  </div>
);

export const Act4WalkBack: React.FC = () => {
  const f = useCurrentFrame() + section("walkback").from;
  const gateAt = START + MINIMUM_S;

  // 24:0–24:2 — the gate opens
  if (f < barf(24, 2)) {
    const elapsed = MINIMUM_S + (f - barf(24)) / 60;
    // the gate flares on the drop and settles over two beats
    const pulse = Math.exp(-(f - barf(24)) / 16);
    return (
      <AbsoluteFill style={{ backgroundColor: C.ink, flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 150 }}>
        <PhoneFront scale={0.98} statusTime="20:55">
          <AppScreen
            scale={0.98}
            run={1}
            sweep={1}
            progress={elapsed / SESSION_S}
            gate={MINIMUM_S / SESSION_S}
            isOpen
            remaining={hms(SESSION_S - elapsed)}
            until="until 21:40"
            opensAt="20:55"
            where="desk slab, on your desk."
            showEmergency={1}
            gatePulse={pulse}
          />
        </PhoneFront>
        <div style={{ width: 760 }} />
      </AbsoluteFill>
    );
  }

  // 24:2–29:0 — the walk back
  if (f < barf(TAP_BAR - 1)) {
    const walk = 1 - steps(f);
    const line = prog(f, barf(WALK_FROM), barf(WALK_FROM, 1), ease.out);
    const metres = walkedMetres(walk);
    return (
      <AbsoluteFill style={{ backgroundColor: C.paper, flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 90 }}>
        <div style={{ width: PLAN_W + 40, height: PLAN_H + 40 }}>
          <FloorPlan draw={1} walk={walk} trail={1} phone={1} back />
        </div>
        <div style={{ width: 560, display: "flex", flexDirection: "column", gap: 56 }}>
          <Line o={line} color={C.inkOnPaper}>
            The only way out is the walk back.
          </Line>
          <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
            <div style={readout(C.inkOnPaper, 96)}>{metres.toFixed(1)} m</div>
            <div style={engraved(C.ashOnPaper, 20)}>from the brick</div>
          </div>
        </div>
      </AbsoluteFill>
    );
  }

  // 29:0–30:2 — the tap, the same as the first one
  if (f < barf(TAP_BAR, 2)) {
    return (
      <AbsoluteFill style={{ backgroundColor: C.paper }}>
        <Table f={f} tapBar={TAP_BAR} hero={false} />
      </AbsoluteFill>
    );
  }

  // 30:2–32:0 — Ready again
  const done = prog(f, barf(TAP_BAR, 2), barf(TAP_BAR, 2) + 18, ease.out);
  const line = prog(f, barf(31), barf(31, 1), ease.out);
  const ended = gateAt + 3 * 60; // the walk took three minutes
  const elapsed = ended - START;
  return (
    <AbsoluteFill style={{ backgroundColor: C.ink, flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 150 }}>
      <PhoneFront scale={0.98} statusTime="20:58">
        <AppScreen
          scale={0.98}
          run={1 - done}
          sweep={1}
          progress={elapsed / SESSION_S}
          gate={MINIMUM_S / SESSION_S}
          isOpen
          remaining={hms(SESSION_S - elapsed)}
          until="until 21:40"
          opensAt="20:55"
          where="desk slab, on your desk."
          showEmergency={1 - done}
          last="48m"
        />
      </PhoneFront>
      <div style={{ width: 760 }}>
        <Line o={line} color={C.chalk}>
          Ended at the brick.
        </Line>
      </div>
    </AbsoluteFill>
  );
};
