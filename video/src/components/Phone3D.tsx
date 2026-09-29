import React, { useMemo } from "react";
import * as THREE from "three";

// A phone reduced to its slab: 71.5 × 149.6 × 8.25 mm (iPhone 17 Pro-ish), rounded corners, soft
// bevel, matte glass back. No camera bump or logo: it's an object in the story, not a product shot.
const W = 71.5;
const H = 149.6;
const D = 8.25;
const R = 12;

export const usePhoneGeometry = () =>
  useMemo(() => {
    const s = new THREE.Shape();
    const x = -W / 2;
    const y = -H / 2;
    s.moveTo(x + R, y);
    s.lineTo(x + W - R, y);
    s.quadraticCurveTo(x + W, y, x + W, y + R);
    s.lineTo(x + W, y + H - R);
    s.quadraticCurveTo(x + W, y + H, x + W - R, y + H);
    s.lineTo(x + R, y + H);
    s.quadraticCurveTo(x, y + H, x, y + H - R);
    s.lineTo(x, y + R);
    s.quadraticCurveTo(x, y, x + R, y);
    const g = new THREE.ExtrudeGeometry(s, {
      depth: D - 2,
      bevelEnabled: true,
      bevelThickness: 1,
      bevelSize: 1,
      bevelSegments: 6,
      curveSegments: 24,
    });
    g.translate(0, 0, -(D - 2) / 2);
    g.computeVertexNormals();
    return g;
  }, []);

export const PHONE = { W, H, D };

/**
 * Pivot is the phone's top edge on its back face — the NFC antenna sits there — so a pose is
 * "where the top of the back touches" plus a tilt, which is how a person actually taps.
 */
export const Phone3D: React.FC<{
  position: [number, number, number];
  tilt: number; // radians the bottom end is raised off the table
  yaw: number;
}> = ({ position, tilt, yaw }) => {
  const geo = usePhoneGeometry();
  const mat = useMemo(
    () => new THREE.MeshPhysicalMaterial({ color: "#1A1A1D", roughness: 0.38, metalness: 0.15, clearcoat: 0.6, clearcoatRoughness: 0.35 }),
    [],
  );
  return (
    <group position={position} rotation={[0, 0, yaw]}>
      <group rotation={[tilt, 0, 0]}>
        {/* top end toward the camera (-y), back face down (-z) */}
        <mesh geometry={geo} material={mat} position={[0, H / 2, D / 2]} castShadow receiveShadow />
      </group>
    </group>
  );
};
