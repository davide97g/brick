import React from "react";
import { AbsoluteFill, useCurrentFrame } from "remotion";

// Film grain over everything: flat vector fields at 1080p band and look synthetic without it.
// Seeded by frame, so it moves like grain but renders identically on every worker.
export const Grain: React.FC<{ opacity?: number }> = ({ opacity = 0.06 }) => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill style={{ pointerEvents: "none", mixBlendMode: "overlay", opacity }}>
      <svg width="100%" height="100%">
        <filter id="grain">
          <feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2" seed={frame % 97} stitchTiles="stitch" />
          <feColorMatrix type="saturate" values="0" />
        </filter>
        <rect width="100%" height="100%" filter="url(#grain)" />
      </svg>
    </AbsoluteFill>
  );
};
