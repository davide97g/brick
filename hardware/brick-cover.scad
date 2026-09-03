// Covers for an NFC sticker, so a tag can sit anywhere and still look like
// part of the product.
//
// Three shapes from one body: the slab is the brick as the app draws it
// (chamfered block, one engraved ring), the puck is the smallest thing that
// hides a 25 mm sticker, and the coaster is wide enough to put a mug on.
//
//   openscad -D 'part="slab"'    -o slab.stl    brick-cover.scad
//   openscad -D 'part="puck"'    -o puck.stl    brick-cover.scad
//   openscad -D 'part="coaster"' -o coaster.stl brick-cover.scad
//
// Printed face down: the engraved face is against the plate, the cavity opens
// upward. Nothing bridges, nothing needs support, and the sticker ends up one
// millimetre from the surface the phone touches.

part = "slab";              // "slab" | "puck" | "coaster"

tag_diameter     = 25;      // NTAG215 sticker, the common size
pocket_clearance = 0.6;     // radial slack so the sticker drops in
face_t           = 1.0;     // material between the sticker and the phone
wall             = 2.6;     // side wall around the cavity

chamfer    = 1.2;
ring_ratio = 0.20;          // engraved ring diameter, as a fraction of the short side
ring_w     = 1.2;
ring_depth = 0.6;

$fn = 96;

// Outside dimensions. The slab keeps the 0.62 aspect the app draws.
slab_w = 62;    slab_h = 38.5;  slab_t = 8;
puck_t = 5;
coaster_w = 92; coaster_h = 92; coaster_t = 6;

pocket_d = tag_diameter + 2 * pocket_clearance;
puck_w   = pocket_d + 2 * wall;

module rounded_slab(w, h, t, r) {
    hull() for (x = [-1, 1], y = [-1, 1])
        translate([x * (w / 2 - r), y * (h / 2 - r), 0])
            cylinder(h = t, r = r);
}

// Chamfered top and bottom edges, as the hull of three stacked plates.
module chamfered_slab(w, h, t, r) {
    inset = max(r - chamfer, 0.6);
    hull() {
        rounded_slab(w - 2 * chamfer, h - 2 * chamfer, 0.01, inset);
        translate([0, 0, chamfer])
            rounded_slab(w, h, t - 2 * chamfer, r);
        translate([0, 0, t - 0.01])
            rounded_slab(w - 2 * chamfer, h - 2 * chamfer, 0.01, inset);
    }
}

// The engraved tap ring, on the face that meets the phone.
module engraved_ring(short_side) {
    d = short_side * ring_ratio * 2;
    translate([0, 0, -0.01])
        difference() {
            cylinder(h = ring_depth + 0.01, d = d + ring_w);
            translate([0, 0, -0.01])
                cylinder(h = ring_depth + 0.03, d = d - ring_w);
        }
}

module cover(w, h, t, r) {
    difference() {
        chamfered_slab(w, h, t, r);
        // Cavity, open at the top: the sticker drops in and sits on the face.
        translate([0, 0, face_t])
            cylinder(h = t, d = pocket_d);
        engraved_ring(min(w, h));
    }
}

if (part == "slab")    cover(slab_w, slab_h, slab_t, 7);
if (part == "puck")    cover(puck_w, puck_w, puck_t, puck_w / 2);
if (part == "coaster") cover(coaster_w, coaster_h, coaster_t, 14);
