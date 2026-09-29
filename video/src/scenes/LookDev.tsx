import React from "react";
import { AbsoluteFill, Easing, interpolate, useCurrentFrame, useVideoConfig } from "remotion";
import { ThreeCanvas } from "@remotion/three";
import * as THREE from "three";
import { Brick3D, useTagGeometry } from "../components/Brick3D";
import { Dial } from "../components/Dial";
import { C, SANS, standard } from "../lib/theme";

// Look-development plates: the two hero objects, lit and typeset, to agree on the look before
// any act is built.

export const LookBrick: React.FC = () => {
  const frame = useCurrentFrame();
  const { width, height, durationInFrames } = useVideoConfig();
  const t = interpolate(frame, [0, durationInFrames], [0, 1], { easing: Easing.bezier(0.45, 0, 0.55, 1) });
  const geo = useTagGeometry();
  return (
    <AbsoluteFill style={{ backgroundColor: C.paper }}>
      <ThreeCanvas
        width={width}
        height={height}
        shadows="soft"
        camera={{ position: [0, -118, 96], fov: 24 }}
        gl={{ toneMapping: THREE.AgXToneMapping, toneMappingExposure: 1.35 }}
      >
        <color attach="background" args={[C.paper]} />
        <hemisphereLight args={[C.chalk, C.paperEdge, 1.1]} />
        {/* Raking key from low left, so the raised BURIKO letters throw real shadows. */}
        <directionalLight
          position={[-60, 20, 28]}
          intensity={3.2}
          castShadow
          shadow-mapSize={[4096, 4096]}
          shadow-camera-left={-40}
          shadow-camera-right={40}
          shadow-camera-top={40}
          shadow-camera-bottom={-40}
          shadow-bias={-0.0004}
          shadow-radius={6}
        />
        <directionalLight position={[40, -30, 50]} intensity={0.35} />
        <mesh receiveShadow position={[0, 0, 0]}>
          <planeGeometry args={[600, 600]} />
          {/* Shadow-only floor over the flat paper background: the paper stays the app's exact
              #EDE7DC instead of whatever the lights make of it. */}
          <shadowMaterial opacity={0.22} />
        </mesh>
        <group rotation={[0, 0, interpolate(t, [0, 1], [-0.35, 0.15])]}>
          {geo ? <Brick3D geometry={geo} color="#1B1B1E" position={[0, 0, 5.4]} /> : null}
        </group>
      </ThreeCanvas>
    </AbsoluteFill>
  );
};

export const LookDial: React.FC = () => {
  const frame = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();
  const sweep = interpolate(frame, [0, 45], [0, 1], {
    extrapolateRight: "clamp",
    easing: Easing.bezier(0.16, 1, 0.3, 1),
  });
  const progress = interpolate(frame, [45, durationInFrames], [0.36, 0.42], { extrapolateLeft: "clamp" });
  return (
    <AbsoluteFill style={{ backgroundColor: C.ink, alignItems: "center", justifyContent: "center", gap: 64 }}>
      <Dial
        size={720}
        progress={progress}
        gate={0.5}
        isOpen={false}
        readoutText="1:04:12"
        caption="until 21:40"
        surface={standard}
        sweepIn={sweep}
      />
      <div style={{ fontFamily: SANS, fontWeight: 300, fontSize: 64, letterSpacing: -1.2, color: C.chalk }}>
        Instant to enter. Expensive to leave.
      </div>
    </AbsoluteFill>
  );
};
