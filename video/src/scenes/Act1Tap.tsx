import React, { useLayoutEffect } from "react";
import { AbsoluteFill, useCurrentFrame, useVideoConfig } from "remotion";
import { ThreeCanvas } from "@remotion/three";
import { useThree } from "@react-three/fiber";
import * as THREE from "three";
import { Brick3D, useTagGeometry } from "../components/Brick3D";
import { Phone3D } from "../components/Phone3D";
import { PhoneFront } from "../components/PhoneFront";
import { AppScreen } from "../components/AppScreen";
import { C, MONO, SANS } from "../lib/theme";
import { ease, lerp, prog } from "../lib/motion";
import { barf, FPS, section } from "../lib/timeline";

// Bars 4–10. The brick on paper, alone, for three bars. The phone arrives during bar 7 and touches
// on the downbeat of bar 8, the song's first kick. Rings leave the tag. Two beats later: the app's
// own screen, already running — "Instant to enter."

// The session the film follows: Deep work, started 20:10, 90 minutes, a 45-minute minimum. The
// shield in Act 2 is at 20:24; the gate opens at 20:55, on the drop.
export const SESSION_S = 90 * 60;
export const MINIMUM_S = 45 * 60;

export const hms = (s: number) => {
  const t = Math.max(0, Math.ceil(s));
  const h = Math.floor(t / 3600);
  const m = Math.floor((t % 3600) / 60);
  const x = t % 60;
  return `${h}:${String(m).padStart(2, "0")}:${String(x).padStart(2, "0")}`;
};

const Rig: React.FC<{ f: number; tap: number; hero: boolean }> = ({ f, tap, hero }) => {
  const { camera, invalidate } = useThree();
  // Three bars alone with the object: a slow rise and a turn round it. Then, as the phone comes,
  // the camera backs off so both fit — the phone is the bigger thing, the brick the subject.
  const orbit = hero ? prog(f, barf(4), barf(7), ease.inOut) : 1;
  const back = hero ? prog(f, barf(6, 2), tap, ease.inOut) : 1;
  const ang = lerp(-0.5, -0.12, orbit);
  const dist = lerp(lerp(190, 165, orbit), 300, back);
  const h = lerp(lerp(70, 95, orbit), 210, back);
  const look: [number, number, number] = [lerp(0, 34, back), lerp(0, 9, back), lerp(4, 0, back)];
  const jolt = f >= tap ? Math.exp(-(f - tap) / 5) * 1.6 : 0;
  // A layout effect, not the render body: R3F otherwise draws the frame before the camera turns.
  useLayoutEffect(() => {
    camera.up.set(0, 0, 1);
    camera.position.set(Math.sin(ang) * dist, -Math.cos(ang) * dist, h - jolt);
    camera.lookAt(...look);
    camera.updateMatrixWorld();
    invalidate();
  });
  return null;
};

const Rings: React.FC<{ f: number; tap: number; beat: number }> = ({ f, tap, beat }) => (
  <>
    {[0, 0.5, 1].map((d, i) => {
      const s = tap + d * beat;
      if (f < s) return null;
      const p = prog(f, s, s + beat * 2.2, ease.out);
      const r = lerp(22, 92, p);
      return (
        <mesh key={i} position={[0, 0, 0.05]}>
          <ringGeometry args={[r, r + lerp(0.9, 0.25, p), 160]} />
          <meshBasicMaterial color={C.inkOnPaper} transparent opacity={(1 - p) * 0.55} />
        </mesh>
      );
    })}
  </>
);

/** The tag on paper and a phone tapping it on the downbeat of `tapBar`. Act 1 and Act 4 both. */
export const Table: React.FC<{ f: number; tapBar: number; hero: boolean }> = ({ f, tapBar, hero }) => {
  const { width, height } = useVideoConfig();
  const geo = useTagGeometry();
  const tap = barf(tapBar);
  const beat = barf(tapBar, 1) - barf(tapBar);
  // Glide in and hover for most of bar 7, then drop the last 20 mm in half a beat, accelerating,
  // so contact lands on the kick instead of drifting into it.
  const arrive = prog(f, barf(tapBar, -4), barf(tapBar, -0.75), ease.out);
  const drop = prog(f, barf(tapBar, -0.5), tap, ease.in);
  const lift = prog(f, barf(tapBar, 1.25), barf(tapBar, 2), ease.in);
  // Contact: the phone comes in from the right, its top end (the antenna) over the tag's right
  // half and 2 mm above the raised letters, the body tilted up the way a hand holds it.
  const contact: [number, number, number] = [6, 2, 13];
  const pos: [number, number, number] = [
    lerp(230, contact[0], arrive),
    lerp(60, contact[1], arrive),
    lerp(140, contact[2] + 20, arrive) - drop * 20 + lift * 24,
  ];
  return (
    <ThreeCanvas
      width={width}
      height={height}
      shadows="soft"
      camera={{ position: [0, -128, 92], fov: 26, near: 1, far: 2000 }}
      gl={{ toneMapping: THREE.AgXToneMapping, toneMappingExposure: 1.35, antialias: true }}
    >
      <Rig f={f} tap={tap} hero={hero} />
      <color attach="background" args={[C.paper]} />
      <hemisphereLight args={[C.chalk, C.paperEdge, 1.1]} />
      <directionalLight
        position={[-60, 20, 28]}
        intensity={3.2}
        castShadow
        shadow-mapSize={[4096, 4096]}
        shadow-camera-left={-120}
        shadow-camera-right={120}
        shadow-camera-top={120}
        shadow-camera-bottom={-120}
        shadow-bias={-0.0004}
        shadow-radius={6}
      />
      <directionalLight position={[40, -30, 50]} intensity={0.35} />
      <mesh receiveShadow>
        <planeGeometry args={[1200, 1200]} />
        <shadowMaterial opacity={0.22} />
      </mesh>
      {geo ? <Brick3D geometry={geo} color="#1B1B1E" position={[0, 0, 5.4]} /> : null}
      <Rings f={f} tap={tap} beat={beat} />
      {f >= barf(tapBar, -4) - 1 ? <Phone3D position={pos} tilt={lerp(0.75, 0.26, arrive) + lift * 0.2} yaw={lerp(-1.25, -1.5, arrive)} /> : null}
    </ThreeCanvas>
  );
};

export const Act1Tap: React.FC = () => {
  const f = useCurrentFrame() + section("tap").from; // absolute frame: every cue is a song bar
  const tap = barf(8);
  const cut = barf(8, 2);
  const spec = prog(f, barf(5), barf(5, 2), ease.out) * (1 - prog(f, barf(7), barf(7, 1), ease.in));

  if (f < cut) {
    return (
      <AbsoluteFill style={{ backgroundColor: C.paper }}>
        <Table f={f} tapBar={8} hero />
        <div style={{ position: "absolute", left: 120, bottom: 100, fontFamily: MONO, fontSize: 30, letterSpacing: 1, color: C.ashOnPaper, opacity: spec }}>
          42 × 42 × 10.8 mm · PLA · NTAG215 inside
        </div>
      </AbsoluteFill>
    );
  }

  const elapsed = Math.max(0, (f - tap) / FPS);
  const run = prog(f, cut, cut + 16, ease.out);
  const sweep = prog(f, cut + 6, barf(9, 2), ease.out);
  const line = prog(f, barf(9), barf(9, 1), ease.out);
  return (
    <AbsoluteFill style={{ backgroundColor: C.ink, flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 150 }}>
      <PhoneFront scale={0.98}>
        <AppScreen
          scale={0.98}
          run={run}
          sweep={sweep}
          progress={elapsed / SESSION_S}
          gate={MINIMUM_S / SESSION_S}
          remaining={hms(SESSION_S - elapsed)}
          until="until 21:40"
          opensAt="20:55"
          where="desk slab, on your desk."
        />
      </PhoneFront>
      <div
        style={{
          width: 760,
          fontFamily: SANS,
          fontWeight: 300,
          fontSize: 92,
          lineHeight: 1.08,
          letterSpacing: -2.2,
          color: C.chalk,
          opacity: line,
          translate: `0px ${(1 - line) * 18}px`,
        }}
      >
        Instant to enter.
      </div>
    </AbsoluteFill>
  );
};
