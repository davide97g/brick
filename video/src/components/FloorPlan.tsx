import React, { useMemo } from "react";
import { evolvePath, getLength, getPointAtLength, getTangentAtLength } from "@remotion/paths";
import { C, engraved } from "../lib/theme";

// One flat, drawn the way an architect would: ink walls, hairline furniture, door swings, windows.
// Acts 2 and 4 both happen here. The only thing that changes between them is where the phone is,
// so the drawing is fixed and everything else is a prop.
//
// Plan units are metres (10 × 6.5 m flat, y down); PX_PER_M maps them to the 1920 × 1080 frame.

export const PX_PER_M = 104;
export const PLAN_W = 10 * PX_PER_M;
export const PLAN_H = 6.5 * PX_PER_M;
const m = (v: number) => v * PX_PER_M;

type Seg = [number, number, number, number];

// Walls, each a segment in metres. Gaps are doorways.
const WALLS: Seg[] = [
  // outer shell (the entrance is the gap on the bottom wall, x 4.3–5.2)
  [0, 0, 10, 0],
  [10, 0, 10, 6.5],
  [10, 6.5, 5.2, 6.5],
  [4.3, 6.5, 0, 6.5],
  [0, 6.5, 0, 0],
  // bedroom / bath / hall line, with the bedroom door (3.7–4.15) and bath door (4.6–5.25)
  [0, 2.6, 3.7, 2.6],
  [4.15, 2.6, 4.6, 2.6],
  [5.25, 2.6, 5.8, 2.6],
  [4.2, 0, 4.2, 2.6],
  // study / hall, study door 3.0–3.9
  [3.6, 2.6, 3.6, 3.0],
  [3.6, 3.9, 3.6, 6.5],
  // hall / living, a wide opening 3.3–4.7
  [5.8, 0, 5.8, 3.3],
  [5.8, 4.7, 5.8, 6.5],
];

// Doors: hinge, radius and the quarter the leaf swings through.
const DOORS: { x: number; y: number; r: number; a0: number; a1: number }[] = [
  { x: 4.15, y: 2.6, r: 0.45, a0: Math.PI, a1: Math.PI * 1.5 },
  { x: 5.25, y: 2.6, r: 0.65, a0: Math.PI, a1: Math.PI * 1.5 },
  { x: 3.6, y: 3.9, r: 0.9, a0: Math.PI, a1: Math.PI * 1.5 },
  { x: 5.2, y: 6.5, r: 0.9, a0: Math.PI, a1: Math.PI * 1.5 },
];

const WINDOWS: Seg[] = [
  [1.0, 0, 3.0, 0],
  [6.5, 0, 9.3, 0],
  [10, 2.0, 10, 5.0],
  [0, 3.5, 0, 5.5],
];

// Furniture as rectangles [x, y, w, h] in metres, plus a few circles.
const RECTS: [number, number, number, number][] = [
  [0.3, 5.7, 1.8, 0.6], // desk
  [0.4, 0.3, 2.0, 2.0], // bed
  [0.55, 0.4, 0.75, 0.4], // pillows
  [1.45, 0.4, 0.75, 0.4],
  [4.4, 0.2, 1.2, 0.7], // bath
  [6.0, 0.2, 3.8, 0.6], // kitchen counter
  [7.5, 5.5, 2.3, 0.8], // sofa
  [7.7, 5.5, 1.9, 0.2],
  [8.0, 4.4, 1.2, 0.6], // low table
];
const CIRCLES: [number, number, number][] = [
  [1.15, 5.2, 0.26], // desk chair
  [7.4, 2.1, 0.55], // dining table
  [4.95, 1.9, 0.22], // basin
];
const LABELS: [string, number, number][] = [
  ["Study", 1.8, 4.1],
  ["Bedroom", 2.1, 1.55],
  ["Hall", 4.7, 5.1],
  ["Kitchen", 7.9, 1.25],
  ["Living", 7.9, 3.4],
];

/** Where the brick sits: on the desk, by the right-hand end. */
export const BRICK_AT: [number, number] = [1.7, 6.0];

// The walk: off the desk, out of the study, down the hall, round the low table, onto the sofa. Catmull-Rom through
// these, so the path is a person's rather than a robot's.
const WAYPOINTS: [number, number][] = [
  [1.72, 5.62], // beside the brick: the walk starts and ends at the object, so 0.0 m means it
  [1.35, 5.3],
  [2.3, 4.5],
  [3.2, 3.55],
  [3.95, 3.45],
  [4.9, 3.85],
  [6.2, 4.05],
  [7.2, 4.3],
  [7.6, 5.05],
  [8.45, 5.85],
];

const catmull = (pts: [number, number][]) => {
  const p = pts.map(([x, y]) => [m(x), m(y)]);
  let d = `M ${p[0][0]} ${p[0][1]}`;
  for (let i = 0; i < p.length - 1; i++) {
    const p0 = p[Math.max(0, i - 1)];
    const p1 = p[i];
    const p2 = p[i + 1];
    const p3 = p[Math.min(p.length - 1, i + 2)];
    const c1 = [p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6];
    const c2 = [p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6];
    d += ` C ${c1[0]} ${c1[1]} ${c2[0]} ${c2[1]} ${p2[0]} ${p2[1]}`;
  }
  return d;
};

export const WALK = catmull(WAYPOINTS);

// An exit route (Act 5): desk slab, then kitchen shelf, then bedside sticker — the three bricks the
// store screenshots are seeded with, walked in order.
export const ROUTE_BRICKS: { at: [number, number]; name: string }[] = [
  { at: BRICK_AT, name: "desk slab" },
  { at: [7.9, 0.5], name: "kitchen shelf" },
  { at: [2.75, 0.45], name: "bedside sticker" },
];
// Through the doorways only: study door, hall, the living-room opening, and back via the bedroom
// door. Straight legs, not a spline: a curve through these overshoots into the walls.
const polyline = (pts: [number, number][]) => pts.map(([x, y], i) => `${i ? "L" : "M"} ${m(x)} ${m(y)}`).join(" ");
export const ROUTE = polyline([
  [1.72, 5.62],
  [2.6, 4.3],
  [3.6, 3.45],
  [4.6, 3.9],
  [5.8, 4.0],
  [7.0, 3.3],
  [7.9, 0.95],
  [7.2, 2.9],
  [5.8, 3.75],
  [4.4, 3.4],
  [3.92, 2.6],
  [3.4, 1.6],
  [2.8, 0.85],
]);
export const WALK_LENGTH_PX = getLength(WALK);
export const WALK_LENGTH_M = WALK_LENGTH_PX / PX_PER_M;

const Line: React.FC<{ d: string; draw: number; w: number; color?: string }> = ({ d, draw, w, color = C.inkOnPaper }) => {
  const e = evolvePath(Math.max(0.0001, draw), d);
  return (
    <path d={d} fill="none" stroke={color} strokeWidth={w} strokeLinecap="square" strokeDasharray={e.strokeDasharray} strokeDashoffset={e.strokeDashoffset} />
  );
};

export const FloorPlan: React.FC<{
  draw: number; // 0…1 walls, then furniture, draw themselves in
  walk: number; // 0…1 how far along the walk the phone is
  trail: number; // 0…1 how much of the dotted path is shown behind it
  phone: number; // 0…1 phone glyph visibility
  light?: number; // 0…1 window light position across the day (Act 3)
  back?: boolean; // walking the path in reverse (Act 4): the phone faces the way it's going
  route?: number; // 0…1 the exit route drawn from brick 1 to 3 (Act 5); undefined = no route
}> = ({ draw, walk, trail, phone, light, back = false, route }) => {
  const walls = useMemo(() => WALLS.map(([x1, y1, x2, y2]) => `M ${m(x1)} ${m(y1)} L ${m(x2)} ${m(y2)}`), []);
  const at = Math.max(0, Math.min(1, walk)) * WALK_LENGTH_PX;
  const pt = getPointAtLength(WALK, at) ?? { x: 0, y: 0 };
  const tan = getTangentAtLength(WALK, Math.min(WALK_LENGTH_PX - 0.01, Math.max(0.01, at))) ?? { x: 0, y: 1 };
  const heading = (Math.atan2(tan.y, tan.x) * 180) / Math.PI + 90 + (back ? 180 : 0);
  const furn = Math.max(0, (draw - 0.45) / 0.55);
  const trailE = evolvePath(Math.max(0.0001, Math.min(trail, walk)), WALK);

  return (
    <svg width={PLAN_W + 40} height={PLAN_H + 40} viewBox={`-20 -20 ${PLAN_W + 40} ${PLAN_H + 40}`} style={{ overflow: "visible" }}>
      {light !== undefined ? (
        // Low sun through the living-room windows: a pale parallelogram that swings across the
        // floor as the session's hour passes.
        <polygon
          points={[
            [m(6.5), 0],
            [m(9.3), 0],
            [m(9.3) - light * m(3.2) + m(1.4), m(3.2)],
            [m(6.5) - light * m(3.2) + m(1.4), m(3.2)],
          ]
            .map((p) => p.join(","))
            .join(" ")}
          fill={C.paperEdge}
          opacity={0.55}
        />
      ) : null}
      {walls.map((d, i) => (
        <Line key={i} d={d} draw={Math.min(1, Math.max(0, draw * 1.8 - i * 0.03))} w={i < 5 ? 7 : 4.5} />
      ))}
      {WINDOWS.map(([x1, y1, x2, y2], i) => {
        const horiz = y1 === y2;
        const o = 4;
        return (
          <g key={i} opacity={furn}>
            <line x1={m(x1)} y1={m(y1)} x2={m(x2)} y2={m(y2)} stroke={C.paper} strokeWidth={9} />
            {[-o, 0, o].map((k) => (
              <line key={k} x1={m(x1) + (horiz ? 0 : k)} y1={m(y1) + (horiz ? k : 0)} x2={m(x2) + (horiz ? 0 : k)} y2={m(y2) + (horiz ? k : 0)} stroke={C.inkOnPaper} strokeWidth={1.2} />
            ))}
          </g>
        );
      })}
      {DOORS.map((d, i) => {
        const x0 = m(d.x) + Math.cos(d.a0) * m(d.r);
        const y0 = m(d.y) + Math.sin(d.a0) * m(d.r);
        const x1 = m(d.x) + Math.cos(d.a1) * m(d.r);
        const y1 = m(d.y) + Math.sin(d.a1) * m(d.r);
        return (
          <g key={i} opacity={furn}>
            <path d={`M ${x0} ${y0} A ${m(d.r)} ${m(d.r)} 0 0 1 ${x1} ${y1}`} fill="none" stroke={C.ashOnPaper} strokeWidth={1.2} strokeDasharray="3 5" />
            <line x1={m(d.x)} y1={m(d.y)} x2={x1} y2={y1} stroke={C.inkOnPaper} strokeWidth={2} />
          </g>
        );
      })}
      {RECTS.map(([x, y, w, h], i) => (
        <Line key={i} d={`M ${m(x)} ${m(y)} h ${m(w)} v ${m(h)} h ${-m(w)} Z`} draw={Math.min(1, Math.max(0, furn * 1.6 - i * 0.05))} w={1.6} />
      ))}
      {CIRCLES.map(([x, y, r], i) => (
        <circle key={i} cx={m(x)} cy={m(y)} r={m(r)} fill="none" stroke={C.inkOnPaper} strokeWidth={1.6} opacity={furn} />
      ))}
      {LABELS.map(([t, x, y]) => (
        <foreignObject key={t} x={m(x) - 120} y={m(y) - 14} width={240} height={30} opacity={furn}>
          <div style={{ ...engraved(C.ashOnPaper, 19), textAlign: "center" }}>{t}</div>
        </foreignObject>
      ))}

      {/* the trail: where the phone has been */}
      <path d={WALK} fill="none" stroke={C.inkOnPaper} strokeWidth={2.4} strokeLinecap="round" strokeDasharray="0.1 11" opacity={0.75} style={{ strokeDashoffset: 0 }} mask="url(#trailmask)" />
      <mask id="trailmask">
        <path d={WALK} fill="none" stroke="#fff" strokeWidth={10} strokeDasharray={trailE.strokeDasharray} strokeDashoffset={trailE.strokeDashoffset} />
      </mask>

      {/* the brick: a square with its ring, like the app draws it */}
      <g transform={`translate(${m(BRICK_AT[0])} ${m(BRICK_AT[1])})`} opacity={Math.min(1, draw * 3)}>
        <rect x={-15} y={-15} width={30} height={30} rx={7} fill={C.inkOnPaper} />
        <circle r={6} fill="none" stroke={C.ash} strokeWidth={1.6} />
      </g>

      {route !== undefined ? (
        <g>
          {(() => {
            const e = evolvePath(Math.max(0.0001, route), ROUTE);
            return <path d={ROUTE} fill="none" stroke={C.inkOnPaper} strokeWidth={2.2} strokeLinecap="round" strokeLinejoin="round" strokeDasharray={e.strokeDasharray} strokeDashoffset={e.strokeDashoffset} />;
          })()}
          {ROUTE_BRICKS.map((b, i) => {
            const lit = route >= [0, 0.47, 0.995][i];
            return (
              <g key={b.name} transform={`translate(${m(b.at[0])} ${m(b.at[1])})`}>
                <rect x={-15} y={-15} width={30} height={30} rx={7} fill={C.inkOnPaper} />
                <circle cx={22} cy={-22} r={15} fill={lit ? C.inkOnPaper : C.paper} stroke={C.inkOnPaper} strokeWidth={2} />
                <text x={22} y={-16.5} textAnchor="middle" fontFamily="system-ui" fontWeight={600} fontSize={16} fill={lit ? C.paper : C.inkOnPaper}>
                  {i + 1}
                </text>
              </g>
            );
          })}
        </g>
      ) : null}

      {/* the phone */}
      <g transform={`translate(${pt.x} ${pt.y}) rotate(${heading})`} opacity={phone}>
        <rect x={-10} y={-20} width={20} height={40} rx={5} fill={C.paper} stroke={C.inkOnPaper} strokeWidth={3} />
        <rect x={-4} y={-16} width={8} height={2.4} rx={1.2} fill={C.inkOnPaper} />
      </g>
    </svg>
  );
};

/** Straight-line-free distance: how far along the walk, in metres, a 0…1 walk progress is. */
export const walkedMetres = (walk: number) => Math.max(0, Math.min(1, walk)) * WALK_LENGTH_M;
