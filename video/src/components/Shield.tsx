import React from "react";
import { SANS } from "../lib/theme";

// The Screen Time shield as BrickShieldExtension configures it: ultra-thin dark material over the
// app, black at 55 %, no icon, the time left as the title and where the brick is as the subtitle,
// and the system's own OK button (the extension sets none, so iOS shows its default). The default
// button's colour is unverified here, so it's drawn neutral rather than guessed at.
// It's drawn because the shield can't be screenshotted: another process renders it.
export const Shield: React.FC<{
  scale: number;
  show: number; // 0…1
  title: string;
  subtitle: string;
  backdrop: React.ReactNode; // what the shield covers, blurred
}> = ({ scale: s, show, title, subtitle, backdrop }) => (
  <div style={{ position: "absolute", inset: 0, opacity: show }}>
    <div style={{ position: "absolute", inset: -30 * s, filter: `blur(${22 * s}px)` }}>{backdrop}</div>
    <div style={{ position: "absolute", inset: 0, background: "rgba(0,0,0,0.55)" }} />
    <div
      style={{
        position: "absolute",
        top: 330 * s,
        left: 30 * s,
        right: 30 * s,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        gap: 10 * s,
        translate: `0px ${(1 - show) * 24 * s}px`,
      }}
    >
      <div style={{ fontFamily: SANS, fontWeight: 700, fontSize: 24 * s, color: "#fff", textAlign: "center" }}>{title}</div>
      <div style={{ fontFamily: SANS, fontWeight: 400, fontSize: 17 * s, color: "rgba(255,255,255,0.7)", textAlign: "center" }}>{subtitle}</div>
    </div>
    <div
      style={{
        position: "absolute",
        left: 24 * s,
        right: 24 * s,
        bottom: 60 * s,
        height: 52 * s,
        borderRadius: 14 * s,
        background: "rgba(255,255,255,0.16)",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        fontFamily: SANS,
        fontWeight: 600,
        fontSize: 17 * s,
        color: "#fff",
      }}
    >
      OK
    </div>
  </div>
);
