import React from "react";
import { AbsoluteFill, Img, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { ThreeCanvas } from "@remotion/three";
import * as THREE from "three";
import { Brick3D, useTagGeometry } from "../components/Brick3D";
import { FloorPlan, PLAN_H, PLAN_W } from "../components/FloorPlan";
import { PhoneFront } from "../components/PhoneFront";
import { Dial } from "../components/Dial";
import { C, MONO, SANS, engraved, readout, reversed } from "../lib/theme";
import { ease, lerp, prog } from "../lib/motion";
import { barf, section, totalFrames } from "../lib/timeline";
import { WORD_PATH, WORD_VIEWBOX } from "../lib/wordmark";

// Bars 32–42. The rest of the drop is four plates, one a bar — everything else the app does, said
// once and fast. Then the song cuts to the piano alone and the film slows down with it: the object,
// "Print it yourself.", and the card.

const Headline: React.FC<{ o: number; color: string; children: React.ReactNode; width?: number; align?: "left" | "center" }> = ({ o, color, children, width = 640, align = "left" }) => (
  <div style={{ width, fontFamily: SANS, fontWeight: 300, fontSize: 88, lineHeight: 1.08, letterSpacing: -2, color, textAlign: align, textWrap: "balance", opacity: o, translate: `0px ${(1 - o) * 18}px` }}>
    {children}
  </div>
);

/** The tag seen from above: the printed object's own face, BURIKO raised on it. */
const TagTop: React.FC<{ size: number }> = ({ size }) => (
  <div
    style={{
      width: size,
      height: size,
      borderRadius: size * 0.2,
      background: "linear-gradient(160deg, #2a2a2d 0%, #151517 70%)",
      boxShadow: `0 ${size * 0.08}px ${size * 0.22}px rgba(0,0,0,0.28), inset 0 0 0 ${size * 0.012}px rgba(255,255,255,0.06)`,
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
    }}
  >
    <svg viewBox={WORD_VIEWBOX} width={size * 0.8} style={{ overflow: "visible", filter: `drop-shadow(${size * 0.006}px ${size * 0.01}px 0 rgba(0,0,0,0.55))` }}>
      <path d={WORD_PATH} fill="#303034" fillRule="evenodd" />
    </svg>
  </div>
);

const Setups: React.FC<{ f: number }> = ({ f }) => {
  const a = prog(f, barf(32), barf(32, 0.6), ease.overshoot);
  const b = prog(f, barf(32, 1), barf(32, 1.6), ease.overshoot);
  const line = prog(f, barf(32), barf(32, 0.5), ease.out);
  const card = (name: string, setup: string, p: number) => (
    <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 26, opacity: Math.min(1, p * 1.5), scale: String(lerp(0.85, 1, p)) }}>
      <TagTop size={220} />
      <div style={engraved(C.ashOnPaper, 24)}>{name}</div>
      <div style={{ fontFamily: SANS, fontSize: 44, fontWeight: 400, color: C.inkOnPaper }}>{setup}</div>
    </div>
  );
  return (
    <AbsoluteFill style={{ backgroundColor: C.paper, alignItems: "center", justifyContent: "center", gap: 80 }}>
      <Headline o={line} color={C.inkOnPaper} width={1400} align="center">
        One setup per brick.
      </Headline>
      <div style={{ display: "flex", gap: 220 }}>
        {card("desk slab", "Deep work · 90 min", a)}
        {card("bedside sticker", "Sleep · reverse", b)}
      </div>
    </AbsoluteFill>
  );
};

const Route: React.FC<{ f: number }> = ({ f }) => {
  const route = prog(f, barf(33), barf(33, 3.2), ease.inOut);
  const line = prog(f, barf(33), barf(33, 0.5), ease.out);
  return (
    <AbsoluteFill style={{ backgroundColor: C.paper, flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 90 }}>
      <div style={{ width: PLAN_W + 40, height: PLAN_H + 40 }}>
        <FloorPlan draw={1} walk={0} trail={0} phone={0} route={route} />
      </div>
      <div style={{ width: 560 }}>
        <Headline o={line} color={C.inkOnPaper} width={560}>
          Or a route: tap them in order.
        </Headline>
      </div>
    </AbsoluteFill>
  );
};

/** Reverse mode, from 04-reverse.png: paper field, ink card, "Standing" → a tap → "Open". */
const Reverse: React.FC<{ f: number }> = ({ f }) => {
  const s = 0.98;
  const open = prog(f, barf(34, 2), barf(34, 2.4), ease.out);
  const line = prog(f, barf(34), barf(34, 0.5), ease.out);
  const sweep = prog(f, barf(34, 2), barf(34, 3.4), ease.out);
  const S = reversed;
  const pill = (label: string, fill: string, color: string) => (
    <div style={{ height: 46 * s, borderRadius: 23 * s, background: fill, display: "flex", alignItems: "center", justifyContent: "center", fontFamily: SANS, fontWeight: 500, fontSize: 16 * s, color }}>{label}</div>
  );
  return (
    <AbsoluteFill style={{ backgroundColor: C.ink, flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 150 }}>
      <PhoneFront scale={s} statusTime="22:39" statusColor={C.inkOnPaper}>
        <div style={{ position: "absolute", inset: 0, background: S.field }}>
          <div style={{ position: "absolute", top: 76 * s, left: 25 * s, ...engraved(S.fieldText, 12 * s), letterSpacing: 3 * s }}>{open > 0.5 ? "Open" : "Standing"}</div>
          <div style={{ position: "absolute", top: 290 * s, width: "100%", display: "flex", flexDirection: "column", alignItems: "center", opacity: 1 - open }}>
            <div style={{ width: 178 * s, height: 110 * s, borderRadius: 40 * s, background: "linear-gradient(180deg, #272729, #141416)", boxShadow: `0 ${14 * s}px ${40 * s}px rgba(0,0,0,0.25)`, display: "flex", alignItems: "center", justifyContent: "center" }}>
              <div style={{ width: 35 * s, height: 35 * s, borderRadius: "50%", border: `${2.2 * s}px solid ${C.ash}` }} />
            </div>
            <div style={{ ...readout(S.fieldText, 44 * s), marginTop: 36 * s }}>Blocked</div>
            <div style={{ ...engraved(S.fieldMuted, 11 * s), marginTop: 12 * s }}>20 apps, 3 categories</div>
          </div>
          <div style={{ position: "absolute", top: (354 - 131) * s, left: (201 - 131) * s, opacity: open }}>
            <Dial size={262 * s} progress={0} gate={null} isOpen readoutText="0:15:00" caption="open until 22:54" surface={S} sweepIn={sweep} />
          </div>
          <div style={{ position: "absolute", top: 640 * s, left: 0, right: 0, bottom: 0, background: S.card, borderTopLeftRadius: 30 * s, borderTopRightRadius: 30 * s }}>
            <div style={{ position: "absolute", inset: `${24 * s}px ${20 * s}px auto`, display: "flex", flexDirection: "column", gap: 12 * s, opacity: 1 - open }}>
              <div style={{ fontFamily: SANS, fontSize: 15 * s, color: S.cardMuted, textAlign: "center" }}>Sleep is standing.</div>
              {pill("Tap your brick for 15m", C.chalk, C.inkOnPaper)}
              <div style={{ ...engraved(S.cardMuted, 11 * s), textAlign: "center" }}>2 openings left today</div>
            </div>
            <div style={{ position: "absolute", inset: `${24 * s}px ${20 * s}px auto`, display: "flex", flexDirection: "column", gap: 12 * s, opacity: open }}>
              <div style={{ fontFamily: SANS, fontSize: 15 * s, color: S.cardMuted, textAlign: "center" }}>It goes back up by itself.</div>
              {pill("Put it back now", C.chalk, C.inkOnPaper)}
            </div>
          </div>
        </div>
      </PhoneFront>
      <Headline o={line} color={C.chalk} width={760}>
        Or blocked by default. A tap buys 15 minutes.
      </Headline>
    </AbsoluteFill>
  );
};

const Privacy: React.FC<{ f: number }> = ({ f }) => {
  const lines = ["No account.", "No analytics.", "Nothing leaves your phone."];
  return (
    <AbsoluteFill style={{ backgroundColor: C.ink, alignItems: "flex-start", justifyContent: "center", paddingLeft: 300, gap: 8 }}>
      {lines.map((l, i) => {
        const o = prog(f, barf(35, i), barf(35, i + 0.5), ease.out);
        return (
          <div key={l} style={{ fontFamily: SANS, fontWeight: 300, fontSize: 110, letterSpacing: -2.6, color: i === 2 ? C.chalk : C.ash, opacity: o, translate: `0px ${(1 - o) * 18}px` }}>
            {l}
          </div>
        );
      })}
    </AbsoluteFill>
  );
};

/** The object alone after the cut to piano, turning slowly: "Print it yourself." */
const Print: React.FC<{ f: number }> = ({ f }) => {
  const { width, height } = useVideoConfig();
  const geo = useTagGeometry();
  const t = prog(f, barf(36), barf(38), ease.linear);
  const line = prog(f, barf(36, 1), barf(36, 2), ease.out);
  return (
    <AbsoluteFill style={{ backgroundColor: C.paper }}>
      <ThreeCanvas width={width} height={height} shadows="soft" camera={{ position: [0, -118, 96], fov: 24 }} gl={{ toneMapping: THREE.AgXToneMapping, toneMappingExposure: 1.35 }}>
        <color attach="background" args={[C.paper]} />
        <hemisphereLight args={[C.chalk, C.paperEdge, 1.1]} />
        <directionalLight position={[-60, 20, 28]} intensity={3.2} castShadow shadow-mapSize={[4096, 4096]} shadow-camera-left={-60} shadow-camera-right={60} shadow-camera-top={60} shadow-camera-bottom={-60} shadow-bias={-0.0004} shadow-radius={6} />
        <directionalLight position={[40, -30, 50]} intensity={0.35} />
        <mesh receiveShadow>
          <planeGeometry args={[800, 800]} />
          <shadowMaterial opacity={0.22} />
        </mesh>
        <group position={[-26, 6, 0]} rotation={[0, 0, lerp(-0.5, 0.25, t)]}>
          {geo ? <Brick3D geometry={geo} color="#1B1B1E" position={[0, 0, 5.4]} /> : null}
        </group>
      </ThreeCanvas>
      <div style={{ position: "absolute", right: 200, top: 0, bottom: 0, display: "flex", flexDirection: "column", justifyContent: "center", gap: 30, opacity: line }}>
        <Headline o={line} color={C.inkOnPaper} width={640}>
          Print it yourself.
        </Headline>
        <div style={{ fontFamily: MONO, fontSize: 28, color: C.ashOnPaper, lineHeight: 1.6 }}>
          42 mm · PLA · one NTAG215 sticker
          <br />
          files and source, public domain
        </div>
      </div>
    </AbsoluteFill>
  );
};

const Card: React.FC<{ f: number }> = ({ f }) => {
  const word = prog(f, barf(38), barf(38, 1.5), ease.out);
  const sub = prog(f, barf(38, 2), barf(38, 3), ease.out);
  const badge = prog(f, barf(39), barf(39, 1), ease.out);
  const out = prog(f, totalFrames - 36, totalFrames - 1, ease.inOut);
  return (
    <AbsoluteFill style={{ backgroundColor: C.paper, alignItems: "center", justifyContent: "center", gap: 44 }}>
      <div style={{ opacity: 1 - out, display: "flex", flexDirection: "column", alignItems: "center", gap: 44 }}>
        <svg viewBox={WORD_VIEWBOX} width={620} style={{ overflow: "visible", opacity: word, translate: `0px ${(1 - word) * 16}px` }}>
          <path d={WORD_PATH} fill={C.inkOnPaper} fillRule="evenodd" />
        </svg>
        <div style={{ fontFamily: SANS, fontWeight: 300, fontSize: 56, letterSpacing: -1, color: C.ashOnPaper, opacity: sub }}>A session you walk away from.</div>
        {/* Apple's own badge artwork, unmodified (toolbox.marketingtools.apple.com), with its clear space */}
        <Img src={staticFile("badge-black.svg")} style={{ height: 96, marginTop: 40, opacity: badge }} />
      </div>
    </AbsoluteFill>
  );
};

export const Act5Card: React.FC = () => {
  const f = useCurrentFrame() + section("card").from;
  if (f < barf(33)) return <Setups f={f} />;
  if (f < barf(34)) return <Route f={f} />;
  if (f < barf(35)) return <Reverse f={f} />;
  if (f < barf(36)) return <Privacy f={f} />;
  if (f < barf(38)) return <Print f={f} />;
  return <Card f={f} />;
};
