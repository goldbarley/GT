#!/usr/bin/env python3

"""
Measure the fire art and the knight, so the slash can be placed from them.

THE FIRE
--------
The art is a crescent: the blade swept an arc and left the fire behind.
Two things matter for placing it:

  * the hollow     the crescent's open side.  The fire's own shape says
                   which way it opens, and it must open towards the knight.
  * the size       how big the crescent is, in the master's pixels.

THE KNIGHT
----------
His crest is worn on the back of his head and streams behind him, so the
crest lies on the side he is facing away from.  That gives the way he
looks, and the helm gives him his face.

Both are measured here, from the pixels, so nothing has to be written down
by hand and the art can be redrawn without the effect breaking.

    python3 tools/knight_edge_placement.py
"""

import json
import math
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANIM = os.path.join(ROOT, "Knight", "Anim", "KnightUltimate")
KNIGHT = os.path.join(ROOT, "Knight")
SOURCE = "/home/stark/Downloads/fire_slash"

VIEWS = ["front", "back", "left", "right"]

# the master frame, the one the fire was painted on
MASTER = "frame2.jpg"

# the master's own canvas, and the margin the art is given so the embers
# have somewhere to drift to
CANVAS = os.path.join(ANIM, "canvas.json")


def load_master():
    """The master frame, and the fire's own brightness."""
    image = Image.open(os.path.join(SOURCE, MASTER)).convert("RGB")
    return np.asarray(image).astype(float)


def fire_geometry():
    """The fire's shape: where its mass is, and which way it opens."""
    array = load_master()
    glow = array.max(axis=2)
    fire = glow > 110

    ys, xs = np.nonzero(fire)
    weight = glow[ys, xs]
    centre = ((xs * weight).sum() / weight.sum(), (ys * weight).sum() / weight.sum())

    # which way does the crescent open?  The hollow is the direction with
    # the least fire in it
    counts = np.zeros(72)
    angles = np.degrees(np.arctan2(ys - centre[1], xs - centre[0])) % 360
    for i in range(72):
        counts[i] = ((angles >= i * 5) & (angles < i * 5 + 5)).sum()
    hollow = int(np.argmin(counts)) * 5

    # the blade's own path: the hot core is the line the sword drew
    core = array.sum(axis=2) > 700
    cys, cxs = np.nonzero(core)
    points = np.stack([cxs, cys], axis=1).astype(float)
    a = np.stack([points[:, 0], points[:, 1], np.ones(len(points))], axis=1)
    b = points[:, 0] ** 2 + points[:, 1] ** 2
    sol, *_ = np.linalg.lstsq(a, b, rcond=None)
    cx, cy = sol[0] / 2, sol[1] / 2
    radius = math.sqrt(sol[2] + cx * cx + cy * cy)

    # the chord the hot core draws: the width of the slash
    core_angles = np.degrees(np.arctan2(cys - cy, cxs - cx)) % 360
    span = 360 - (core_angles.max() - core_angles.min())
    if span > 180:
        span = 360 - span
    chord = 2 * radius * math.sin(math.radians(span) / 2)

    return {
        "centre": centre,
        "hollow": hollow,
        "core_radius": radius,
        "chord": chord,
        "extent": (int(xs.min()), int(xs.max()), int(ys.min()), int(ys.max())),
    }


def knight_geometry(view):
    """Which way the knight looks, and where his face is."""
    with open(os.path.join(KNIGHT, "Knight_%s" % view, "pieces.json")) as handle:
        data = json.load(handle)
    body = data["pieces"]["body"]
    region = body["region"]
    atlas = Image.open(os.path.join(KNIGHT, "Knight_%s" % view,
                                    "Knight_%s_clean.png" % (view, view))).convert("RGBA")
    array = np.asarray(atlas).astype(float)
    piece = array[region["y"]:region["y"] + region["h"],
                  region["x"]:region["x"] + region["w"]]
    alpha = array[region["y"]:region["y"] + region["h"],
                  region["x"]:region["x"] + region["w"], 3]

    red, green, blue = piece[:, :, 0], piece[:, :, 1], piece[:, :, 2]
    brightest = piece.max(axis=2)
    dullest = piece.min(axis=2)

    crest = (red > 100) & (green < red * 0.62) & (blue < red * 0.62) & (alpha > 120)
    helm = (brightest - dullest < 40) & (brightest > 90) & (alpha > 120)

    def centre(mask):
        ys, xs = np.nonzero(mask)
        if not len(xs):
            return None
        return float(xs.mean()), float(ys.mean())

    crest_at = centre(crest)
    helm_at = centre(helm)
    if crest_at is None or helm_at is None:
        return None

    # the crest trails behind him, so the way he looks is away from it
    dx = helm_at[0] - crest_at[0]
    dy = helm_at[1] - crest_at[1]
    if abs(dx) > abs(dy):
        facing = (1.0 if dx > 0 else -1.0, 0.0)
    else:
        facing = (0.0, 1.0 if dy > 0 else -1.0)

    # where his face is, in the rig's own space
    hip_x = body["pivot"]["x"]
    origin_x = body["position"]["x"] - hip_x
    origin_y = body["position"]["y"] - 32
    face = (origin_x + helm_at[0], origin_y + helm_at[1])

    return {
        "facing": {"x": facing[0], "y": facing[1]},
        "face": {"x": round(face[0], 2), "y": round(face[1], 2)},
        "crest_angle": round(math.degrees(math.atan2(dy, dx)), 2),
    }


def main():
    with open(CANVAS) as handle:
        canvas = json.load(handle)
    margin = canvas["margin"]

    fire = fire_geometry()
    print("the fire: its mass at (%.0f, %.0f), it opens at %d deg" % (
        fire["centre"][0], fire["centre"][1], fire["hollow"]))
    print("         the blade's path is a circle of radius %.0f, the chord %.0f" % (
        fire["core_radius"], fire["chord"]))

    views = {}
    for view in VIEWS:
        knight = knight_geometry(view)
        if knight is None:
            print("  %-6s: no crest found" % view)
            continue
        views[view] = knight
        print("  %-6s: he looks %s, his face is at %s" % (
            view, knight["facing"], knight["face"]))

    out = {
        "fire": {
            # where the fire's mass is, on the canvas the shader samples
            "centre": [round(fire["centre"][0] + margin, 2), round(fire["centre"][1] + margin, 2)],
            # the way it opens, in the master's degrees
            "hollow": fire["hollow"],
            # the width of the blade's path, in the master's pixels
            "chord": round(fire["chord"], 2),
            "core_radius": round(fire["core_radius"], 2),
        },
        "knight": views,
    }
    path = os.path.join(ANIM, "placement.json")
    with open(path, "w") as handle:
        json.dump(out, handle, indent=1)
    print("\nwrote", path)


if __name__ == "__main__":
    main()
