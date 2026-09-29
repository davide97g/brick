import React from "react";
import { interpolate } from "remotion";
import { Dial } from "./Dial";
import { C, SANS, Surface, engraved, readout, standard } from "../lib/theme";
import { ease, lerp } from "../lib/motion";

// buriko's home screen, redrawn in points from store/screenshots/6.9/01-idle.png and 03-running.png.
// Redrawn rather than screenshotted so every tick can move on the beat and so the running state can
// be shown at all (the app's own capture can't film a live session).
//
// One deliberate omission: the oxide "Hold to unlock" pill stays hidden until Act 3 shows the
// emergency hold, so the film's only colour arrives at the one moment it means something.

const Pill: React.FC<{ s: number; fill: string; color: string; label: string; stroke?: string }> = ({ s, fill, color, label, stroke }) => (
  <div
    style={{
      height: 46 * s,
      borderRadius: 23 * s,
      background: fill,
      border: stroke ? `${1 * s}px solid ${stroke}` : undefined,
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      fontFamily: SANS,
      fontWeight: 500,
      fontSize: 16 * s,
      color,
    }}
  >
    {label}
  </div>
);

const SettingsGlyph: React.FC<{ s: number; color: string }> = ({ s, color }) => (
  <svg width={16 * s} height={14 * s} viewBox="0 0 16 14" style={{ overflow: "visible" }}>
    {[2, 7, 12].map((y, i) => (
      <g key={y} stroke={color} strokeWidth={1} fill="none">
        <line x1={0} y1={y} x2={16} y2={y} />
        <circle cx={[11, 5, 9][i]} cy={y} r={1.6} fill={C.ink} />
      </g>
    ))}
  </svg>
);

/** The drawn brick on the idle screen (BrickBlock in Theme.swift): chamfered slab, engraved ring. */
const BrickBlock: React.FC<{ s: number }> = ({ s }) => (
  <div
    style={{
      width: 178 * s,
      height: 110 * s,
      borderRadius: 40 * s,
      background: "linear-gradient(180deg, #272729, #141416)",
      boxShadow: `inset 0 0 0 ${1 * s}px #54545A33, 0 ${14 * s}px ${40 * s}px rgba(0,0,0,0.6)`,
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
    }}
  >
    <div style={{ width: 35 * s, height: 35 * s, borderRadius: "50%", border: `${2.2 * s}px solid ${C.ash}` }} />
  </div>
);

export const AppScreen: React.FC<{
  scale: number;
  run: number; // 0 idle → 1 running (the transition after the tap)
  sweep: number; // 0…1 ticks appear in order
  progress: number;
  gate: number;
  isOpen?: boolean;
  remaining: string;
  until: string;
  opensAt: string;
  where: string;
  showEmergency?: number; // 0…1
  emergencyFill?: number; // 0…1 how far the hold has filled the pill
  surface?: Surface;
  last?: string; // the idle card's "Last" line
  gatePulse?: number;
}> = ({ scale: s, run, sweep, progress, gate, isOpen = false, remaining, until, opensAt, where, showEmergency = 0, emergencyFill = 0, surface = standard, last = "1h 40m", gatePulse = 0 }) => {
  const idle = 1 - run;
  const cardTop = lerp(709, 607, ease.out(run));
  return (
    <div style={{ position: "absolute", inset: 0, background: surface.field }}>
      {/* header */}
      <div style={{ position: "absolute", top: 76 * s, left: 25 * s, ...engraved(surface.fieldText, 12 * s), letterSpacing: 3 * s }}>
        {run > 0.5 ? "Bricked" : "Brick"}
      </div>
      <div style={{ position: "absolute", top: 78 * s, right: 25 * s }}>
        <SettingsGlyph s={s} color={surface.fieldMuted} />
      </div>

      {/* idle: the drawn brick and "Ready" */}
      <div
        style={{
          position: "absolute",
          top: 307 * s,
          left: 0,
          right: 0,
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          opacity: idle,
          scale: interpolate(idle, [0, 1], [0.92, 1]),
        }}
      >
        <BrickBlock s={s} />
        <div style={{ ...readout(surface.fieldText, 44 * s), marginTop: 36 * s, fontWeight: 200 }}>Ready</div>
        <div style={{ ...engraved(surface.fieldMuted, 11 * s), marginTop: 12 * s }}>12 apps, 2 categories, 3 sites</div>
      </div>

      {/* running: the bezel */}
      <div
        style={{
          position: "absolute",
          top: (354 - 131) * s,
          left: (201 - 131) * s,
          opacity: run > 0 ? 1 : 0,
        }}
      >
        <Dial size={262 * s} progress={progress} gate={gate} isOpen={isOpen} readoutText={remaining} caption={until} surface={surface} sweepIn={sweep} gatePulse={gatePulse} />
      </div>

      {/* the paper card */}
      <div
        style={{
          position: "absolute",
          top: cardTop * s,
          left: 0,
          right: 0,
          bottom: 0,
          background: surface.card,
          borderTopLeftRadius: 30 * s,
          borderTopRightRadius: 30 * s,
          padding: `${22 * s}px ${20 * s}px`,
        }}
      >
        <div style={{ position: "absolute", inset: `${24 * s}px ${20 * s}px auto`, opacity: idle }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
            <div style={engraved(surface.cardMuted, 11 * s)}>Last</div>
            <div style={{ fontFamily: SANS, fontSize: 15 * s, color: surface.cardMuted }}>
              <span style={{ color: surface.cardText }}>{last}</span> · ended at the brick
            </div>
          </div>
          <div style={{ marginTop: 22 * s }}>
            <Pill s={s} fill={C.inkOnPaper} color={C.chalk} label="Start a session" />
          </div>
        </div>
        <div style={{ position: "absolute", inset: `${22 * s}px ${20 * s}px auto`, opacity: run, display: "flex", flexDirection: "column", gap: 10 * s }}>
          <div style={{ fontFamily: SANS, fontSize: 15 * s, color: surface.cardMuted, textAlign: "center", marginBottom: 8 * s }}>{where}</div>
          {/* SolidPill: disabled while locked, ink and live once the gate has passed */}
          <Pill s={s} fill={isOpen ? surface.cardText : "rgba(23,23,26,0.10)"} color={isOpen ? surface.card : "rgba(23,23,26,0.55)"} label={isOpen ? "Tap your brick to end" : "Locked"} />
          <div style={{ ...engraved(surface.cardMuted, 11 * s), textAlign: "center", opacity: isOpen ? 0 : 1 }}>The brick opens at {opensAt}</div>
          <div style={{ marginTop: 6 * s, opacity: showEmergency, display: "flex", flexDirection: "column", gap: 8 * s }}>
            {/* EmergencyUnlockButton: an outlined capsule that fills with oxide from the left while held */}
            <div style={{ position: "relative", height: 46 * s, borderRadius: 23 * s, overflow: "hidden", border: `${1 * s}px solid rgba(23,23,26,0.18)` }}>
              <div style={{ position: "absolute", inset: 0, width: `${emergencyFill * 100}%`, background: C.oxide, opacity: 0.9 }} />
              <div
                style={{
                  position: "absolute",
                  inset: 0,
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  fontFamily: SANS,
                  fontWeight: 500,
                  fontSize: 15 * s,
                  color: emergencyFill > 0.42 ? C.paper : C.oxide,
                }}
              >
                {emergencyFill > 0 ? "Keep holding" : "Hold to unlock"}
              </div>
            </div>
            <div style={{ ...engraved(surface.cardMuted, 11 * s), textAlign: "center" }}>3 left this week</div>
          </div>
        </div>
      </div>
    </div>
  );
};
