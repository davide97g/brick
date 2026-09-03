# Covers

**Unverified.** These are parametric models, not printed objects: no STL has
been rendered and nothing has been off a printer yet.

An NFC sticker is a beige circle with a barcode on it. These are the shells
that make one an object you would leave on a shelf on purpose.

`brick-cover.scad` builds three from the same body:

| Part | Size | For |
|---|---|---|
| `slab` | 62 × 38.5 mm | The brick as the app draws it. The one on the desk. |
| `puck` | ~30 mm round | The smallest thing that hides a sticker. Stations. |
| `coaster` | 92 × 92 × 6 mm | Wide enough to put a mug on it. |

```sh
openscad -D 'part="slab"' -o slab.stl brick-cover.scad
```

## Printing

- Engraved face down on the plate, no supports. The cavity opens upward, so
  nothing bridges and the face the phone touches is a single unbroken surface.
- 0.2 mm layers, 3 perimeters, 15% infill. Nothing here is structural.
- PLA or PETG. **No carbon-fill, no metallic filament, no metal inserts** — a
  conductive layer over the tag detunes the antenna and the phone stops seeing
  it. This is the one material rule that matters.
- The tag sits under `face_t` (1 mm) of plastic. Thicker reads worse; much
  thinner is fragile.

## Assembly

1. Drop the sticker into the cavity, adhesive side down, and press it flat
   against the floor — that floor is the 1 mm face the phone reads through.
2. Cover the opening with a disc of card or a felt pad, or leave it open. It
   faces the shelf either way.
3. Pair it in the app, name it after where it lives, and leave it there.

## What the app expects

Nothing. The app pairs on the tag's factory UID, which cannot be rewritten, so
any NTAG-family sticker works and no cover is special. A tag someone else has
already paired can be joined from **Bricks → Join a shared brick**, which reads
the UID and writes nothing.
