#!/usr/bin/env python3

"""
Build the Knight's Edge flipbook from the source frames.

The frames are exports of one sweep, but they were saved at different sizes
and crops, so they have to be put on one canvas before they can be packed
into a flipbook.  The frames that share the big canvas are already on it;
the ones that were zoomed in are matched against the frame after them and
the transforms are composed, which keeps every step small enough to match
well.

The result is a row of eight cells, which the shader plays through.

    python3 tools/knight_edge_frames.py
"""

import json
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = "/home/stark/Downloads/fire_slash"
ANIM = os.path.join(ROOT, "Knight", "Anim", "KnightUltimate")
OUT_DIR = os.path.join(ANIM, "sprites")

CHAIN = [
    "frame1.png",
    "frame1.1.png",
    "frame1.2.png",
    "frame2.jpg",
    "frame3.jpg",
    "frame4.jpg",
    "frame5.jpg",
    "frame6.jpg",
]

MASTER = "frame2.jpg"
MASTER_SIZE = (938, 520)

# The last of the fire is embers, and embers drift: they float in the air
# for a while after the sweep is done.  The art needs room to drift into,
# so it is laid on a bigger canvas with a margin all round.
MARGIN = 110
CANVAS_SIZE = (MASTER_SIZE[0] + 2 * MARGIN, MASTER_SIZE[1] + 2 * MARGIN)

# how big one cell of the flipbook is
CELL_W = 560
CELL_H = int(round(CELL_W * CANVAS_SIZE[1] / CANVAS_SIZE[0]))

# the source frames are dark grey, not black, so the cut has to be above it
CUT = 110.0


def load(name):
    """The frame's bright mask."""
    image = Image.open(os.path.join(SOURCE, name)).convert("RGB")
    array = np.asarray(image).astype(float)
    threshold = 200 if name.endswith(".jpg") else 90
    return (array.sum(axis=2) > threshold).astype(np.float32), image.size


def content(mask):
    """The mask cropped to the art, and where that art sits."""
    ys, xs = np.nonzero(mask)
    if not len(xs):
        return None, (0, 0)
    box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    return mask[box[1]:box[3], box[0]:box[2]], (box[0], box[1])


def match(source, target, scales):
    """Where the source art sits on the target, and how big it is."""
    best = None
    for scale in scales:
        height = max(2, int(round(source.shape[0] * scale)))
        width = max(2, int(round(source.shape[1] * scale)))
        if height >= target.shape[0] or width >= target.shape[1]:
            continue
        small = np.asarray(
            Image.fromarray((source * 255).astype(np.uint8)).resize((width, height), Image.LANCZOS)
        ) > 40
        small = small.astype(np.float32)
        source_sum = small.sum()
        if source_sum < 20:
            continue
        for y in range(0, target.shape[0] - height, 3):
            for x in range(0, target.shape[1] - width, 3):
                window = target[y:y + height, x:x + width]
                inter = (window * small).sum()
                union = window.sum() + source_sum - inter
                score = inter / union if union else 0.0
                if best is None or score > best[0]:
                    best = (score, scale, x, y, width, height)
    return best


def refine(source, target, guess):
    """A finer pass around the coarse guess."""
    best = guess
    for scale in np.arange(max(0.3, guess[1] - 0.12), guess[1] + 0.12, 0.02):
        height = max(2, int(round(source.shape[0] * scale)))
        width = max(2, int(round(source.shape[1] * scale)))
        if height >= target.shape[0] or width >= target.shape[1]:
            continue
        small = (np.asarray(
            Image.fromarray((source * 255).astype(np.uint8)).resize((width, height), Image.LANCZOS)
        ) > 40).astype(np.float32)
        source_sum = small.sum()
        for y in range(max(0, guess[3] - 8), min(target.shape[0] - height, guess[3] + 8) + 1):
            for x in range(max(0, guess[2] - 8), min(target.shape[1] - width, guess[2] + 8) + 1):
                window = target[y:y + height, x:x + width]
                inter = (window * small).sum()
                union = window.sum() + source_sum - inter
                score = inter / union if union else 0.0
                if score > best[0]:
                    best = (score, scale, x, y, width, height)
    return best


def align():
    """Where each frame's art sits in the master's canvas."""
    frames = {}
    for name in CHAIN:
        mask, size = load(name)
        art, origin = content(mask)
        frames[name] = {"mask": mask, "art": art, "origin": origin, "size": size}

    master = frames[MASTER]
    # where each frame's art sits in the master's canvas: scale, x, y
    placed = {MASTER: (1.0, float(master["origin"][0]), float(master["origin"][1]))}

    # the frames on the master's canvas are already on it, they only fade
    for name in CHAIN:
        if name == MASTER:
            continue
        if frames[name]["size"] != master["size"]:
            continue
        placed[name] = (1.0, float(frames[name]["origin"][0]), float(frames[name]["origin"][1]))
        print("  %-14s: already on the master's canvas" % name)

    # the zoomed in frames are matched against the one after them, and the
    # transform is composed back to the master
    for index in range(CHAIN.index(MASTER) - 1, -1, -1):
        name = CHAIN[index]
        nxt = CHAIN[index + 1]
        guess = match(frames[name]["art"], frames[nxt]["mask"], np.arange(0.4, 2.3, 0.05))
        if guess is None:
            print("  %-14s: no match" % name)
            continue
        guess = refine(frames[name]["art"], frames[nxt]["mask"], guess)
        score, scale, x, y, w, h = guess
        # the match is in the next frame's canvas; compose it forward
        ns, nx, ny = placed[nxt]
        ox, oy = frames[nxt]["origin"]
        placed[name] = (scale * ns, nx + (x - ox) * ns, ny + (y - oy) * ns)
        print("  %-14s -> %-14s: scale %.3f at (%d,%d) %dx%d, overlap %.3f" % (
            name, nxt, scale, x, y, w, h, score))

    out = {
        name: {"scale": round(placed[name][0], 5),
               "x": round(placed[name][1], 2),
               "y": round(placed[name][2], 2)}
        for name in CHAIN
    }
    path = os.path.join(ANIM, "alignment.json")
    with open(path, "w") as handle:
        json.dump(out, handle, indent=1)
    print("wrote", path)
    return out


def build(alignment):
    """The flipbook, and the sheet to look at it with."""
    placed = []
    for name in CHAIN:
        image = Image.open(os.path.join(SOURCE, name)).convert("RGB")
        array = np.asarray(image).astype(float)
        threshold = 200 if name.endswith(".jpg") else 90
        ys, xs = np.nonzero(array.sum(axis=2) > threshold)
        cropx, cropy = int(xs.min()), int(ys.min())
        art = image.crop((cropx, cropy, int(xs.max()) + 1, int(ys.max()) + 1))

        info = alignment[name]
        scale = info["scale"]
        art = art.resize((max(1, int(round(art.size[0] * scale))),
                          max(1, int(round(art.size[1] * scale)))), Image.LANCZOS)

        # the master's canvas, with this frame's art on it, and a margin
        # round it for the embers to drift into
        sheet = Image.new("RGB", CANVAS_SIZE, (0, 0, 0))
        sheet.paste(art, (int(round(info["x"])) + MARGIN, int(round(info["y"])) + MARGIN))
        placed.append(sheet)

    # the flipbook, one cell per frame
    atlas = Image.new("RGBA", (CELL_W * len(placed), CELL_H), (0, 0, 0, 0))
    for index, sheet in enumerate(placed):
        array = np.asarray(sheet).astype(float)
        # the frame is scaled down to the cell, and the alpha comes from how
        # bright the fire is, so the dark background goes away
        small = Image.fromarray(array.astype(np.uint8)).resize((CELL_W, CELL_H), Image.LANCZOS)
        pixels = np.asarray(small).astype(float)
        glow = pixels.max(axis=2)
        alpha = np.clip((glow - CUT) * 1.7, 0.0, 255.0)
        rgba = np.dstack([pixels, alpha]).astype(np.uint8)
        atlas.paste(Image.fromarray(rgba, "RGBA"), (index * CELL_W, 0))

    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, "fire_slash.png")
    atlas.save(path)
    print("wrote %s  (%dx%d, %d frames)" % (path, atlas.size[0], atlas.size[1], len(placed)))

    # the canvas the art sits on, so the other tools know where it is
    canvas = {
        "master_size": list(MASTER_SIZE),
        "canvas_size": list(CANVAS_SIZE),
        "margin": MARGIN,
        "cell_size": [CELL_W, CELL_H],
    }
    path = os.path.join(ANIM, "canvas.json")
    with open(path, "w") as handle:
        json.dump(canvas, handle, indent=1)
    print("wrote", path)

    # a sheet to look at, so the alignment can be checked by eye
    sheet = Image.new("RGBA", (CELL_W * 4, CELL_H * 2), (24, 22, 30, 255))
    for index in range(len(placed)):
        frame = atlas.crop((index * CELL_W, 0, (index + 1) * CELL_W, CELL_H))
        sheet.alpha_composite(frame, ((index % 4) * CELL_W, (index // 4) * CELL_H))
    sheet.convert("RGB").save("/tmp/opencode/flipbook.png")
    print("wrote /tmp/opencode/flipbook.png")


def main():
    print("aligning the frames:")
    alignment = align()
    print("\nbuilding the flipbook:")
    build(alignment)


if __name__ == "__main__":
    main()
