#!/usr/bin/env python3
"""
Rebuild the modular Knight's side views from their assembled reference pictures.

The side views' `body.png` was never cut out properly and is a black
placeholder, so the knight renders without his cape, his plume or his feet,
and the sword hangs in the wrong place.  The `assembled_reference.png` next to
it is the finished knight, so the body is cut from that instead: the reference
minus the arm and the sword, which stay separate pieces so they can swing.

    python3 tools/knight_rebuild.py --view left
    python3 tools/knight_rebuild.py --view right
"""

import json
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KNIGHT = os.path.join(ROOT, "Knight")


def load(path):
    return Image.open(path).convert("RGBA")


def match(a, b, tolerance=40):
    return (abs(a[0] - b[0]) <= tolerance and abs(a[1] - b[1]) <= tolerance
            and abs(a[2] - b[2]) <= tolerance)


def score_at(ref, ref_px, piece, piece_px, x0, y0):
    good = 0
    bad = 0
    for y in range(piece.size[1]):
        for x in range(piece.size[0]):
            p = piece_px[x, y]
            if p[3] < 40:
                continue
            rx, ry = x0 + x, y0 + y
            if rx < 0 or ry < 0 or rx >= ref.size[0] or ry >= ref.size[1]:
                bad += 1
                continue
            r = ref_px[rx, ry]
            if r[3] < 40:
                bad += 1
            elif match(p, r):
                good += 1
            else:
                bad += 2
    return good - bad * 2


def best_fit(ref, ref_px, piece):
    piece_px = piece.load()
    best = (0, 0)
    best_score = None
    for y0 in range(-piece.size[1], ref.size[1]):
        for x0 in range(-piece.size[0], ref.size[0]):
            s = score_at(ref, ref_px, piece, piece_px, x0, y0)
            if best_score is None or s > best_score:
                best_score = s
                best = (x0, y0)
    return best, best_score


def rebuild(view):
    folder = os.path.join(KNIGHT, "Knight_%s" % view, "sprites")
    ref = load(os.path.join(folder, "assembled_reference.png"))
    ref_px = ref.load()
    arm = load(os.path.join(folder, "arm.png"))
    sword = load(os.path.join(folder, "sword.png"))

    arm_at, arm_score = best_fit(ref, ref_px, arm)
    sword_at, sword_score = best_fit(ref, ref_px, sword)
    print("%s: arm at %s (score %d), sword at %s (score %d)"
          % (view, arm_at, arm_score, sword_at, sword_score))

    # the body is everything in the reference except the arm and the sword
    body = Image.new("RGBA", ref.size, (0, 0, 0, 0))
    body_px = body.load()
    for y in range(ref.size[1]):
        for x in range(ref.size[0]):
            body_px[x, y] = ref_px[x, y]
    for piece, (x0, y0) in ((arm, arm_at), (sword, sword_at)):
        piece_px = piece.load()
        for y in range(piece.size[1]):
            for x in range(piece.size[0]):
                p = piece_px[x, y]
                if p[3] < 40:
                    continue
                rx, ry = x0 + x, y0 + y
                if 0 <= rx < body.size[0] and 0 <= ry < body.size[1]:
                    body_px[rx, ry] = (0, 0, 0, 0)

    out = os.path.join(folder, "body.png")
    body.save(out)
    print("  body rebuilt from the reference -> %s %s" % (out, body.size))

    # and the arm and the sword are cut out of the reference too, so the rig
    # draws the very same art
    for name, piece, at in (("arm", arm, arm_at), ("sword", sword, sword_at)):
        crop = Image.new("RGBA", ref.size, (0, 0, 0, 0))
        crop_px = crop.load()
        for y in range(ref.size[1]):
            for x in range(ref.size[0]):
                crop_px[x, y] = ref_px[x, y]
        piece_px = piece.load()
        for y in range(piece.size[1]):
            for x in range(piece.size[0]):
                p = piece_px[x, y]
                if p[3] < 40:
                    continue
                rx, ry = at[0] + x, at[1] + y
                if 0 <= rx < crop.size[0] and 0 <= ry < crop.size[1]:
                    crop_px[rx, ry] = (0, 0, 0, 0)
        bbox = crop.getbbox()
        if bbox:
            crop = crop.crop(bbox)
        path = os.path.join(folder, "%s.png" % name)
        crop.save(path)
        print("  %s cut from the reference -> %s %s" % (name, path, crop.size))


if __name__ == "__main__":
    views = ["left", "right"]
    if "--view" in sys.argv:
        views = [sys.argv[sys.argv.index("--view") + 1]]
    for view in views:
        rebuild(view)
