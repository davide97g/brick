# Covers

An NFC sticker is a beige circle with a barcode on it. These are the shells
that make one an object you would leave on a shelf on purpose.

`buriko-tag.scad` is the one that has been printed, four times. `brick-cover.scad`
is a family of three that has been rendered and sliced but **never printed** —
treat its dimensions as untested.

## Ready to print

`models/` holds the tag as files, for anyone who wants to print one without
OpenSCAD. Each `.3mf` is a Bambu Studio project for the A1 mini with the print
pause already placed — open it with **File → Open Project**, not Import.

| File | Size | What it is |
|---|---|---|
| `buriko-tag` | 42 × 42 × 10.8 mm | The current tag. The one to print. |
| `buriko-tag-110` | 46.2 × 46.2 × 11.8 mm | The same model at `scale_pct=110`. Too big in the hand, kept for anyone whose hands disagree. |
| `buriko_nfc_tag` | 42 × 42 × 10.8 mm | The first pass, before the fixes under *What each print taught*. Kept for the record; don't print it. |

`buriko-tag-110` was regenerated from the current `buriko-tag.scad` with
`./slice.sh 110`, so it carries the widened strokes and the engraved back. The
110% tag that came off the printer was an earlier revision of the model, not
this exact file.

Anything else — another size, another printer — comes from `slice.sh`.

## The tag

`buriko-tag.scad` — 42 × 42 × 10.8 mm. BURIKO stands 0.8 mm proud of the face
you tap, the hexagon mark is cut 0.6 mm into the back, and an NFC sticker is
**sealed inside**: it goes in at a print pause 2 mm under the front and the
printer closes over it. The finished object has no opening anywhere.

```sh
./slice.sh            # 42 mm
./slice.sh 110        # and at another size
```

`scale_pct` scales the body and both marks; the sticker does not scale, so the
pocket stays sized for a 25 mm NTAG whatever the brick measures. The run leaves
`out/buriko-tag.3mf` — a Bambu Studio *project* with the model on the plate, the
pause already placed and the gcode inside. Open it with **File → Open Project**;
Import drops the pause.

### Why one face is raised and the other is cut in

Only the face pointing away from the plate can carry anything raised. A mark
standing off the underside would touch the plate on its own and leave the whole
body hanging over it, which needs support under the entire part. So the front is
proud and the back is engraved — and the back gets the better surface of the two
for it, since the face against the plate comes out smoother than anything printed
in air. Swapping which one is raised means turning the part over, not editing the
model.

### Printing it

1. Start it. Lettering is up; the part prints as exported, no supports.
2. It stops on its own at **z = 8.0 mm** (after layer 40), with a 26.5 mm well
   open in the top. `M400 U1` does that.
3. Drop the sticker in, adhesive down, and press it flat onto the floor of the
   well. Sticking it matters: a loose tag can be dragged by the seal layer.
4. Resume. The next layer bridges across and seals it, 0.8 mm above the top of
   the tag. Nothing after the pause comes near it again.

### Stroke width is the rule

A raised mark prints hollow when its strokes are narrower than two extrusions —
the perimeters touch and there is nothing left to fill, so the top comes out
porous. That is what the first raised print looked like, and no amount of relief
height fixes it. An engraved groove is held to the same floor for the same
reason: under two extrusions it is a seam, not a groove. The numbers, measured
off the outlines with `stroke.py`:

| Mark | Thinnest tenth | Median | |
|---|---|---|---|
| Liberation Sans Bold 6.0 — *the porous print* | 0.70 mm | 1.25 mm | under two extrusions |
| BURIKO — Helvetica Neue Condensed Bold 8.0, fattened 0.15 | 1.05 mm | 1.95 mm | |
| Hexagon mark, 1.8 mm stroke | 1.65 mm | 1.90 mm | |

Condensed is what lets a wide stroke fit "BURIKO" across a 42 mm face at all;
the fatten buys the rest. The drawn logo has a 4.5% stroke, which would be
1.35 mm at this size — so the mark here is deliberately heavier than the
artwork, because the artwork does not have to survive a nozzle.

### What each print taught

| Fault | Fix |
|---|---|
| The pocket was 0.4 mm tall and the pause sat at its **floor**, so the very next layer printed straight over the sticker. | The pocket is 1.0 mm and the pause sits at its **ceiling**. The well is fully walled before the stop, and the first layer after it is the seal, 0.8 mm clear. |
| Raised lettering came out porous on top. | Strokes widened until the slicer fills them. See above. |
| Cutting the letters in fixed the porosity but lost the feel. | Proud again, on the terms that make proud work. |
| 110% was too big in the hand. | Back to 42 mm. |

### What slice.sh proves before you print

Every check exists because the thing it checks for went wrong on a real print,
and each one has been shown to fail on the geometry that failed:

- `stroke.py` measures both marks and refuses a stroke under two extrusions, or
  a median under three and a half. It rejects the old lettering.
- The last layer before the pause lays nothing across the pocket, so there is a
  well to drop the sticker into.
- The first layer after the pause clears the top of the sticker.
- The wordmark reaches the layers above the front face, and the logo leaves a
  hole in the first layer. With `engrave = 0` that hole is 0 mm²; with the logo
  it is 96 mm², and rasterising the first layer draws the hexagon.

Two things about the pause are not adjustable by taste:

- Bambu fires a pause *before* the layer it is pinned to, so the pin goes one
  layer **above** the pocket ceiling. Pinned at the ceiling it would stop with
  the last ring layer still missing.
- `--load-settings` does not carry `machine_pause_gcode` through, so `slice.sh`
  writes it into the project. Without it the slicer emits the marker comment
  and no `M400`, and the printer sails past the pause and seals an empty pocket.

Sliced on an A1 mini, 0.4 nozzle, 0.20 mm Standard: 54 layers, about an hour, no
supports, one pause. **The pocket and the pause are verified on the printer** —
a tag came off with the sticker sealed in and reading. The widened strokes, the
hexagon mark and the engraved back are **unverified**; they have been sliced,
not printed.

No magnets. `~/Downloads/buriko_nfc_tag_magnets.stl` exists from the first pass
and is abandoned: metal near the coil detunes the antenna, and its pockets sat
1 mm from the tag.

## The cover family

`brick-cover.scad` builds three from the same body:

| Part | Size | For |
|---|---|---|
| `slab` | 62 × 38.5 mm | The brick as the app draws it. The one on the desk. |
| `puck` | ~30 mm round | The smallest thing that hides a sticker. Stations. |
| `coaster` | 92 × 92 × 6 mm | Wide enough to put a mug on it. |

```sh
openscad -D 'part="slab"' -o slab.stl brick-cover.scad
```

## Printing the cover family

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
   (The tag is different: its sticker is sealed in mid-print. See above.)
2. Cover the opening with a disc of card or a felt pad, or leave it open. It
   faces the shelf either way.
3. Pair it in the app, name it after where it lives, and leave it there.

## What the app expects

Nothing. The app pairs on the tag's factory UID, which cannot be rewritten, so
any NTAG-family sticker works and no cover is special. A tag someone else has
already paired can be joined from **Bricks → Join a shared brick**, which reads
the UID and writes nothing.
