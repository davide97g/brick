import React from "react";
import { interpolate } from "remotion";
import { C, SANS, readout } from "../lib/theme";
import { ease, prog } from "../lib/motion";

// The phone on its own: lock screen, a notification, the grid of apps. Icons are abstract grey
// tiles: Screen Time tokens are opaque to the app, and no one else's brand belongs in the film.
const TONES = ["#2B2B2F", "#3A3A3E", "#4B4B50", "#5E5E64", "#74747A", "#8E8E94"];
const PRESSED = 9; // third row, second column: an app a thumb finds without looking
const tone = (i: number) => TONES[(i * 7 + (i >> 2) * 3) % TONES.length];

export const HomeScreen: React.FC<{
  scale: number;
  note: number; // notification banner 0…1
  bloom: number; // 0 lock screen → 1 grid open
  press?: number; // 0…1 one icon pressed, the reflex opening an app
}> = ({ scale: s, note, bloom, press = 0 }) => {
  const cols = 4;
  const rows = 6;
  const icon = 64;
  const gapX = (402 - 2 * 26 - cols * icon) / (cols - 1);
  const top = 92;
  const rowH = 96;
  return (
    <div style={{ position: "absolute", inset: 0, background: "radial-gradient(120% 80% at 50% 20%, #1d1d21 0%, #0b0b0d 70%)" }}>
      {/* lock screen */}
      <div style={{ position: "absolute", top: 120 * s, width: "100%", textAlign: "center", opacity: 1 - prog(bloom, 0, 0.35) }}>
        <div style={{ fontFamily: SANS, fontSize: 18 * s, fontWeight: 500, color: C.ash }}>Tuesday 29 September</div>
        <div style={{ ...readout(C.chalk, 96 * s), fontWeight: 300, marginTop: 2 * s }}>20:10</div>
      </div>
      <div
        style={{
          position: "absolute",
          left: 14 * s,
          right: 14 * s,
          top: interpolate(ease.out(note), [0, 1], [-90, 330]) * s,
          height: 74 * s,
          borderRadius: 22 * s,
          background: "rgba(80,80,86,0.55)",
          opacity: note * (1 - prog(bloom, 0, 0.3)),
          display: "flex",
          alignItems: "center",
          gap: 12 * s,
          padding: `0 ${14 * s}px`,
        }}
      >
        <div style={{ width: 38 * s, height: 38 * s, borderRadius: 9 * s, background: TONES[4] }} />
        <div style={{ flex: 1, display: "flex", flexDirection: "column", gap: 7 * s }}>
          <div style={{ width: "46%", height: 9 * s, borderRadius: 5 * s, background: "#c9c9cd" }} />
          <div style={{ width: "78%", height: 8 * s, borderRadius: 4 * s, background: "#8e8e94" }} />
        </div>
      </div>
      {/* the grid */}
      {Array.from({ length: cols * rows }, (_, i) => {
        const c = i % cols;
        const r = Math.floor(i / cols);
        // bloom outward from the middle of the grid, the way the springboard opens
        const d = Math.hypot(c - 1.5, r - 2.5) / 3.2;
        const p = prog(bloom, d * 0.35, d * 0.35 + 0.55, ease.overshoot);
        return (
          <div
            key={i}
            style={{
              position: "absolute",
              left: (26 + c * (icon + gapX)) * s,
              top: (top + r * rowH) * s,
              width: icon * s,
              height: icon * s,
              borderRadius: 15 * s,
              background: tone(i),
              opacity: Math.min(1, p * 1.4),
              scale: interpolate(p, [0, 1], [0.55, 1]) * (i === PRESSED ? 1 - press * 0.12 : 1),
              filter: i === PRESSED && press > 0 ? `brightness(${1 - press * 0.35})` : undefined,
            }}
          />
        );
      })}
      {/* dock */}
      <div
        style={{
          position: "absolute",
          left: 14 * s,
          right: 14 * s,
          bottom: 14 * s,
          height: 92 * s,
          borderRadius: 32 * s,
          background: "rgba(60,60,66,0.5)",
          opacity: prog(bloom, 0.2, 0.7),
          display: "flex",
          justifyContent: "space-around",
          alignItems: "center",
        }}
      >
        {[1, 3, 5, 2].map((t) => (
          <div key={t} style={{ width: icon * s, height: icon * s, borderRadius: 15 * s, background: TONES[t], scale: interpolate(prog(bloom, 0.3, 0.8, ease.overshoot), [0, 1], [0.6, 1]) }} />
        ))}
      </div>
    </div>
  );
};
