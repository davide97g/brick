// The buriko tag: a solid block with an NFC sticker sealed inside it.
//
// The sticker goes in at a print pause and the printer closes over it, so the
// finished object has no opening anywhere. BURIKO stands proud of the face you
// tap; the hexagon mark is cut into the back.
//
//   ./slice.sh          # ready to print
//
// PRINTED LETTERING UP, and that decides everything else about the two faces.
// Only the face pointing away from the plate can carry anything raised: a mark
// standing off the underside would touch the plate on its own and leave the
// whole body hanging over it. So the wordmark is proud and the logo is engraved
// — and the logo gets the better surface of the two for it, since the face
// against the plate comes out smoother than anything printed in air. Swapping
// which one is raised means turning the part over, not editing this file.
//
// Four prints got it here, and each fixed one thing:
//
//   1. The pocket was 0.4 mm tall with the pause at its *floor*, so the next
//      layer printed straight onto the sticker. Now the pocket is 1.0 mm and
//      the pause sits at its *ceiling*: the well is fully walled before the
//      stop and the first layer after it is the seal, 0.8 mm clear of the tag.
//   2. Raised lettering came out porous on top. See below.
//   3. Cutting the letters in solved the porosity but lost the feel.
//   4. 110% was too big in the hand. Back to 42 mm.
//
// Stroke width is the rule the whole thing turns on, and it is a function of
// the nozzle, not of taste. Anything raised has to be at least two extrusions
// wide everywhere, or the perimeters touch and there is nothing left to fill —
// that is exactly what printed porous. slice.sh measures both marks with
// stroke.py and refuses to slice one that cannot come out solid.

scale_pct = 100;            // 100 = 42 mm, the size that felt right in the hand
emit      = "tag";          // "tag" | "word" | "logo" — the mark names export the
                            // 2D outline alone, which is how slice.sh measures it
layer_h   = 0.2;            // must match the slicer: the pause lands on a layer boundary
line_w    = 0.42;           // the slicer's extrusion width for a 0.4 nozzle

relief  = 0.8;              // how far the wordmark stands off the front: 4 layers
engrave = 0.6;              // how deep the mark is cut into the back: 3 layers

// The wordmark, on the front. Condensed because "BURIKO" has to hold a wide
// stroke inside a 42 mm face, bold because a wide stroke is the entire point.
// Helvetica Neue is macOS-only; Liberation Sans Bold renders anywhere but is
// too wide to do this.
label        = "BURIKO";
text_font    = "Helvetica Neue:style=Condensed Bold";
text_size    = 8.0;         // OpenSCAD sizes text by cap height, not em
text_spacing = 1.05;        // a touch loose, so the gaps between letters stay printable
text_fatten  = 0.15;        // thickens every stroke by twice this. The face alone
                            // gets the median to 1.65 mm; this takes it to 1.95,
                            // and the counters have room to give it up

// The hexagon mark, on the back: the isometric silhouette of a brick, traced
// off the logo. Vertices are the outer hull, normalised to width 1 and centred.
// The drawn mark has a 4.5% stroke, which is 1.35 mm at this size, so the stroke
// here is deliberately heavier than the artwork. The artwork does not have to
// survive a nozzle.
logo_pts = [[-0.5,     0.1934], [-0.0923,  0.3328], [ 0.5,  0.0784],
            [ 0.5,    -0.1934], [ 0.0923, -0.3328], [-0.5, -0.0784]];
logo_w      = 30;           // outer width; 20 mm tall at the traced proportion
logo_stroke = 1.8;
logo_round  = 1.0;          // the joints are rounded in the artwork

// Physical facts, never scaled. The sticker does not grow with the brick.
tag_diameter     = 25;      // NTAG215, the common size
tag_thickness    = 0.4;     // measured generously; the clearance is built off this
pocket_clearance = 0.75;    // radial slack. Kept tight: this is also the bridge span
pocket_h         = 1.0;     // 5 layers: 0.4 of sticker, 0.6 of air under the seal
seal_t           = 2.0;     // plastic over the pocket, up to the face the letters rise from

// The block, at 100%. Add `relief` for the height of the finished object.
base_w  = 42;
base_t  = 10;
base_r  = 9;
base_ch = 0.8;

$fn = 120;

s        = scale_pct / 100;
body_w   = base_w  * s;
body_t   = base_t  * s;
corner_r = base_r  * s;
chamfer  = base_ch * s;

pocket_d = tag_diameter + 2 * pocket_clearance;

// Snapped down to a layer boundary, so the pause has an exact layer to sit on.
// Everything about the seal is measured from here, not from the face.
pocket_top   = floor((body_t - seal_t) / layer_h) * layer_h;
pocket_floor = pocket_top - pocket_h;

module rounded_square(w, t, r) {
    hull() for (x = [-1, 1], y = [-1, 1])
        translate([x * (w / 2 - r), y * (w / 2 - r), 0])
            cylinder(h = t, r = r);
}

// Chamfered top and bottom edges, as the hull of three stacked plates.
module chamfered_body(w, t, r) {
    inset = max(r - chamfer, 0.6);
    hull() {
        rounded_square(w - 2 * chamfer, 0.01, inset);
        translate([0, 0, chamfer])
            rounded_square(w, t - 2 * chamfer, r);
        translate([0, 0, t - 0.01])
            rounded_square(w - 2 * chamfer, 0.01, inset);
    }
}

module wordmark_2d() {
    offset(delta = text_fatten * s)
        text(label, size = text_size * s, font = text_font, spacing = text_spacing,
             halign = "center", valign = "center");
}

// Shrink-then-grow rounds the convex joints without changing the size.
module hexagon_2d(w) {
    offset(r = logo_round) offset(r = -logo_round)
        polygon([for (p = logo_pts) [p[0] * w, p[1] * w]]);
}

module logomark_2d() {
    w = logo_w * s;
    difference() {
        hexagon_2d(w);
        offset(delta = -logo_stroke * s) hexagon_2d(w);
    }
}

module tag() {
    difference() {
        union() {
            chamfered_body(body_w, body_t, corner_r);
            // Proud of the front, and the last thing printed.
            translate([0, 0, body_t - 0.01])
                linear_extrude(height = relief + 0.01) wordmark_2d();
        }

        // The pocket. Sealed in the finished part, open at the pause.
        translate([0, 0, pocket_floor])
            cylinder(h = pocket_h, d = pocket_d);

        // The mark, cut into the back. Mirrored because this face is drawn at
        // z = 0 and read from the other side: turn the tag over left to right
        // and it leans the way the artwork does. Without the mirror it leans
        // the other way, which on an asymmetric mark is the wrong logo.
        translate([0, 0, -0.01])
            linear_extrude(height = engrave + 0.01)
                mirror([1, 0, 0]) logomark_2d();
    }
}

if      (emit == "word") wordmark_2d();
else if (emit == "logo") logomark_2d();
else                     tag();

// slice.sh reads these back out. PAUSE_TOP_Z is one layer above the pocket
// ceiling, because Bambu fires a pause *before* printing the layer it is pinned
// to: pinned at the ceiling it would stop with the last ring layer missing.
echo(str("body   ", body_w, " x ", body_w, " x ", body_t + relief, " mm"));
echo(str("pocket ", pocket_d, " mm dia, z ", pocket_floor, " to ", pocket_top));
echo(str("PAUSE_TOP_Z=", pocket_top + layer_h));
echo(str("TAG_TOP_Z=", pocket_floor + tag_thickness));
echo(str("TAG_R=", tag_diameter / 2));
echo(str("RELIEF_Z=", body_t));
echo(str("ENGRAVE_Z=", engrave));
echo(str("BODY_W=", body_w));
echo(str("LINE_W=", line_w));
