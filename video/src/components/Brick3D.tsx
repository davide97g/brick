import React, { useEffect, useMemo, useState } from "react";
import { cancelRender, continueRender, delayRender, staticFile } from "remotion";
import * as THREE from "three";
import { STLLoader } from "three/examples/jsm/loaders/STLLoader.js";

// The printed tag itself (hardware/models/buriko-tag.stl, 42 × 42 × 10.8 mm), not a drawing of
// one: the trailer has no footage of a real brick, so the geometry at least has to be the real one.
//
// Load it in the DOM tree and hand the geometry into the canvas as a prop: a delayRender taken
// inside R3F's reconciler is not seen by the renderer, and the still is taken without the mesh.
export const useTagGeometry = () => {
  const [geo, setGeo] = useState<THREE.BufferGeometry | null>(null);
  const [handle] = useState(() => delayRender("load tag STL"));
  useEffect(() => {
    fetch(staticFile("buriko-tag.stl"))
      .then((r) => r.arrayBuffer())
      .then((buf) => {
        const g = new STLLoader().parse(buf);
        g.computeVertexNormals();
        g.center();
        setGeo(g);
      })
      .catch((e) => cancelRender(e));
  }, []);
  useEffect(() => {
    if (geo) continueRender(handle);
  }, [geo, handle]);
  return geo;
};

export const Brick3D: React.FC<{
  geometry: THREE.BufferGeometry;
  color: string;
  rotation?: [number, number, number];
  position?: [number, number, number];
  scale?: number;
}> = ({ geometry, color, rotation = [0, 0, 0], position = [0, 0, 0], scale = 1 }) => {
  // Matte PLA: high roughness, no metalness, a whisper of clearcoat for the layer-line sheen.
  const mat = useMemo(
    () => new THREE.MeshPhysicalMaterial({ color, roughness: 0.62, metalness: 0, clearcoat: 0.08 }),
    [color],
  );
  return (
    <mesh geometry={geometry} material={mat} rotation={rotation} position={position} scale={scale} castShadow receiveShadow />
  );
};
