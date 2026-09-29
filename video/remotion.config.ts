import { Config } from "@remotion/cli/config";

Config.setRspack(true);
Config.setVideoImageFormat("jpeg");
Config.setJpegQuality(95);
Config.setOverwriteOutput(true);
// WebGL for the R3F scenes: headless Chrome needs ANGLE on macOS or ThreeCanvas renders black.
Config.setChromiumOpenGlRenderer("angle");
