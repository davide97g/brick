import { Easing, interpolate } from "remotion";

// One small vocabulary of curves for the whole film, so every move feels like the same hand.
export const ease = {
  out: Easing.bezier(0.16, 1, 0.3, 1), // arrivals: fast, then settles
  inOut: Easing.bezier(0.65, 0, 0.35, 1), // camera moves
  in: Easing.bezier(0.7, 0, 0.84, 0), // departures
  overshoot: Easing.bezier(0.34, 1.56, 0.64, 1), // icons blooming
  linear: (t: number) => t,
};

/** 0…1 progress of `frame` between frames a and b, clamped, eased. */
export const prog = (frame: number, a: number, b: number, e: (t: number) => number = ease.inOut) =>
  interpolate(frame, [a, b], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: e });

export const lerp = (a: number, b: number, t: number) => a + (b - a) * t;

/** Deterministic per-frame noise in -1…1: never Math.random, or renders flicker between workers. */
export const hash = (n: number) => {
  const x = Math.sin(n * 127.1 + 311.7) * 43758.5453;
  return (x - Math.floor(x)) * 2 - 1;
};
