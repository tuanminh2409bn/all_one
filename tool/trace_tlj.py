"""Trace the TLJ 40% artwork from mockup/1.jpg into Flutter vector paths."""

import sys
from collections import deque

from PIL import Image, ImageDraw

SRC = 'mockup/1.jpg'
X0, X1, Y0, Y1 = 158, 400, 806, 940
BAND_TOP = 801
SCALE = 4


def classify(p):
    r, g, b = p
    if r > 170 and (g - b) > 35 and g > 82:
        return 'O'
    if r > 188 and (r - g) > 88:
        return 'F'
    if 100 < r <= 188 and (r - g) > 55:
        return 'D'
    if (g - r) > 20 and g > 105:
        return 'G'
    if (b - r) > 20 and b > 145:
        return 'B'
    return '.'


def build_masks(img):
    w, h = img.size
    px = img.load()
    masks = {k: [[False] * w for _ in range(h)] for k in 'OFDGB'}
    for y in range(h):
        for x in range(w):
            k = classify(px[x, y])
            if k != '.':
                masks[k][y][x] = True
    return masks, w, h


def components(mask, w, h, min_area):
    seen = [[False] * w for _ in range(h)]
    out = []
    for sy in range(h):
        for sx in range(w):
            if not mask[sy][sx] or seen[sy][sx]:
                continue
            q = deque([(sx, sy)])
            seen[sy][sx] = True
            cells = []
            while q:
                x, y = q.popleft()
                cells.append((x, y))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and mask[ny][nx] and not seen[ny][nx]:
                        seen[ny][nx] = True
                        q.append((nx, ny))
            if len(cells) >= min_area:
                out.append(cells)
    return out


def cells_to_grid(cells, w, h):
    grid = [[False] * w for _ in range(h)]
    for x, y in cells:
        grid[y][x] = True
    return grid


def trace(grid, w, h):
    """Return closed loops; outer loops clockwise, holes counter-clockwise."""
    edges = {}

    def add(a, b):
        edges.setdefault(a, []).append(b)

    for y in range(h):
        row = grid[y]
        for x in range(w):
            if not row[x]:
                continue
            if y == 0 or not grid[y - 1][x]:
                add((x, y), (x + 1, y))
            if x == w - 1 or not row[x + 1]:
                add((x + 1, y), (x + 1, y + 1))
            if y == h - 1 or not grid[y + 1][x]:
                add((x + 1, y + 1), (x, y + 1))
            if x == 0 or not row[x - 1]:
                add((x, y + 1), (x, y))

    loops = []
    while edges:
        start = next(iter(edges))
        loop = [start]
        cur = start
        while True:
            nxts = edges.get(cur)
            if not nxts:
                break
            nxt = nxts.pop()
            if not nxts:
                del edges[cur]
            loop.append(nxt)
            cur = nxt
            if cur == start:
                break
        if len(loop) > 4:
            loops.append(loop)
    return loops


def collinear_reduce(pts):
    out = []
    n = len(pts)
    for i in range(n - 1):
        p, c, q = pts[i - 1], pts[i], pts[(i + 1) % (n - 1)]
        if (c[0] - p[0]) * (q[1] - c[1]) != (c[1] - p[1]) * (q[0] - c[0]):
            out.append(c)
    return out or pts[:-1]


def dp(pts, eps):
    if len(pts) < 3:
        return pts
    ax, ay = pts[0]
    bx, by = pts[-1]
    dx, dy = bx - ax, by - ay
    norm = (dx * dx + dy * dy) ** 0.5
    best, bi = -1.0, 0
    for i in range(1, len(pts) - 1):
        x, y = pts[i]
        d = (abs(dy * x - dx * y + bx * ay - by * ax) / norm) if norm else (
            ((x - ax) ** 2 + (y - ay) ** 2) ** 0.5)
        if d > best:
            best, bi = d, i
    if best <= eps:
        return [pts[0], pts[-1]]
    return dp(pts[:bi + 1], eps)[:-1] + dp(pts[bi:], eps)


def simplify_loop(loop, eps):
    pts = collinear_reduce(loop)
    if len(pts) < 4:
        return pts
    k = len(pts) // 2
    a = dp(pts[:k + 1], eps)
    b = dp(pts[k:] + [pts[0]], eps)
    return a[:-1] + b[:-1]


def chaikin(pts, iterations=1):
    for _ in range(iterations):
        out = []
        n = len(pts)
        for i in range(n):
            p, q = pts[i], pts[(i + 1) % n]
            out.append((p[0] * 0.75 + q[0] * 0.25, p[1] * 0.75 + q[1] * 0.25))
            out.append((p[0] * 0.25 + q[0] * 0.75, p[1] * 0.25 + q[1] * 0.75))
        pts = out
    return pts


def area(pts):
    s = 0.0
    n = len(pts)
    for i in range(n):
        x1, y1 = pts[i]
        x2, y2 = pts[(i + 1) % n]
        s += x1 * y2 - x2 * y1
    return s / 2


def layer_loops(mask, w, h, min_area, eps, smooth=1, min_loop=None):
    min_loop = min_area if min_loop is None else min_loop
    loops = []
    for cells in components(mask, w, h, min_area):
        grid = cells_to_grid(cells, w, h)
        for loop in trace(grid, w, h):
            pts = simplify_loop(loop, eps)
            if len(pts) < 3:
                continue
            pts = chaikin(pts, smooth)
            if abs(area(pts)) < min_loop:
                continue
            loops.append(pts)
    return loops


def morph(mask, w, h, radius, grow):
    out = [[False] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            hit = False
            for dy in range(-radius, radius + 1):
                for dx in range(-radius, radius + 1):
                    nx, ny = x + dx, y + dy
                    v = mask[ny][nx] if 0 <= nx < w and 0 <= ny < h else False
                    if v == grow:
                        hit = True
                        break
                if hit:
                    break
            out[y][x] = grow if hit else not grow
    return out


def close_open(mask, w, h, radius=2):
    m = morph(mask, w, h, radius, True)
    m = morph(m, w, h, radius, False)
    m = morph(m, w, h, 1, False)
    return morph(m, w, h, 1, True)


def clip(mask, w, h, box):
    x0, y0, x1, y1 = [v * SCALE for v in box]
    return [[mask[y][x] and x0 <= x < x1 and y0 <= y < y1 for x in range(w)]
            for y in range(h)]


def to_design(loops):
    return [[(X0 + x / SCALE, Y0 + y / SCALE - BAND_TOP) for x, y in loop]
            for loop in loops]


def main():
    img = Image.open(SRC).convert('RGB').crop((X0, Y0, X1, Y1))
    img = img.resize(((X1 - X0) * SCALE, (Y1 - Y0) * SCALE), Image.LANCZOS)
    masks, w, h = build_masks(img)

    split = (338 - X0) * SCALE

    def side(mask, left):
        return [[(x < split if left else x >= split) and mask[y][x]
                 for x in range(w)] for y in range(h)]

    front, dark = masks['F'], masks['D']
    big_solid = [[front[y][x] or dark[y][x] for x in range(w)] for y in range(h)]
    front = close_open(front, w, h)
    big_solid = close_open(big_solid, w, h)

    percent = clip(big_solid, w, h, (338 - X0, 863 - Y0, 392 - X0, 908 - Y0))

    layers = {
        'digitsShadow': layer_loops(side(big_solid, True), w, h, 400, 2.6,
                                    smooth=2, min_loop=400),
        'digitsFace': layer_loops(side(front, True), w, h, 400, 2.6,
                                  smooth=2, min_loop=400),
        'percent': layer_loops(percent, w, h, 120, 2.0, smooth=2, min_loop=120),
    }

    preview = Image.new('RGB', (w, h), (243, 245, 245))
    draw = ImageDraw.Draw(preview)
    colors = {
        'digitsShadow': (160, 18, 4), 'digitsFace': (230, 73, 58),
        'percent': (230, 73, 58),
    }
    for name in ('digitsShadow', 'digitsFace', 'percent'):
        if name == 'percent':
            for loop in layers[name]:
                if area(loop) > 0:
                    draw.line(loop + [loop[0]], fill=(255, 255, 255),
                              width=int(2.6 * SCALE), joint='curve')
        for loop in layers[name]:
            fill = colors[name] if area(loop) > 0 else (243, 245, 245)
            draw.polygon(loop, fill=fill)
    preview.save('tlj_traced_preview.png')

    total = sum(len(p) for v in layers.values() for p in v)
    print('total points', total,
          {k: (len(v), sum(len(p) for p in v)) for k, v in layers.items()})

    out = ["// GENERATED by tool/trace_tlj.py from mockup/1.jpg. Do not edit by hand.",
           "// Coordinates use the 588 px design width, relative to the promo band.",
           "const tljArtworkPaths = <String, List<List<double>>>{"]
    for name in layers:
        out.append("  '$name': <List<double>>[".replace('$name', name))
        for loop in to_design(layers[name]):
            flat = ', '.join(f'{v:.2f}' for pt in loop for v in pt)
            out.append(f'    <double>[{flat}],')
        out.append('  ],')
    out.append('};')
    with open('lib/ui/tlj_artwork_paths.dart', 'w') as fh:
        fh.write('\n'.join(out) + '\n')
    print('written lib/ui/tlj_artwork_paths.dart')


if __name__ == '__main__':
    sys.setrecursionlimit(10000)
    main()
