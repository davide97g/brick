import React from "react";
import { Surface, engraved, readout } from "../lib/theme";

// SessionRing.swift, redrawn: 72 ticks, elapsed ones lit, one longer tick at the gate.
// Geometry is kept proportional to the app's 274 pt bezel so it reads as the same instrument.
const TICKS = 72;

export const Dial: React.FC<{
  size: number;
  progress: number; // 0…1 through the session
  gate: number | null; // 0…1 where the minimum is met
  isOpen: boolean;
  readoutText: string;
  caption: string;
  surface: Surface;
  sweepIn?: number; // 0…1, ticks appear in order during the tap
  gatePulse?: number; // 0…1, the gate tick flares as it opens (the drop)
}> = ({ size, progress, gate, isOpen, readoutText, caption, surface, sweepIn = 1, gatePulse = 0 }) => {
  const k = size / 274;
  const r = size / 2;
  const elapsed = Math.round(TICKS * progress);
  const gateTick = gate === null ? null : Math.round(TICKS * gate);

  return (
    <div style={{ width: size, height: size, position: "relative" }}>
      <svg width={size} height={size} style={{ position: "absolute", inset: 0 }}>
        {Array.from({ length: TICKS }, (_, i) => {
          const visible = Math.min(1, Math.max(0, sweepIn * TICKS - i));
          if (visible <= 0) return null;
          const isGate = i === gateTick;
          const isElapsed = i < elapsed;
          const len = (isGate ? 22 * (1 + gatePulse * 0.9) : isElapsed ? 13 : 9) * k;
          const w = (isGate ? 2.5 * (1 + gatePulse * 0.8) : 1.5) * k;
          const color = isGate
            ? isOpen
              ? surface.fieldText
              : surface.fieldMuted
            : isElapsed
              ? surface.fieldText
              : surface.fieldRecessed;
          const a = (i / TICKS) * Math.PI * 2 - Math.PI / 2;
          return (
            <line
              key={i}
              x1={r + Math.cos(a) * (r - len)}
              y1={r + Math.sin(a) * (r - len)}
              x2={r + Math.cos(a) * r}
              y2={r + Math.sin(a) * r}
              stroke={color}
              strokeWidth={w}
              strokeLinecap="round"
              opacity={visible}
            />
          );
        })}
      </svg>
      <div
        style={{
          position: "absolute",
          inset: 0,
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          gap: 10 * k,
        }}
      >
        <div style={readout(surface.fieldText, 52 * k)}>{readoutText}</div>
        <div style={engraved(surface.fieldMuted, 11 * k)}>{caption}</div>
      </div>
    </div>
  );
};
