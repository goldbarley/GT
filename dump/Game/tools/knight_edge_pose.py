#!/usr/bin/env python3

"""
Work out the raised pose for Knight's Edge.

The first part of the ultimate is the knight lifting his sword, and the fire
climbing the blade.  The pose has to be worked out per view, because the
sword sits differently in each of them, and in the left view there is no arm
of its own for the sword to ride on.

This tool asks the rig itself: it poses every view, finds the turn that
lifts the blade highest, and writes the answer out for the clip to use.

    python3 tools/knight_edge_pose.py
"""

import json
import math
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KNIGHT = os.path.join(ROOT, "Knight")
ANIM = os.path.join(KNIGHT, "Anim", "KnightUltimate")
VIEWS = ["right", "left", "front", "back"]


def rig_pieces(view):
    """The pieces of a view, and where each one's pivot rests."""
    with open(os.path.join(KNIGHT, "Knight_%s" % view, "pieces.json")) as handle:
        data = json.load(handle)
    hip = data["pieces"]["body"]["pivot"]
    rest = {}
    for name, piece in data["pieces"].items():
        if "position" not in piece:
            continue
        rest[name] = (piece["position"]["x"] - hip["x"] + piece["pivot"]["x"],
                      piece["position"]["y"] - 32 + piece["pivot"]["y"])
    return data, rest


def blade_tip(view, data):
    """The tip of the sword, from the sword's own pivot."""
    piece = data["pieces"]["sword"]
    region = piece["region"]
    atlas = Image.open(os.path.join(KNIGHT, "Knight_%s" % view,
                                    "Knight_%s_clean.png" % view)).convert("RGBA")
    art = atlas.crop((region["x"], region["y"],
                      region["x"] + region["w"], region["y"] + region["h"]))
    array = np.asarray(art)
    ys, xs = np.nonzero(array[:, :, 3] > 40)
    px, py = piece["pivot"]["x"], piece["pivot"]["y"]
    far = int(np.argmax(np.hypot(xs - px, ys - py)))
    return (int(xs[far]) - px, int(ys[far]) - py)


def pose(rest, parents, role_of, turns):
    """Where each piece ends up, the way the choreography player works it out."""
    order = []

    def visit(piece):
        if piece in order or piece not in rest:
            return
        parent = parents.get(piece)
        if parent:
            visit(parent)
        order.append(piece)

    for piece in rest:
        visit(piece)

    place = {}
    spin = {}
    for piece in order:
        own = turns.get(role_of.get(piece, ""), 0.0)
        parent = parents.get(piece)
        if parent and parent in place:
            offset = (rest[piece][0] - rest[parent][0], rest[piece][1] - rest[parent][1])
            radians = math.radians(spin[parent])
            swung = (offset[0] * math.cos(radians) - offset[1] * math.sin(radians),
                     offset[0] * math.sin(radians) + offset[1] * math.cos(radians))
            place[piece] = (place[parent][0] + swung[0], place[parent][1] + swung[1])
            spin[piece] = spin[parent] + own
        else:
            place[piece] = rest[piece]
            spin[piece] = own
    return place, spin


def main():
    answers = {}
    for view in VIEWS:
        data, rest = rig_pieces(view)
        roles = data["roles"]
        parents = {}
        for role, parent_role in data.get("piece_parents", {}).items():
            if role in roles and parent_role in roles:
                parents[roles[role]] = roles[parent_role]
        role_of = {piece: role for role, piece in roles.items()}

        # the left view has no arm of its own, so the sword turns on its own
        swing_role = "arm" if "arm" in roles else "sword"
        tip = blade_tip(view, data)

        best = None
        for angle in np.arange(-180.0, 180.0, 1.0):
            place, spin = pose(rest, parents, role_of, {swing_role: float(angle)})
            # where the tip of the blade ends up
            radians = math.radians(spin["sword"])
            offset = (tip[0] * math.cos(radians) - tip[1] * math.sin(radians),
                      tip[0] * math.sin(radians) + tip[1] * math.cos(radians))
            at = (place["sword"][0] + offset[0], place["sword"][1] + offset[1])
            if best is None or at[1] < best[0]:
                best = (at[1], float(angle), at)
        print("%-6s: the %s turns %7.1f to lift the blade, the tip at %s" % (
            view, swing_role, best[1], best[2]))
        answers[view] = {"role": swing_role, "angle": best[1]}

    os.makedirs(ANIM, exist_ok=True)
    path = os.path.join(ANIM, "pose.json")
    with open(path, "w") as handle:
        json.dump(answers, handle, indent=1)
    print("\nwrote", path)


if __name__ == "__main__":
    main()
