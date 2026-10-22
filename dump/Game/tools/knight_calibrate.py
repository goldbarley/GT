#!/usr/bin/env python3
"""
Calibrate the modular Knight's rigs against their assembled reference pictures.

Each perspective has an `assembled_reference.png`, which is the finished
knight.  The rig has to put the same pixels back together, so the tool slides
every piece over the reference and keeps the place where it agrees with it.

    python3 tools/knight_calibrate.py           # report
    python3 tools/knight_calibrate.py --write   # report and fix the rigs

The pieces that the reference has and the rig does not (the cape and the
plume on the side views) are cut out of the reference and saved as new
sprites, so the knight is whole again.
"""

import json
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KNIGHT = os.path.join(ROOT, "Knight")
VIEWS = ["back", "left", "right"]

# the pieces the rig is made of, and where they live
PIECES = ["body", "arm", "sword"]


def load(path):
    return Image.open(path).convert("RGBA")


def pixels(image):
    return image.load()


def colour_matches(a, b, tolerance=40):
    return (abs(a[0] - b[0]) <= tolerance and abs(a[1] - b[1]) <= tolerance
            and abs(a[2] - b[2]) <= tolerance and abs(a[3] - b[3]) <= tolerance)


def score_piece(ref, ref_px, piece, piece_px, offset, ref_size):
    """How well a piece agrees with the reference at this offset."""
    x0, y0 = offset
    good = 0
    bad = 0
    for y in range(piece.size[1]):
        for x in range(piece.size[0]):
            p = piece_px[x, y]
            if p[3] < 40:
                continue
            rx = x0 + x
            ry = y0 + y
            if rx < 0 or ry < 0 or rx >= ref_size[0] or ry >= ref_size[1]:
                bad += 1
                continue
            r = ref_px[rx, ry]
            if r[3] < 40:
                bad += 1
            elif colour_matches(p, r):
                good += 1
            else:
                bad += 2
    return good - bad * 2


def best_offset(ref, ref_px, piece, piece_px, ref_size):
    best = None
    best_score = None
    for y0 in range(-piece.size[1], ref_size[1]):
        for x0 in range(-piece.size[0], ref_size[0]):
            s = score_piece(ref, ref_px, piece, piece_px, (x0, y0), ref_size)
            if best_score is None or s > best_score:
                best_score = s
                best = (x0, y0)
    return best, best_score


def piece_files(view):
    folder = os.path.join(KNIGHT, "Knight_%s" % view, "sprites")
    return {
        "body": os.path.join(folder, "body.png"),
        "arm": os.path.join(folder, "arm.png"),
        "sword": os.path.join(folder, "sword.png"),
    }


def analyse(view):
    ref = load(os.path.join(KNIGHT, "Knight_%s" % view, "sprites", "assembled_reference.png"))
    ref_px = pixels(ref)
    files = piece_files(view)
    result = {}
    for name in PIECES:
        piece = load(files[name])
        offset, score = best_offset(ref, ref_px, piece, pixels(piece), ref.size)
        result[name] = {"offset": offset, "score": score, "size": piece.size}
    return ref, ref_px, files, result


def cut_body(view, ref, ref_px, files, offsets):
    """Build a body sprite that holds everything the rig was missing.

    The reference has the arm and the sword baked into it.  Those are cut away
    so the real pieces can swing, and everything that is left is the knight's
    body: the armour, the cape, the plume and the legs.
    """
    body = load(files["body"])
    body_px = pixels(body)
    body_w, body_h = body.size
    out = Image.new("RGBA", (ref.size[0], ref.size[1]), (0, 0, 0, 0))
    out_px = pixels(out)

    # where the body sits inside the reference
    bx, by = offsets["body"]["offset"]
    for y in range(body_h):
        for x in range(body_w):
            rx = bx + x
            ry = by + y
            if 0 <= rx < ref.size[0] and 0 <= ry < ref.size[1]:
                out_px[rx, ry] = ref_px[rx, ry]

    # and cut the arm and the sword away again
    for name in ("arm", "sword"):
        piece = load(files[name])
        piece_px = pixels(piece)
        x0, y0 = offsets[name]["offset"]
        for y in range(piece.size[1]):
            for x in range(piece.size[0]):
                p = piece_px[x, y]
                if p[3] < 40:
                    continue
                rx = x0 + x
                ry = y0 + y
                if 0 <= rx < out.size[0] and 0 <= ry < out.size[1]:
                    out_px[rx, ry] = (0, 0, 0, 0)

    # trim it to what is left
    bbox = out.getbbox()
    if bbox:
        out = out.crop(bbox)
    return out


def write_body(view, image):
    path = os.path.join(KNIGHT, "Knight_%s" % view, "sprites", "body.png")
    image.save(path)
    return path


def main():
    write = "--write" in sys.argv
    for view in VIEWS:
        ref, ref_px, files, result = analyse(view)
        print("\n%s" % view)
        for name in PIECES:
            offset, score = result[name]["offset"], result[name]["score"]
            print("  %-6s best at %-12s score %d" % (name, str(offset), score))
        if write:
            body = cut_body(view, ref, ref_px, files, result)
            path = write_body(view, body)
            print("  body rebuilt from the reference -> %s %s" % (path, body.size))


if __name__ == "__main__":
    main()
