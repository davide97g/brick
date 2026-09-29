import React from "react";
import { AbsoluteFill } from "remotion";
import { evolvePath } from "@remotion/paths";
import { C, MONO } from "../lib/theme";
import { ease, hash, lerp, prog } from "../lib/motion";

// Act 3: the world outside the flat, drawn in the same pen as the floor plan — ink hairlines on
// paper, nothing photographed. Each vignette draws itself on in a few frames (a cut lasts a beat
// or two) and then moves, so even a half-second plate reads as alive rather than as a slide.
//
// Every vignette takes `t` in seconds since its cut and `draw` 0…1 for the draw-on, and lays out
// in a 1920 × 1080 viewBox.

const INK = C.inkOnPaper;
const FAINT = C.chalkline;
const W = 1920;
const H = 1080;

const Stroke: React.FC<{ d: string; draw: number; width?: number; color?: string; dash?: string }> = ({ d, draw, width = 3, color = INK, dash }) => {
  if (dash) return <path d={d} fill="none" stroke={color} strokeWidth={width} strokeLinecap="round" strokeDasharray={dash} opacity={draw} />;
  const e = evolvePath(draw, d);
  return <path d={d} fill="none" stroke={color} strokeWidth={width} strokeLinecap="round" strokeLinejoin="round" strokeDasharray={e.strokeDasharray} strokeDashoffset={e.strokeDashoffset} />;
};

const Plate: React.FC<{ children: React.ReactNode; label: string; time: string }> = ({ children, label, time }) => (
  <AbsoluteFill style={{ backgroundColor: C.paper }}>
    <svg viewBox={`0 0 ${W} ${H}`} width="100%" height="100%">
      {children}
    </svg>
    {/* a map legend, not a caption: what it is, and when, while the session runs */}
    <div style={{ position: "absolute", left: 120, bottom: 96, fontFamily: MONO, fontSize: 30, color: C.ashOnPaper, letterSpacing: 1 }}>
      {label}
    </div>
    <div style={{ position: "absolute", right: 120, bottom: 96, fontFamily: MONO, fontSize: 30, color: C.ashOnPaper, letterSpacing: 1 }}>
      {time}
    </div>
  </AbsoluteFill>
);

type V = { t: number; draw: number; time: string };

/** Grass in wind: a few hundred blades, each a curve whose tip leans with a travelling gust. */
export const Grass: React.FC<V> = ({ t, draw, time }) => {
  const blades = [];
  for (let i = 0; i < 260; i++) {
    const x = 140 + (i / 260) * 1640 + hash(i) * 9;
    const base = 760 + hash(i + 7) * 26;
    const h = 150 + (hash(i + 3) + 1) * 110;
    const gust = Math.sin(t * 2.6 - x / 260) * 0.5 + Math.sin(t * 5.1 - x / 90 + i) * 0.12;
    const lean = (0.22 + gust * 0.35) * h;
    const p = prog(draw, (i / 260) * 0.5, (i / 260) * 0.5 + 0.5, ease.out);
    blades.push(
      <Stroke key={i} d={`M ${x} ${base} Q ${x + lean * 0.25} ${base - h * 0.6} ${x + lean} ${base - h}`} draw={p} width={2.2} />,
    );
  }
  return (
    <Plate label="grass, wind from the west" time={time}>
      <Stroke d={`M 120 ${800} L 1800 ${800}`} draw={draw} width={2} color={FAINT} />
      {blades}
    </Plate>
  );
};

/** A pitch from above, and one pass: the ball's path draws itself between two players (dots). */
export const Pitch: React.FC<V> = ({ t, draw, time }) => {
  const x0 = 360;
  const y0 = 190;
  const w = 1200;
  const h = 700;
  const d = [
    `M ${x0} ${y0} h ${w} v ${h} h ${-w} Z`,
    `M ${x0 + w / 2} ${y0} v ${h}`,
    `M ${x0 + w / 2 + 110} ${y0 + h / 2} a 110 110 0 1 0 -220 0 a 110 110 0 1 0 220 0`,
    `M ${x0} ${y0 + 190} h 190 v 320 h -190`,
    `M ${x0 + w} ${y0 + 190} h -190 v 320 h 190`,
  ];
  const a = { x: x0 + 420, y: y0 + 520 };
  const b = { x: x0 + 880, y: y0 + 210 };
  const pass = prog(t, 0.12, 0.62, ease.inOut);
  const bx = lerp(a.x, b.x, pass);
  const by = lerp(a.y, b.y, pass) - Math.sin(pass * Math.PI) * 60;
  return (
    <Plate label="five-a-side, second half" time={time}>
      {d.map((p, i) => (
        <Stroke key={i} d={p} draw={prog(draw, i * 0.08, 0.6 + i * 0.08, ease.out)} width={2.4} />
      ))}
      <path d={`M ${a.x} ${a.y} Q ${(a.x + b.x) / 2} ${(a.y + b.y) / 2 - 120} ${b.x} ${b.y}`} fill="none" stroke={C.ashOnPaper} strokeWidth={2} strokeDasharray="4 14" strokeLinecap="round" opacity={draw} />
      <circle cx={a.x} cy={a.y} r={16} fill={INK} opacity={draw} />
      <circle cx={b.x} cy={b.y} r={16} fill={INK} opacity={draw} />
      <circle cx={bx} cy={by} r={9} fill={C.paper} stroke={INK} strokeWidth={3} opacity={draw} />
    </Plate>
  );
};

/** A running track, lanes and one runner going round. */
export const Track: React.FC<V> = ({ t, draw, time }) => {
  const cx = 960;
  const cy = 520;
  const lanes = [0, 1, 2, 3, 4, 5];
  const lane = (k: number) => {
    const r = 170 + k * 26;
    const s = 330;
    return `M ${cx - s} ${cy - r} h ${2 * s} a ${r} ${r} 0 0 1 0 ${2 * r} h ${-2 * s} a ${r} ${r} 0 0 1 0 ${-2 * r}`;
  };
  // the runner: a point on lane 2's centre line, parametrised by distance round the oval
  const r = 170 + 2.5 * 26;
  const s = 330;
  const L = 4 * s + 2 * Math.PI * r;
  let u = ((t * 520) % L + L) % L;
  let px: number;
  let py: number;
  if (u < 2 * s) {
    px = cx - s + u;
    py = cy - r;
  } else if ((u -= 2 * s) < Math.PI * r) {
    const a = -Math.PI / 2 + u / r;
    px = cx + s + Math.cos(a) * r;
    py = cy + Math.sin(a) * r;
  } else if ((u -= Math.PI * r) < 2 * s) {
    px = cx + s - u;
    py = cy + r;
  } else {
    u -= 2 * s;
    const a = Math.PI / 2 + u / r;
    px = cx - s + Math.cos(a) * r;
    py = cy + Math.sin(a) * r;
  }
  return (
    <Plate label="400 m, lane three" time={time}>
      {lanes.map((k) => (
        <Stroke key={k} d={lane(k)} draw={prog(draw, k * 0.06, 0.55 + k * 0.06, ease.out)} width={k === 0 || k === 5 ? 2.6 : 1.6} color={k === 0 || k === 5 ? INK : FAINT} />
      ))}
      <circle cx={px} cy={py} r={13} fill={INK} opacity={draw} />
    </Plate>
  );
};

/** A bicycle wheel rolling: rim, hub, 32 spokes, the ground sliding under it. */
export const Wheel: React.FC<V> = ({ t, draw, time }) => {
  const cx = 960;
  const cy = 500;
  const R = 300;
  const rot = t * 5.2;
  const spokes = Array.from({ length: 32 }, (_, i) => {
    const a = rot + (i / 32) * Math.PI * 2;
    const a2 = a + (i % 2 ? 0.35 : -0.35); // tangential lacing, the way a real wheel is built
    return `M ${cx + Math.cos(a2) * 26} ${cy + Math.sin(a2) * 26} L ${cx + Math.cos(a) * (R - 18)} ${cy + Math.sin(a) * (R - 18)}`;
  });
  const ground = cy + R + 8;
  const dashOff = (t * 5.2 * R) % 80;
  return (
    <Plate label="the long way round" time={time}>
      <Stroke d={`M ${cx + R} ${cy} a ${R} ${R} 0 1 1 ${-2 * R} 0 a ${R} ${R} 0 1 1 ${2 * R} 0`} draw={draw} width={4} />
      <Stroke d={`M ${cx + R - 18} ${cy} a ${R - 18} ${R - 18} 0 1 1 ${-2 * (R - 18)} 0 a ${R - 18} ${R - 18} 0 1 1 ${2 * (R - 18)} 0`} draw={draw} width={1.6} />
      {spokes.map((d, i) => (
        <Stroke key={i} d={d} draw={prog(draw, 0.2 + (i / 32) * 0.3, 0.5 + (i / 32) * 0.3, ease.out)} width={1.3} />
      ))}
      <circle cx={cx} cy={cy} r={24} fill="none" stroke={INK} strokeWidth={3} opacity={draw} />
      <line x1={140} y1={ground} x2={1780} y2={ground} stroke={INK} strokeWidth={2.4} strokeDasharray="44 36" strokeDashoffset={dashOff} opacity={draw} />
    </Plate>
  );
};

/** A table for two, from above: two plates, two cups, steam. Nobody is looking at a phone. */
export const Table: React.FC<V> = ({ t, draw, time }) => {
  const cx = 960;
  const cy = 520;
  const circle = (x: number, y: number, r: number) => `M ${x + r} ${y} a ${r} ${r} 0 1 1 ${-2 * r} 0 a ${r} ${r} 0 1 1 ${2 * r} 0`;
  const steam = (x: number, y: number, k: number) => {
    const pts = Array.from({ length: 14 }, (_, i) => {
      const yy = y - i * 9;
      const xx = x + Math.sin(t * 3 + i * 0.6 + k) * (4 + i * 0.9);
      return `${i ? "L" : "M"} ${xx} ${yy}`;
    });
    return pts.join(" ");
  };
  // Place settings sit point-symmetric (cup at each diner's right hand), never mirrored: two
  // mirrored plates with cups above them read as a face.
  const seats = [
    { px: cx - 175, py: cy + 20, cup: [cx - 250, cy + 160], chair: -1 },
    { px: cx + 175, py: cy - 20, cup: [cx + 250, cy - 160], chair: 1 },
  ];
  const arc = (side: number) => {
    const x = cx + side * 400;
    return `M ${x} ${cy - 120} Q ${x + side * 70} ${cy} ${x} ${cy + 120}`;
  };
  return (
    <Plate label="dinner, two" time={time}>
      <Stroke d={circle(cx, cy, 330)} draw={draw} width={3} />
      <Stroke d={circle(cx, cy, 16)} draw={prog(draw, 0.5, 1)} width={1.8} />
      {seats.map((st) => (
        <g key={st.chair}>
          <Stroke d={arc(st.chair)} draw={prog(draw, 0.15, 0.7)} width={2.4} color={FAINT} />
          <Stroke d={circle(st.px, st.py, 92)} draw={prog(draw, 0.3, 0.9)} width={2.4} />
          <Stroke d={circle(st.px, st.py, 60)} draw={prog(draw, 0.4, 1)} width={1.4} />
          <Stroke d={circle(st.cup[0], st.cup[1], 26)} draw={prog(draw, 0.45, 1)} width={2.4} />
          <path d={steam(st.cup[0], st.cup[1] - 34, st.chair)} fill="none" stroke={C.ashOnPaper} strokeWidth={1.6} opacity={draw * 0.8} />
        </g>
      ))}
    </Plate>
  );
};

/** A street grid, two dots walking towards each other; they meet, and stop. */
export const Street: React.FC<V> = ({ t, draw, time }) => {
  const blocks = [];
  for (let i = 0; i < 5; i++) {
    for (let j = 0; j < 3; j++) {
      const x = 250 + i * 300;
      const y = 180 + j * 250;
      blocks.push(`M ${x} ${y} h 230 v 180 h -230 Z`);
    }
  }
  const meet = prog(t, 0, 1.0, ease.out);
  // one comes along the second street, one down an avenue; the corner is the meeting
  const ax = lerp(260, 1015, Math.min(1, meet * 1.08));
  const ay = 395;
  const bx = 1015;
  const by = lerp(900, 395, meet);
  return (
    <Plate label="meeting at the corner" time={time}>
      {blocks.map((d, i) => (
        <Stroke key={i} d={d} draw={prog(draw, (i % 5) * 0.08, 0.5 + (i % 5) * 0.08, ease.out)} width={2} color={i % 4 === 1 ? INK : FAINT} />
      ))}
      <path d={`M 260 395 H ${ax}`} stroke={C.ashOnPaper} strokeWidth={2} strokeDasharray="3 12" strokeLinecap="round" opacity={draw} />
      <path d={`M 1015 900 V ${by}`} stroke={C.ashOnPaper} strokeWidth={2} strokeDasharray="3 12" strokeLinecap="round" opacity={draw} />
      <circle cx={ax - 14} cy={ay} r={13} fill={INK} opacity={draw} />
      <circle cx={bx + 14} cy={by} r={13} fill={INK} opacity={draw} />
    </Plate>
  );
};

export const WORLD = [Grass, Pitch, Track, Wheel, Table, Street] as const;
