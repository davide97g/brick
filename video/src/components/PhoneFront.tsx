import React from "react";
import { SANS } from "../lib/theme";

// iPhone 17 Pro proportions in points (402 × 874); `scale` maps points to pixels. No logo, no
// buttons drawn: the phone is an object in the story, not a product shot.
export const PT_W = 402;
export const PT_H = 874;

export const PhoneFront: React.FC<{
  scale: number;
  children?: React.ReactNode;
  screenOn?: number; // 0 = glass off (black), 1 = lit
  statusTime?: string;
  statusColor?: string;
}> = ({ scale, children, screenOn = 1, statusTime = "20:10", statusColor = "#F2F2F0" }) => {
  const bezel = 11 * scale;
  const w = PT_W * scale;
  const h = PT_H * scale;
  const r = 62 * scale;
  return (
    <div
      style={{
        width: w + bezel * 2,
        height: h + bezel * 2,
        borderRadius: r + bezel,
        background: "linear-gradient(145deg, #3a3a3f 0%, #1c1c1f 38%, #111113 70%, #2a2a2e 100%)",
        padding: bezel,
        boxShadow: `0 ${40 * scale}px ${90 * scale}px rgba(0,0,0,0.55), inset 0 0 0 ${1.2 * scale}px rgba(255,255,255,0.10)`,
        position: "relative",
      }}
    >
      <div style={{ width: w, height: h, borderRadius: r, overflow: "hidden", position: "relative", background: "#000" }}>
        <div style={{ position: "absolute", inset: 0, opacity: screenOn }}>
          {children}
          {/* Status bar and Dynamic Island, drawn the way the app's own screenshots show them. */}
          <div
            style={{
              position: "absolute",
              top: 21 * scale,
              left: 44 * scale,
              fontFamily: SANS,
              fontWeight: 600,
              fontSize: 17 * scale,
              color: statusColor,
            }}
          >
            {statusTime}
          </div>
        </div>
        <div
          style={{
            position: "absolute",
            top: 11 * scale,
            left: (PT_W / 2 - 63) * scale,
            width: 126 * scale,
            height: 37 * scale,
            borderRadius: 19 * scale,
            background: "#000",
          }}
        />
        {/* Glass: one soft diagonal reflection, strongest when the screen is off. */}
        <div
          style={{
            position: "absolute",
            inset: 0,
            background: "linear-gradient(120deg, rgba(255,255,255,0.07) 0%, rgba(255,255,255,0) 34%)",
            opacity: 1 - screenOn * 0.6,
          }}
        />
      </div>
    </div>
  );
};
