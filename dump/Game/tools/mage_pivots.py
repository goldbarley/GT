#!/usr/bin/env python3
"""
Derive correct rotation pivots for the modular Mage pieces and write them into
`pieces.json` and the `.tscn` scenes.

WHY
---
The original pivots were hand-placed and only roughly meaningful: the staff's
pivot sat in the middle of the shaft instead of at the hand that holds it, and
several boot pivots sat off the visible top of the boot.  A rotation pivot has to
sit on the joint or the limb swings around the wrong point.

HOW
---
* staff  -> the point where the hand crosses the shaft (the staff x arm overlap,
            or staff x body in the left view where the arm is part of the body).
* arm    -> the shoulder: the arm pixel furthest from the hand, nudged one pixel
            back towards the hand so the pivot sits inside the sprite mass.
* foot   -> the hip: the centroid of the boot's topmost row of art, which is the
            point where the leg enters the robe.

Changing a pivot does not move the sprite: the scene stores
`offset = -pivot` and `position = assembled_pos + pivot`, so the art's top-left
stays exactly where it was.  Only the rotation centre moves.
"""

import json
import os
import re
import statistics
from collections import Counter

from PIL import Image

MAGE_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Mage")
PERSPECTIVES = ["front", "back", "left", "right"]


def median_int(values):
    return int(statistics.median(values))


def piece_masks(tex, pieces, w, h):
    masks = {}
    for name, info in pieces.items():
        r = info["region"]
        m = Image.new("L", (w, h), 0)
        alpha = tex.crop((r["x"], r["y"], r["x"] + r["w"], r["y"] + r["h"])).split()[3]
        m.paste(alpha, (info["position"]["x"], info["position"]["y"]))
        masks[name] = m
    return masks


def art_pixels(mask):
    px = mask.load()
    return [(x, y) for y in range(mask.height) for x in range(mask.width) if px[x, y] > 0]


def derive_pivots(tex, pieces, w, h):
    masks = piece_masks(tex, pieces, w, h)
    art = {n: art_pixels(m) for n, m in masks.items()}
    sets = {n: set(v) for n, v in art.items()}

    arm = None
    for cand in ("arm_right", "arm_left"):
        if cand in pieces:
            arm = cand
            break

    out = {}

    # ---- staff: the hand grips the shaft ------------------------------------
    grip_src = sets[arm] if arm else sets["body"]
    grip = sorted(sets["staff"] & grip_src)
    if grip:
        gx = median_int([q[0] for q in grip])
        gy = median_int([q[1] for q in grip])
        sp = pieces["staff"]["position"]
        out["staff"] = (gx - sp["x"], gy - sp["y"])

    # ---- arm: the shoulder, furthest from the hand --------------------------
    if arm and "staff" in out:
        hx, hy = out["staff"]
        hx += pieces["staff"]["position"]["x"]
        hy += pieces["staff"]["position"]["y"]
        root = max(art[arm], key=lambda q: (q[0] - hx) ** 2 + (q[1] - hy) ** 2)
        rx = root[0] + (1 if hx > root[0] else -1)
        ry = root[1] + (1 if hy > root[1] else -1)
        ap = pieces[arm]["position"]
        out[arm] = (rx - ap["x"], ry - ap["y"])

    # ---- feet: the hip, at the top of the visible boot ----------------------
    for foot in [n for n in pieces if n.startswith("foot")]:
        fp = pieces[foot]["position"]
        local = sorted(((x - fp["x"], y - fp["y"]) for x, y in art[foot]), key=lambda q: (q[1], q[0]))
        top = local[0][1]
        row = [q[0] for q in local if q[1] == top]
        out[foot] = (median_int(row), top)

    return out


def norm(name):
    return name.replace("_", "").lower()


def rewrite_tscn(tscn, pieces, persp):
    node_for = {}
    for m in re.finditer(r'\[node name="([^"]+)" type="Sprite2D"', tscn):
        node_for[norm(m.group(1))] = m.group(1)
    for pname, info in pieces.items():
        node = node_for.get(norm(pname))
        if not node:
            continue
        pat = re.compile(
            r'(\[node name="%s" type="Sprite2D"[^\]]*\]\n)(.*?)(?=\n\[|\Z)' % re.escape(node),
            re.S,
        )
        m = pat.search(tscn)
        if not m:
            continue
        blk = m.group(2)
        piv = info["pivot"]
        pos = info["position"]
        blk = re.sub(r"offset = Vector2\([^\)]*\)",
                     f"offset = Vector2({-piv['x']}, {-piv['y']})", blk)
        blk = re.sub(r"position = Vector2\([^\)]*\)",
                     f"position = Vector2({pos['x'] + piv['x']}, {pos['y'] + piv['y']})", blk)
        blk = re.sub(r"metadata/pivot = Vector2\([^\)]*\)",
                     f"metadata/pivot = Vector2({piv['x']}, {piv['y']})", blk)
        tscn = tscn[: m.start(2)] + blk + tscn[m.end(2):]
    return tscn


def apply_to_perspective(persp, report):
    base = os.path.join(MAGE_DIR, f"mage_{persp}")
    json_path = os.path.join(base, "pieces.json")
    tscn_path = os.path.join(base, f"mage_{persp}.tscn")

    with open(json_path) as fh:
        jd = json.load(fh)
    pieces = jd["pieces"]
    tex = Image.open(os.path.join(base, jd["spritesheet"])).convert("RGBA")
    c = jd["canvas_size"]

    new = derive_pivots(tex, pieces, c["width"], c["height"])

    changed = []
    for name, (px, py) in new.items():
        old = pieces[name]["pivot"]
        pieces[name]["pivot"] = {"x": px, "y": py}
        if (old["x"], old["y"]) != (px, py):
            changed.append(f"{name} {tuple(old.values())} -> ({px},{py})")

    with open(json_path, "w") as fh:
        json.dump(jd, fh, indent=2)
        fh.write("\n")

    tscn = open(tscn_path).read()
    tscn = rewrite_tscn(tscn, pieces, persp)
    open(tscn_path, "w").write(tscn)

    report.append(f"  {persp}: " + ("; ".join(changed) if changed else "no changes"))


if __name__ == "__main__":
    report = []
    print("Deriving Mage pivots...")
    for p in PERSPECTIVES:
        apply_to_perspective(p, report)
    print("\n".join(report))
