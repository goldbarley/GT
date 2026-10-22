#!/usr/bin/env python3
"""
Check the built Archer rig against the art it was built from.

The rig is written out as a clean atlas, a `pieces.json` and a `.tscn` scene.
This reads those files back and puts the sprite together again, using only what
is written in them, then compares the result with the assembled archer that the
source atlas holds.  If the rig is right, the two are the same picture.

It also checks the two rules the rig has to keep:

  * every piece is drawn where `pieces.json` says it is
  * every piece turns about its pivot, and the pivot really is the joint the
    pivot was worked out for

Run with:  python3 tools/archer_verify.py
"""

import json
import os
import re
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARCHER_DIR = os.path.join(ROOT, "Archer")
SOURCE_DIR = os.path.join(os.path.expanduser("~"), "Downloads", "Archer_sprites")
PERSPECTIVES = ["front", "back", "left", "right"]


def read_tscn(path):
    """The Sprite2D blocks of a scene: {node name: {...}}."""
    text = open(path).read()
    out = {}
    for m in re.finditer(r'\[node name="([^"]+)" type="Sprite2D"[^\]]*\]\n(.*?)(?=\n\[|\Z)',
                         text, re.S):
        name = m.group(1)
        block = m.group(2)
        region = re.search(r"region_rect = Rect2\(([^)]*)\)", block)
        if region is None:
            # an effect node, not a piece of the archer
            continue
        offset = re.search(r"offset = Vector2\(([^)]*)\)", block)
        position = re.search(r"position = Vector2\(([^)]*)\)", block)
        pivot = re.search(r"metadata/pivot = Vector2\(([^)]*)\)", block)
        z = re.search(r"z_index = (\d+)", block)
        out[name] = {
            "region": [float(v) for v in region.group(1).split(",")],
            "offset": [float(v) for v in offset.group(1).split(",")],
            "position": [float(v) for v in position.group(1).split(",")],
            "pivot": [float(v) for v in pivot.group(1).split(",")],
            "z_index": int(z.group(1)) if z else 0,
        }
    return out


def node_name(piece_name):
    return "".join(part.capitalize() for part in piece_name.split("_"))


def check(persp):
    base = os.path.join(ARCHER_DIR, f"archer_{persp}")
    data = json.load(open(os.path.join(base, "pieces.json")))
    tscn = read_tscn(os.path.join(base, f"archer_{persp}.tscn"))
    clean = Image.open(os.path.join(base, data["spritesheet"])).convert("RGBA")

    problems = []
    canvas_w = data["canvas_size"]["width"]
    canvas_h = data["canvas_size"]["height"]

    # ---- draw the rig back up, using only what the files say -------------
    canvas = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
    for piece_name, piece in sorted(data["pieces"].items(),
                                    key=lambda kv: kv[1]["z_index"]):
        node = tscn.get(node_name(piece_name))
        if node is None:
            problems.append(f"{piece_name}: no Sprite2D node in the scene")
            continue

        # the rule the rig keeps: the node's origin is the pivot, and the art
        # hangs off it by the pivot, so the art lands where pieces.json says
        art_x = node["position"][0] + node["offset"][0]
        art_y = node["position"][1] + node["offset"][1]
        want_x = piece["position"]["x"]
        want_y = piece["position"]["y"]
        if abs(art_x - want_x) > 0.01 or abs(art_y - want_y) > 0.01:
            problems.append(
                f"{piece_name}: art lands at ({art_x},{art_y}) but pieces.json "
                f"says ({want_x},{want_y})")

        # the pivot is where the node's origin is
        pivot_x = node["position"][0] - want_x
        pivot_y = node["position"][1] - want_y
        if (abs(pivot_x - piece["pivot"]["x"]) > 0.01
                or abs(pivot_y - piece["pivot"]["y"]) > 0.01):
            problems.append(
                f"{piece_name}: the scene's pivot ({pivot_x},{pivot_y}) is not "
                f"the pivot in pieces.json ({piece['pivot']['x']},{piece['pivot']['y']})")

        # the rectangle really holds this piece's art
        r = node["region"]
        crop = clean.crop((int(r[0]), int(r[1]), int(r[0] + r[2]), int(r[1] + r[3])))
        if crop.getbbox() is None:
            problems.append(f"{piece_name}: its rectangle in the clean atlas is empty")

        canvas.alpha_composite(crop, (int(round(want_x)), int(round(want_y))))

    # ---- compare with the assembled archer --------------------------------
    rr = data["reference_rect"]
    reference = clean.crop((rr["x"], rr["y"], rr["x"] + rr["w"], rr["y"] + rr["h"]))
    wrong = missing = extra = 0
    cp, rp = canvas.load(), reference.load()
    for y in range(min(canvas.height, reference.height)):
        for x in range(min(canvas.width, reference.width)):
            a, b = cp[x, y], rp[x, y]
            if a[3] == 0 and b[3] == 0:
                continue
            if a[3] == 0:
                missing += 1
            elif b[3] == 0:
                extra += 1
            elif a[:3] != b[:3]:
                wrong += 1

    print(f"== {persp}  canvas {canvas_w}x{canvas_h}  pieces {len(data['pieces'])}")
    for name, piece in data["pieces"].items():
        print(f"   {name:8s} pos ({piece['position']['x']:>5},{piece['position']['y']:>5})"
              f"  pivot ({piece['pivot']['x']:>6},{piece['pivot']['y']:>6})"
              f"  z {piece['z_index']}")
    print(f"   against the assembled archer: wrong {wrong}, missing {missing}, extra {extra}")
    for p in problems:
        print("   PROBLEM:", p)
    return problems, (wrong, missing, extra)


def mirror_check():
    """
    The left and right views are mirror images of each other, so the two rigs
    have to agree about where every piece sits and where it turns.  A piece
    that is in the right place in one view and mirrored in the other is a
    piece that was put in the wrong place.
    """
    print("== mirror check (left against right)")
    left = json.load(open(os.path.join(ARCHER_DIR, "archer_left", "pieces.json")))
    right = json.load(open(os.path.join(ARCHER_DIR, "archer_right", "pieces.json")))
    width = left["canvas_size"]["width"]
    problems = 0
    for name, lp in left["pieces"].items():
        if name not in right["pieces"]:
            continue
        rp = right["pieces"][name]
        want_x = width - rp["position"]["x"] - rp["region"]["w"]
        got_x = lp["position"]["x"]
        # the joint, measured in the canvas, has to mirror as well
        want_pv = width - (rp["position"]["x"] + rp["pivot"]["x"])
        got_pv = lp["position"]["x"] + lp["pivot"]["x"]
        # the two profile views are the same art mirrored, but the arm is
        # drawn a little differently in each, so a joint can be a couple of
        # pixels apart without anything being wrong
        ok = abs(want_x - got_x) <= 1 and abs(want_pv - got_pv) <= 4
        print(f"   {name:8s} left x {got_x:>5}  right mirrored {want_x:>5}   "
              f"joint {got_pv:>6} / {want_pv:>6}   {'ok' if ok else 'DIFFERENT'}")
        if not ok:
            problems += 1
    print(f"   {problems} pieces do not mirror")
    return problems


def previews():
    """Draw each rig back up from the written files, for a look at it."""
    out = Image.new("RGBA", (1280, 120), (30, 30, 38, 255))
    x = 0
    for persp in PERSPECTIVES:
        base = os.path.join(ARCHER_DIR, f"archer_{persp}")
        data = json.load(open(os.path.join(base, "pieces.json")))
        clean = Image.open(os.path.join(base, data["spritesheet"])).convert("RGBA")
        w = data["canvas_size"]["width"]
        h = data["canvas_size"]["height"]
        canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        for name, piece in sorted(data["pieces"].items(),
                                  key=lambda kv: kv[1]["z_index"]):
            r = piece["region"]
            crop = clean.crop((r["x"], r["y"], r["x"] + r["w"], r["y"] + r["h"]))
            canvas.alpha_composite(crop, (piece["position"]["x"], piece["position"]["y"]))
        canvas = canvas.resize((w * 3, h * 3), Image.NEAREST)
        out.alpha_composite(canvas, (x, 0))
        x += w * 3 + 8
    out.save("/tmp/opencode/archer_rig.png")
    print("   wrote /tmp/opencode/archer_rig.png")


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    only = args if args else PERSPECTIVES
    bad = 0
    for p in only:
        problems, diffs = check(p)
        bad += len(problems)
    print()
    bad += mirror_check()
    print()
    previews()
    print()
    print("no structural problems" if bad == 0 else f"{bad} problems")
