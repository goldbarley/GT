#!/usr/bin/env python3
"""
Cut the modular Knight's sprite sheets into pieces, the same way the Mage's
atlases are cut.

WHY
---
Each sheet holds the knight's pieces spread over a few 32x32 cells and the
finished knight, which is the reference, in one of them.  The pieces were
never cut out, so the rig had nothing to assemble: the side views ended up
with a black placeholder for a body and the front view was never assembled at
all.

HOW
---
1. Every cell of the sheet is a candidate reference.
2. Each connected blob of pixels in the other cells is a candidate piece.
3. A piece is placed by sliding it over the reference and keeping the place
   where its colours agree with the reference, which is the same oracle the
   Mage's repack uses.
4. The reference is whichever cell the pieces assemble into best.
5. The pieces are cut to their own pixels, given a name, and laid back out in
   a clean atlas where no two of them overlap.
6. `pieces.json` is written in the Mage's format, so the Knight's rig data
   lives in exactly the same shape as the Mage's.

    python3 tools/knight_repack.py            # report only
    python3 tools/knight_repack.py --write    # report and write the atlas
"""

import json
import os
import sys
from collections import deque

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KNIGHT = os.path.join(ROOT, "Knight")
SHEETS = "/home/stark/Downloads/warrior_sprite"
VIEWS = ["front", "back", "left", "right"]
CELL = 32

# how alike two colours have to be to count as the same pixel
TOLERANCE = 60


def clusters(cell):
    """The connected blobs of opaque pixels in a cell."""
    px = cell.load()
    w, h = cell.size
    seen = [[False] * w for _ in range(h)]
    found = []
    for y in range(h):
        for x in range(w):
            if seen[y][x] or px[x, y][3] < 40:
                continue
            queue = deque([(x, y)])
            seen[y][x] = True
            blob = []
            while queue:
                cx, cy = queue.popleft()
                blob.append((cx, cy))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = cx + dx, cy + dy
                    if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and px[nx, ny][3] >= 40:
                        seen[ny][nx] = True
                        queue.append((nx, ny))
            found.append(blob)
    return found


def alike(a, b):
    return (abs(a[0] - b[0]) <= TOLERANCE and abs(a[1] - b[1]) <= TOLERANCE
            and abs(a[2] - b[2]) <= TOLERANCE)


def best_placement(blob, blob_px, ref_px):
    """Where a piece fits the reference best."""
    best = (-1, 0, 0)
    for ry in range(-4, CELL + 1):
        for rx in range(-4, CELL + 1):
            score = 0
            for (x, y) in blob:
                tx, ty = rx + x, ry + y
                if 0 <= tx < CELL and 0 <= ty < CELL:
                    target = ref_px[tx, ty]
                    if target[3] >= 40 and alike(blob_px[x, y], target):
                        score += 1
            if score > best[0]:
                best = (score, rx, ry)
    return best


def art_of(cell, blob):
    px = cell.load()
    return {(x, y): px[x, y] for (x, y) in blob}


def signature(art):
    """The same piece drawn twice has the same signature."""
    return tuple(sorted((x, y, c[0], c[1], c[2], c[3]) for (x, y), c in art.items()))


def colour_stats(art):
    reds = blues = golds = greys = 0
    for c in art.values():
        r, g, b = c[0], c[1], c[2]
        if r > 120 and r - g > 50 and r - b > 50:
            reds += 1
        elif b > 90 and b - r > 30:
            blues += 1
        elif r > 150 and g > 110 and b < 110:
            golds += 1
        else:
            greys += 1
    return {"red": reds, "blue": blues, "gold": golds, "grey": greys}


# What each cut piece is, per perspective, in the order the tool finds them
# (biggest first).  The sheets hold the same parts in a different arrangement
# in every view, so they have to be named by hand.
NAMES = {
    "front": ["body", "sword", "arm", "shield", "plume", "boot_right", "boot_left", "cloth"],
    "back": ["body", "cloth", "plume", "arm", "sword", "boot_right", "boot_left", "shield"],
    "left": ["body", "cloth", "plume", "sword", "boot_right", "arm", "boot_left", "shield"],
    "right": ["body", "arm", "shield", "sword", "cloth", "boot_right", "boot_left", "plume"],
}


def name_piece(view, index):
    names = NAMES.get(view, [])
    if index < len(names):
        return names[index]
    return "extra_%d" % index


def cut_piece(art):
    xs = [p[0] for p in art]
    ys = [p[1] for p in art]
    x0, x1 = min(xs), max(xs)
    y0, y1 = min(ys), max(ys)
    image = Image.new("RGBA", (x1 - x0 + 1, y1 - y0 + 1), (0, 0, 0, 0))
    px = image.load()
    for (x, y), c in art.items():
        px[x - x0, y - y0] = c
    return image, (x0, y0, x1, y1)


def analyse(view):
    sheet = Image.open(os.path.join(SHEETS, "Warrior_%s.png" % view)).convert("RGBA")
    cells = [sheet.crop((i * CELL, 0, (i + 1) * CELL, CELL)) for i in range(4)]

    # which cell is the finished knight?
    best_total = None
    best_ref = None
    for ref_index in range(4):
        ref_px = cells[ref_index].load()
        total = 0
        for other in range(4):
            if other == ref_index:
                continue
            for blob in clusters(cells[other]):
                if len(blob) < 8:
                    continue
                art = art_of(cells[other], blob)
                score, _, _ = best_placement(blob, cells[other].load(), ref_px)
                total += score
        if best_total is None or total > best_total:
            best_total = total
            best_ref = ref_index

    ref_cell = cells[best_ref]
    ref_px = ref_cell.load()

    # the pieces, each placed where it fits the reference best
    found = {}
    for other in range(4):
        if other == best_ref:
            continue
        cell = cells[other]
        cell_px = cell.load()
        for blob in clusters(cell):
            if len(blob) < 8:
                continue
            art = art_of(cell, blob)
            key = signature(art)
            score, rx, ry = best_placement(blob, cell_px, ref_px)
            ratio = score / float(len(blob))
            if key not in found or score > found[key]["score"]:
                found[key] = {"art": art, "score": score, "ratio": ratio, "at": (rx, ry)}

    pieces = []
    for entry in found.values():
        if entry["ratio"] < 0.35:
            continue
        art = entry["art"]
        image, box = cut_piece(art)
        pieces.append({
            "art": art,
            "image": image,
            "box": box,
            "placed": entry["at"],
            "score": entry["score"],
            "ratio": entry["ratio"],
        })
    pieces.sort(key=lambda p: -len(p["art"]))
    for index, piece in enumerate(pieces):
        piece["name"] = name_piece(view, index)
    return ref_cell, pieces


def write_atlas(view, pieces):
    """Lay the pieces out in a clean atlas where nothing overlaps."""
    atlas = Image.new("RGBA", (CELL * len(pieces), CELL), (0, 0, 0, 0))
    regions = {}
    for i, piece in enumerate(pieces):
        x = i * CELL
        atlas.paste(piece["image"], (x, 0))
        regions[piece["name"]] = {
            "x": x,
            "y": 0,
            "w": piece["image"].size[0],
            "h": piece["image"].size[1],
        }
    path = os.path.join(KNIGHT, "Knight_%s" % view, "Warrior_%s_clean.png" % view)
    atlas.save(path)
    return path, regions


def main():
    write = "--write" in sys.argv
    for view in VIEWS:
        ref, pieces = analyse(view)
        print("\n%s" % view)
        for piece in pieces:
            print("  %-6s %2dx%-2d at %-9s score %4d (%.0f%%)"
                  % (piece["name"], piece["image"].size[0], piece["image"].size[1],
                     str(piece["placed"]), piece["score"], piece["ratio"] * 100.0))
        if write:
            path, regions = write_atlas(view, pieces)
            print("  atlas written -> %s" % path)


if __name__ == "__main__":
    main()
