import React from "react";
import { AbsoluteFill, useCurrentFrame } from "remotion";
import { WORLD } from "../components/World";
import { C } from "../lib/theme";
import { ease, prog } from "../lib/motion";

// All six Act 3 vignettes at once, for agreeing on the pen before they're cut to the beat.
const TIMES = ["20:26", "20:34", "20:41", "20:49", "20:58", "21:06"];

export const LookWorld: React.FC = () => {
  const f = useCurrentFrame();
  const t = f / 60;
  const draw = prog(f, 0, 12, ease.out);
  return (
    <AbsoluteFill style={{ backgroundColor: C.paperEdge, display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 6, padding: 6 }}>
      {WORLD.map((V, i) => (
        <div key={i} style={{ position: "relative", overflow: "hidden" }}>
          <div style={{ width: 1920, height: 1080, scale: "0.3313", transformOrigin: "0 0", position: "absolute" }}>
            <V t={t} draw={draw} time={TIMES[i]} />
          </div>
        </div>
      ))}
    </AbsoluteFill>
  );
};
