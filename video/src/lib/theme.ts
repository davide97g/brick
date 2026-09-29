// Mirrors Brick/Support/Theme.swift. The trailer is the app's own instrument panel, so it
// uses the app's tokens and nothing else; change them there first, then here.

export const C = {
  ink: "#0B0B0D",
  inkRaised: "#141416",
  paper: "#EDE7DC",
  paperEdge: "#DCD4C6",
  chalk: "#F2F2F0",
  ash: "#9C9CA1",
  graphite: "#3A3A3E",
  chalkline: "#C7BEAE",
  inkOnPaper: "#17171A",
  ashOnPaper: "#6B675F",
  // The only chroma. In the app it appears only where the commitment breaks (the emergency
  // hold); in the trailer it appears exactly once, at that same moment.
  oxide: "#B4614F",
} as const;

export type Surface = {
  field: string;
  fieldText: string;
  fieldMuted: string;
  fieldRecessed: string;
  card: string;
  cardText: string;
  cardMuted: string;
};

export const standard: Surface = {
  field: C.ink,
  fieldText: C.chalk,
  fieldMuted: C.ash,
  fieldRecessed: C.graphite,
  card: C.paper,
  cardText: C.inkOnPaper,
  cardMuted: C.ashOnPaper,
};

// Reverse mode swaps the zones rather than adding a colour.
export const reversed: Surface = {
  field: C.paper,
  fieldText: C.inkOnPaper,
  fieldMuted: C.ashOnPaper,
  fieldRecessed: C.chalkline,
  card: C.ink,
  cardText: C.chalk,
  cardMuted: C.ash,
};

// Headless Chrome on macOS resolves system-ui to SF Pro, the font the app actually ships in.
export const SANS = `system-ui, -apple-system, "SF Pro Display", "Helvetica Neue", sans-serif`;
export const MONO = `ui-monospace, "SF Mono", Menlo, monospace`;

export const engraved = (color: string, size = 30): React.CSSProperties => ({
  fontFamily: SANS,
  fontWeight: 500,
  fontSize: size,
  letterSpacing: size * 0.22,
  textTransform: "uppercase",
  color,
});

export const readout = (color: string, size: number): React.CSSProperties => ({
  fontFamily: SANS,
  fontWeight: 200,
  fontSize: size,
  letterSpacing: -size * 0.02,
  fontVariantNumeric: "tabular-nums",
  color,
});
