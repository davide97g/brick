// Every cut and tap is a function of the song, never a hand-typed frame number.
//
// data/edit.json is written by analysis/edit.py: the 1:30 cut of song/piano-motif.mp3, with the
// tracked beat grid (shifted onto the kick attacks), drum onsets and envelopes re-timed into
// trailer time. Suno tempo drifts, so beat times come from the tracked grid, never bpm × index.
import edit from "../../data/edit.json";

export const FPS = 60;

export type AudioMap = {
  duration: number;
  bpm: number;
  beats: number[];
  downbeats: number[];
  sections: { name: string; start: number; end: number }[];
  fps: number;
  onsets: { kick: [number, number][]; snare: [number, number][]; hat: [number, number][] };
  rms: number[];
  low: number[];
  drums: number[];
  bass: number[];
  other: number[];
};

export const audio = edit as unknown as AudioMap;

export const sec = (s: number) => Math.round(s * FPS);

/** Frame of bar k's downbeat (bar 0 = first downbeat). */
export const bar = (k: number) => sec(audio.downbeats[Math.min(k, audio.downbeats.length - 1)]);

/** Frame of beat i. */
export const beat = (i: number) => sec(audio.beats[Math.min(i, audio.beats.length - 1)]);

export const section = (name: string) => {
  const s = audio.sections.find((x) => x.name === name);
  if (!s) throw new Error(`no section ${name}`);
  return { from: sec(s.start), durationInFrames: sec(s.end) - sec(s.start) };
};

export const totalFrames = sec(audio.duration);

/** Envelope value (0…1) at a video frame, e.g. env("low", frame) for a bass-reactive pulse. */
export const env = (name: "rms" | "low" | "drums" | "bass" | "other", frame: number) =>
  audio[name][Math.min(audio[name].length - 1, Math.max(0, Math.round((frame / FPS) * audio.fps)))] ?? 0;

/** Frame at a fractional beat index (beatf(8.5) = halfway between beats 8 and 9). */
export const beatf = (x: number) => {
  const i = Math.floor(x);
  const a = audio.beats[Math.min(i, audio.beats.length - 1)];
  const b = audio.beats[Math.min(i + 1, audio.beats.length - 1)];
  return (a + (b - a) * (x - i)) * FPS;
};

/** Frame at bar k plus a fractional number of beats. */
export const barf = (k: number, beats = 0) => {
  const i = audio.beats.findIndex((t) => Math.abs(t - audio.downbeats[k]) < 0.02);
  return beatf(i + beats);
};
