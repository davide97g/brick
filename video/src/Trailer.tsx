import React from "react";
import { AbsoluteFill, Sequence, staticFile } from "remotion";
import { Audio } from "@remotion/media";
import { Act0Reflex } from "./scenes/Act0Reflex";
import { Act1Tap } from "./scenes/Act1Tap";
import { Act2Leave } from "./scenes/Act2Leave";
import { Act3Time } from "./scenes/Act3Time";
import { Act4WalkBack } from "./scenes/Act4WalkBack";
import { Act5Card } from "./scenes/Act5Card";
import { ActCard } from "./scenes/Animatic";
import { Grain } from "./components/Grain";
import { audio, section } from "./lib/timeline";
import { C } from "./lib/theme";

// The film: the cut of the song, and one act per section of it. Acts not yet built fall back to
// their animatic card so the whole thing always plays end to end.
const BUILT: Record<string, React.FC> = { reflex: Act0Reflex, tap: Act1Tap, leave: Act2Leave, time: Act3Time, walkback: Act4WalkBack, card: Act5Card };

export const Trailer: React.FC = () => (
  <AbsoluteFill style={{ backgroundColor: C.ink }}>
    <Audio src={staticFile("trailer.wav")} />
    {audio.sections.map((s) => {
      const Act = BUILT[s.name];
      return (
        <Sequence key={s.name} name={s.name} {...section(s.name)}>
          {Act ? <Act /> : <ActCard name={s.name} />}
        </Sequence>
      );
    })}
    <Grain />
  </AbsoluteFill>
);
