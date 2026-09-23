"""Local stroke thickness of a 2D outline, straight from OpenSCAD's SVG.

A raised mark prints hollow when its strokes are narrower than two perimeters
plus something between them. The slicer will not say so — it labels two touching
walls "Top surface" just the same — so this measures the mark itself.

    openscad -D 'emit="mark"' -o mark.svg buriko-tag.scad
    python3 stroke.py mark.svg BURIKO 0.42

Thickness at a point is the smaller of its horizontal and vertical run, which
reads a diagonal stroke a little wide and a curve terminal a little narrow. Both
errors are on the same side for every candidate, so it ranks them honestly.
"""
import re, sys

PX = 0.05

def contours(svg):
    out = []
    for d in re.findall(r'<path d="(.*?)"', svg, re.S):
        pts = [(float(a), float(b))
               for a, b in re.findall(r'([-\d.]+),([-\d.]+)', d)]
        if len(pts) > 2:
            out.append(pts)
    return out

def fill(cs):
    xs = [p[0] for c in cs for p in c]
    ys = [p[1] for c in cs for p in c]
    x0, y0 = min(xs) - PX, min(ys) - PX
    W = int((max(xs) - x0) / PX) + 2
    H = int((max(ys) - y0) / PX) + 2
    edges = []
    for c in cs:
        for (ax, ay), (bx, by) in zip(c, c[1:] + c[:1]):
            if ay != by:
                edges.append((ax, ay, bx, by))
    grid = [bytearray(W) for _ in range(H)]
    for j in range(H):
        yc = y0 + (j + 0.5) * PX
        hits = sorted((ax + (yc - ay) * (bx - ax) / (by - ay))
                      for ax, ay, bx, by in edges
                      if (ay <= yc < by) or (by <= yc < ay))
        row = grid[j]
        for k in range(0, len(hits) - 1, 2):
            i0 = max(0, int((hits[k] - x0) / PX))
            i1 = min(W, int((hits[k + 1] - x0) / PX) + 1)
            for i in range(i0, i1):
                row[i] = 1
    return grid, W, H

def runs_along(get, n, m):
    """run length through each filled cell, along one axis"""
    out = [[0] * n for _ in range(m)]
    for a in range(m):
        b = 0
        while b < n:
            if not get(a, b):
                b += 1
                continue
            c = b
            while c < n and get(a, c):
                c += 1
            for k in range(b, c):
                out[a][k] = c - b
            b = c
    return out

def thickness(svg_path):
    grid, W, H = fill(contours(open(svg_path).read()))
    hor = runs_along(lambda j, i: grid[j][i], W, H)
    ver = runs_along(lambda i, j: grid[j][i], H, W)
    t = sorted(min(hor[j][i], ver[i][j]) * PX
               for j in range(H) for i in range(W) if grid[j][i])
    if not t:
        raise SystemExit('nothing in %s' % svg_path)
    q = lambda f: t[int(f * (len(t) - 1))]
    return q(0.10), q(0.50), len(t) * PX * PX

if __name__ == '__main__':
    p10, med, area = thickness(sys.argv[1])
    name = sys.argv[2] if len(sys.argv) > 2 else sys.argv[1]
    print('; %s: stroke p10 %.2f mm, median %.2f mm, area %.0f mm2'
          % (name, p10, med, area))
    if len(sys.argv) > 3:
        line_w = float(sys.argv[3])
        # Two extrusions is the floor: thinner and the perimeters overlap, which
        # is what left the first print porous. Three and a half over most of the
        # area is what it takes for the top to be filled rather than walled.
        assert p10 >= 2 * line_w, (
            'thinnest tenth of the mark is %.2f mm, under two extrusions (%.2f): '
            'it will print hollow' % (p10, 2 * line_w))
        assert med >= 3.5 * line_w, (
            'median stroke %.2f mm is under %.2f mm: too little of the mark can '
            'take infill' % (med, 3.5 * line_w))
