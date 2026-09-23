#!/bin/sh
# Render the tag, slice it for the A1 mini, and place the print pause.
#
#   ./slice.sh          # 42 mm
#   ./slice.sh 110      # and at another size
#
# Leaves out/buriko-tag.3mf — a Bambu Studio *project* with the model on the
# plate, the pause already pinned to the right layer and the gcode inside. Open
# it with File → Open Project, not Import, or the pause is dropped.
#
# Nothing here is trusted to be right by construction. Every check below exists
# because the thing it checks for went wrong on a real print:
#
#   - both marks are wide enough that the slicer fills them, rather than laying
#     two perimeters that touch and leaving the top porous,
#   - the pocket is still open when the printer stops,
#   - the layer printed after the stop clears the top of the sticker,
#   - the wordmark survived onto the front and the logo was cut into the back.
#
# If a check fails, do not print the result.

set -e
cd "$(dirname "$0")"

SCALE=${1:-100}
BS=/Applications/BambuStudio.app/Contents/MacOS/BambuStudio
P=/Applications/BambuStudio.app/Contents/Resources/profiles/BBL
OUT=$PWD/out

mkdir -p "$OUT"
openscad -D "scale_pct=$SCALE" -o "$OUT/buriko-tag.stl" buriko-tag.scad 2>"$OUT/render.log"
grep ECHO "$OUT/render.log" | sed 's/^ECHO: "//; s/"$//'

key() { sed -n "s/.*$1=\([0-9.]*\).*/\1/p" "$OUT/render.log"; }
PAUSE_Z=$(key PAUSE_TOP_Z)
TAG_TOP_Z=$(key TAG_TOP_Z)
TAG_R=$(key TAG_R)
RELIEF_Z=$(key RELIEF_Z)
ENGRAVE_Z=$(key ENGRAVE_Z)
BODY_W=$(key BODY_W)
LINE_W=$(key LINE_W)
for v in "$PAUSE_Z" "$TAG_TOP_Z" "$TAG_R" "$RELIEF_Z" "$ENGRAVE_Z" "$BODY_W" "$LINE_W"; do
    [ -n "$v" ] || { echo "the render did not report the keys slice.sh needs" >&2; exit 1; }
done

# Refuse a mark that cannot print, before spending an hour finding out. The
# engraved one is measured on the same terms as the raised one: a groove
# narrower than two extrusions is not a groove, it is a seam.
for MARK in word logo; do
    openscad -D "scale_pct=$SCALE" -D "emit=\"$MARK\"" \
        -o "$OUT/$MARK.svg" buriko-tag.scad 2>/dev/null
    python3 stroke.py "$OUT/$MARK.svg" "$MARK" "$LINE_W"
done

# Pass 1: get the model onto a plate with the A1 mini presets.
"$BS" \
  --load-settings "$P/machine/Bambu Lab A1 mini 0.4 nozzle.json;$P/process/0.20mm Standard @BBL A1M.json" \
  --load-filaments "$P/filament/Bambu PLA Basic @BBL A1M.json" \
  --slice 0 --arrange 1 \
  --outputdir "$OUT" --export-3mf stage.3mf \
  "$OUT/buriko-tag.stl" >/dev/null 2>&1

# Pin the pause. machine_pause_gcode goes in here too: --load-settings does not
# carry it through, and without it the slicer writes the marker comment and no
# M400, so the printer sails past and seals an empty pocket.
python3 - "$OUT/stage.3mf" "$OUT/paused.3mf" "$PAUSE_Z" <<'PY'
import json, sys, zipfile

src, dst, z = sys.argv[1], sys.argv[2], sys.argv[3]
xml = ('<?xml version="1.0" encoding="utf-8"?>\n'
       '<custom_gcodes_per_layer>\n<plate>\n<plate_info id="1"/>\n'
       '<layer top_z="%s" type="1" extruder="1" color="" extra="" gcode="M400 U1"/>\n'
       '<mode value="SingleExtruder"/>\n</plate>\n</custom_gcodes_per_layer>' % z)
drop = {'Metadata/plate_1.gcode', 'Metadata/plate_1.gcode.md5',
        'Metadata/custom_gcode_per_layer.xml'}

zin = zipfile.ZipFile(src)
zout = zipfile.ZipFile(dst, 'w', zipfile.ZIP_DEFLATED)
for item in zin.infolist():
    if item.filename in drop:
        continue
    data = zin.read(item.filename)
    if item.filename == 'Metadata/project_settings.config':
        cfg = json.loads(data)
        cfg['machine_pause_gcode'] = 'M400 U1'
        data = json.dumps(cfg, indent=4).encode()
    zout.writestr(item.filename, data)
zout.writestr('Metadata/custom_gcode_per_layer.xml', xml)
zout.close()
PY

# Pass 2: slice again, now with the pause in the project.
"$BS" --slice 0 --outputdir "$OUT" --export-3mf buriko-tag.3mf \
  "$OUT/paused.3mf" >/dev/null 2>&1
rm -f "$OUT/stage.3mf" "$OUT/paused.3mf"

grep -m1 "^; total layer number" "$OUT/plate_1.gcode"
grep -m1 "^; model printing time" "$OUT/plate_1.gcode"

python3 - "$OUT/plate_1.gcode" "$PAUSE_Z" "$TAG_TOP_Z" "$TAG_R" \
          "$RELIEF_Z" "$BODY_W" "$LINE_W" <<'PY'
import math, re, sys

gcode = sys.argv[1]
pause_z, tag_top, tag_r, relief_z, body_w, line_w = (float(a) for a in sys.argv[2:8])

rows = []
z = x = y = None
for line in open(gcode):
    if line.startswith('; Z_HEIGHT:'):
        z = float(line.split(':')[1])
        continue
    if not line.startswith(('G0', 'G1', 'G2', 'G3')):
        continue
    mx, my, me = (re.search(c + r'(-?[\d.]+)', line) for c in 'XYE')
    nx = float(mx.group(1)) if mx else x
    ny = float(my.group(1)) if my else y
    if None not in (x, y, nx, ny) and (mx or my):
        rows.append((z, x, y, nx, ny, bool(me) and float(me.group(1)) > 0))
    x, y = nx, ny

# Where the plate put the part, from the last layer before the pause: the purge
# line the A1 lays at the edge of the plate would drag a whole-print centre off.
last = max(r[0] for r in rows if r[0] < pause_z)
ring = [r for r in rows if r[0] == last and r[5]]
cx = (min(r[1] for r in ring) + max(r[3] for r in ring)) / 2
cy = (min(r[2] for r in ring) + max(r[4] for r in ring)) / 2

def reach(r):
    ax, ay = r[1] - cx, r[2] - cy
    dx, dy = (r[3] - cx) - ax, (r[4] - cy) - ay
    span = dx * dx + dy * dy
    t = 0 if span == 0 else max(0, min(1, -(ax * dx + ay * dy) / span))
    return math.hypot(ax + t * dx, ay + t * dy)

assert 'M400 U1' in open(gcode).read(), \
    'no M400 U1 in the gcode: the printer would never stop'

# 1. The stop has to leave a well to drop the sticker into.
roofed = [r for r in ring if reach(r) < tag_r]
assert not roofed, \
    'the pocket is already roofed at z=%g: nowhere to put the tag' % last

# 2. Everything printed after it has to clear the top of the sticker. The seal
#    is the first layer up, so it is the only one that can foul.
seal = min(r[0] for r in rows if r[0] >= pause_z)
gap = seal - tag_top
assert gap >= 0.3, 'only %.2f mm over the tag at z=%g' % (gap, seal)

# 3. The wordmark stands on the front.
lift = [r for r in rows if r[0] > relief_z + 1e-6 and r[5]]
assert lift, 'nothing is printed above the face: the wordmark is missing'

# 4. The logo is cut into the back — the face on the plate. Rasterise the first
#    layer and look for the hole it leaves. Stroke width is already checked on
#    the outline; this only confirms it reached the gcode.
CELL = 0.3
half = body_w / 2 - 3          # inside the part, clear of the wall and the purge line
n = int(2 * half / CELL)
hit = bytearray(n * n)
for (z0, x0, y0, x1, y1, ext) in rows:
    if z0 != min(r[0] for r in rows) or not ext:
        continue
    steps = max(2, int(math.dist((x0, y0), (x1, y1)) / (CELL / 2)) + 1)
    for k in range(steps + 1):
        px = x0 + (x1 - x0) * k / steps - cx + half
        py = y0 + (y1 - y0) * k / steps - cy + half
        for dx in (-line_w / 2, 0, line_w / 2):
            for dy in (-line_w / 2, 0, line_w / 2):
                i, j = int((px + dx) / CELL), int((py + dy) / CELL)
                if 0 <= i < n and 0 <= j < n:
                    hit[j * n + i] = 1
bare = (n * n - sum(hit)) * CELL * CELL
assert bare > 50, ('only %.0f mm2 of the first layer is left bare: the logo is '
                   'not cut into the back' % bare)

print('; pocket open at z=%g, sealed at z=%g, %.1f mm over the tag'
      % (last, seal, gap))
print('; wordmark stands proud over %d layers above z=%g'
      % (len({r[0] for r in lift}), relief_z))
print('; logo cut into the first layer, %.0f mm2 of it' % bare)
print('; OK')
PY

echo "out/buriko-tag.3mf"
