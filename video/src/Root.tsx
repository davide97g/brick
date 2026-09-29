import React from "react";
import { Composition, Folder } from "remotion";
import { LookBrick, LookDial } from "./scenes/LookDev";
import { LookWorld } from "./scenes/LookWorld";
import { Animatic } from "./scenes/Animatic";
import { Trailer } from "./Trailer";
import { FPS, totalFrames } from "./lib/timeline";

export const RemotionRoot: React.FC = () => (
  <>
    <Composition id="Trailer" component={Trailer} durationInFrames={totalFrames} fps={FPS} width={1920} height={1080} />
    <Composition id="Animatic" component={Animatic} durationInFrames={totalFrames} fps={FPS} width={1920} height={1080} />
    <Folder name="LookDev">
      <Composition id="LookBrick" component={LookBrick} durationInFrames={FPS * 4} fps={FPS} width={1920} height={1080} />
      <Composition id="LookDial" component={LookDial} durationInFrames={FPS * 4} fps={FPS} width={1920} height={1080} />
      <Composition id="LookWorld" component={LookWorld} durationInFrames={FPS * 4} fps={FPS} width={1920} height={1080} />
    </Folder>
  </>
);
