#!/usr/bin/env python3
"""
Repack the modular Mage sprite atlases so that every piece crop contains only its
own art.

WHY THIS EXISTS
---------------
In the original sheets the pieces' *bounding boxes* overlap each other even though
the art itself is disjoint. Cropping a piece with `region_rect` therefore also grabs
a small corner of a neighbouring piece. When that crop is re-placed at the piece's
assembled position the foreign corner lands several pixels away from where it
belongs and shows up as a floating speck next to the sprite.

HOW IT WORKS
------------
1. Every opaque atlas pixel inside at least one piece region is a candidate.
2. Pixels inside exactly one region are unambiguous.
3. Contested pixels are resolved using the sheet's own assembled reference sprite
   (the `reference_rect`): for each candidate piece we work out where that pixel
   would land in the assembled sprite and keep the candidate whose landing spot
   matches the reference colour. Palette affinity is the fallback.
4. Each piece is re-cut to the tight bounding box of the pixels it owns.
5. Pieces are re-laid into a clean atlas where no two piece rectangles overlap.
6. `pieces.json` and the `.tscn` scenes are rewritten with the new regions; pivots,
   offsets and positions carry over unchanged in meaning.

The original sheet PNGs are never modified; cleaned atlases are written next to them
as `Mage_<perspective>_clean.png`.
"""

import json
import os
import re
from collections import Counter

from PIL import Image

MAGE_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Mage")
PERSPECTIVES = ["front", "back", "left", "right"]
PAD = 1  # transparent gutter between packed pieces


# --------------------------------------------------------------------------- #
# ownership
# --------------------------------------------------------------------------- #
def build_ownership(tex, pieces, ref_img):
    """Return ({(x, y): piece_name}, oracle_hits, palette_fallbacks)."""
    px = tex.load()
    candidates = {}
    for name, info in pieces.items():
        r = info["region"]
        for y in range(r["y"], r["y"] + r["h"]):
            for x in range(r["x"], r["x"] + r["w"]):
                if px[x, y][3] > 0:
                    candidates.setdefault((x, y), []).append(name)

    # palettes built only from unambiguous pixels
    palette = Counter()
    for pt, names in candidates.items():
        if len(names) == 1:
            palette[(names[0], px[pt[0], pt[1]][:3])] += 1
    by_piece = {}
    for (name, col), _ in palette.items():
        by_piece.setdefault(name, []).append(col)

    rp = ref_img.load()
    owned = {}
    oracle_hits = 0
    fallbacks = 0
    for pt, names in candidates.items():
        ax, ay = pt
        col = px[ax, ay][:3]
        if len(names) == 1:
            owned[pt] = names[0]
            continue

        # oracle: which candidate lands on a matching reference pixel?
        best = None
        for name in names:
            info = pieces[name]
            r = info["region"]
            lx = ax - r["x"] + info["position"]["x"]
            ly = ay - r["y"] + info["position"]["y"]
            if 0 <= lx < ref_img.width and 0 <= ly < ref_img.height:
                if rp[lx, ly][3] > 0 and rp[lx, ly][:3] == col:
                    best = name
                    break
        if best is not None:
            owned[pt] = best
            oracle_hits += 1
            continue

        # fallback: nearest palette entry among the candidates
        bd, best = None, names[0]
        for name in names:
            pal = by_piece.get(name)
            if not pal:
                continue
            d = min(sum((col[i] - q[i]) ** 2 for i in range(3)) for q in pal)
            if bd is None or d < bd:
                bd, best = d, name
        owned[pt] = best
        fallbacks += 1

    return owned, oracle_hits, fallbacks


def tight_boxes(owned):
    """Tight bounding box (atlas coords) of the pixels each piece owns."""
    boxes = {}
    for (ax, ay), name in owned.items():
        b = boxes.setdefault(name, [ax, ay, ax, ay])
        b[0] = min(b[0], ax)
        b[1] = min(b[1], ay)
        b[2] = max(b[2], ax)
        b[3] = max(b[3], ay)
    return {
        n: {"x": b[0], "y": b[1], "w": b[2] - b[0] + 1, "h": b[3] - b[1] + 1}
        for n, b in boxes.items()
    }


# --------------------------------------------------------------------------- #
# packing
# --------------------------------------------------------------------------- #
def pack(rects, width):
    """First-fit-decreasing shelf packer. rects: {name: (w, h)} -> (placement, height)"""
    order = sorted(rects.items(), key=lambda kv: (-kv[1][1], -kv[1][0]))
    placed = {}
    shelf_y = 0
    shelf_h = 0
    cursor_x = 0
    for name, (w, h) in order:
        if cursor_x + w > width:
            shelf_y += shelf_h + PAD
            shelf_h = 0
            cursor_x = 0
        placed[name] = (cursor_x, shelf_y)
        cursor_x += w + PAD
        shelf_h = max(shelf_h, h)
    return placed, shelf_y + shelf_h


# --------------------------------------------------------------------------- #
# tscn helpers
# --------------------------------------------------------------------------- #
def norm(name):
    return name.replace("_", "").lower()


def update_tscn(tscn, pieces, new_regions, clean_name, persp):
    tscn = tscn.replace(
        f'path="res://Mage/mage_{persp}/Mage_{persp}.png"',
        f'path="res://Mage/mage_{persp}/{clean_name}"',
    )
    # map scene node names (PascalCase) onto piece names (snake_case)
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
        r = new_regions[pname]
        piv = info["pivot"]
        pos = info["position"]
        blk = re.sub(r"region_rect = Rect2\([^\)]*\)",
                     f"region_rect = Rect2({r['x']}, {r['y']}, {r['w']}, {r['h']})", blk)
        blk = re.sub(r"offset = Vector2\([^\)]*\)",
                     f"offset = Vector2({-piv['x']}, {-piv['y']})", blk)
        blk = re.sub(r"position = Vector2\([^\)]*\)",
                     f"position = Vector2({pos['x'] + piv['x']}, {pos['y'] + piv['y']})", blk)
        blk = re.sub(r"metadata/pivot = Vector2\([^\)]*\)",
                     f"metadata/pivot = Vector2({piv['x']}, {piv['y']})", blk)
        tscn = tscn[: m.start(2)] + blk + tscn[m.end(2):]
    return tscn


# --------------------------------------------------------------------------- #
# main per-perspective work
# --------------------------------------------------------------------------- #
def assemble(tex, pieces, canvas_w, canvas_h):
    """Composite the pieces the same way the Godot scene does."""
    canvas = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
    for name, info in sorted(pieces.items(), key=lambda kv: kv[1].get("z_index", 0)):
        r = info["region"]
        layer = tex.crop((r["x"], r["y"], r["x"] + r["w"], r["y"] + r["h"]))
        canvas.alpha_composite(layer, (info["position"]["x"], info["position"]["y"]))
    return canvas


def compare(old_img, new_img):
    """(removed, added, changed) pixel counts between two assembled sprites."""
    removed = added = changed = 0
    for y in range(min(old_img.height, new_img.height)):
        for x in range(min(old_img.width, new_img.width)):
            a = old_img.getpixel((x, y))
            b = new_img.getpixel((x, y))
            if a[:3] == b[:3] and (a[3] == 0) == (b[3] == 0):
                continue
            if a[3] > 0 and b[3] == 0:
                removed += 1
            elif a[3] == 0 and b[3] > 0:
                added += 1
            else:
                changed += 1
    return removed, added, changed


def repack_perspective(persp, report):
    base = os.path.join(MAGE_DIR, f"mage_{persp}")
    sheet_path = os.path.join(base, f"Mage_{persp}.png")
    json_path = os.path.join(base, "pieces.json")
    tscn_path = os.path.join(base, f"mage_{persp}.tscn")

    with open(json_path) as fh:
        jd = json.load(fh)
    pieces = jd["pieces"]
    canvas_w = jd["canvas_size"]["width"]
    canvas_h = jd["canvas_size"]["height"]

    # Always work from the pristine source atlas and its original region layout.
    # pieces.json records both, so the tool can be re-run on an already-repacked
    # project without drifting.
    source_sheet = jd.get("source_sheet", os.path.basename(sheet_path))
    source_regions = jd.get("source_regions") or {n: i["region"] for n, i in pieces.items()}
    source_pivots = jd.get("source_pivots") or {n: i["pivot"] for n, i in pieces.items()}
    source_path = os.path.join(base, source_sheet)
    tex = Image.open(source_path).convert("RGBA")
    for name, reg in source_regions.items():
        if name in pieces:
            pieces[name]["region"] = dict(reg)

    rr = jd["reference_rect"]
    ref_img = tex.crop((rr["x"], rr["y"], rr["x"] + rr["w"], rr["y"] + rr["h"]))
    # the reference sprite always lives in the pristine source atlas
    src_ref = jd.get("source_reference_rect")
    if src_ref:
        ref_img = tex.crop((src_ref["x"], src_ref["y"],
                            src_ref["x"] + src_ref["w"], src_ref["y"] + src_ref["h"]))

    import copy as _copy
    pieces_backup = _copy.deepcopy(pieces)   # snapshot of the *source* layout
    owned, oracle_hits, fallbacks = build_ownership(tex, pieces, ref_img)
    boxes = tight_boxes(owned)

    sheet_w = max(128, tex.width)
    placed, pieces_h = pack({n: (b["w"], b["h"]) for n, b in boxes.items()}, sheet_w)
    ref_h = ref_img.height
    sheet_h = pieces_h + PAD + ref_h
    ref_x = 0
    ref_y = pieces_h + PAD

    clean = Image.new("RGBA", (sheet_w, sheet_h), (0, 0, 0, 0))
    px = tex.load()
    new_regions = {}
    for name, info in pieces.items():
        bx, by = placed[name]
        bw, bh = boxes[name]["w"], boxes[name]["h"]
        layer = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
        lp = layer.load()
        for (ax, ay), owner in owned.items():
            if owner != name:
                continue
            lx, ly = ax - boxes[name]["x"], ay - boxes[name]["y"]
            if 0 <= lx < bw and 0 <= ly < bh:
                lp[lx, ly] = px[ax, ay]
        clean.paste(layer, (bx, by), layer)
        new_regions[name] = {"x": bx, "y": by, "w": bw, "h": bh}
        # A pivot is a point on the piece, stored relative to the piece's art
        # top-left. The source pivot is relative to the *source region*, which
        # may have had empty margin, so shift it by whatever margin the tight
        # crop trimmed away.
        src_piv = source_pivots.get(name, info["pivot"])
        trim_x = boxes[name]["x"] - source_regions[name]["x"]
        trim_y = boxes[name]["y"] - source_regions[name]["y"]
        info["_new_pivot"] = {
            "x": src_piv["x"] - trim_x,
            "y": src_piv["y"] - trim_y,
        }

    clean.paste(ref_img, (ref_x, ref_y), ref_img)
    new_ref_rect = {"x": ref_x, "y": ref_y, "w": rr["w"], "h": rr["h"]}

    clean_name = f"Mage_{persp}_clean.png"
    clean.save(os.path.join(base, clean_name))

    # ---- pieces.json --------------------------------------------------------
    jd["spritesheet"] = clean_name
    jd["reference_rect"] = new_ref_rect
    for name, info in pieces.items():
        info["region"] = new_regions[name]
        info["pivot"] = info["_new_pivot"]
        del info["_new_pivot"]
    with open(json_path, "w") as fh:
        json.dump(jd, fh, indent=2)
        fh.write("\n")

    # ---- .tscn --------------------------------------------------------------
    tscn = open(tscn_path).read()
    tscn = update_tscn(tscn, pieces, new_regions, clean_name, persp)
    open(tscn_path, "w").write(tscn)

    # --- self check: the new sprite must equal the old one minus stray specks ---
    old_asm = assemble(tex, pieces_backup, canvas_w, canvas_h)
    new_asm = assemble(clean, pieces, canvas_w, canvas_h)
    removed, added, changed = compare(old_asm, new_asm)
    report.append(
        f"  {persp:6s} atlas {tex.size} -> {clean.size} | owned {len(owned)} px | "
        f"oracle {oracle_hits} | palette-fallback {fallbacks} | "
        f"specks removed {removed}, added {added}, re-tinted {changed}"
    )
    if added:
        report.append(f"  {persp}: WARNING {added} px were ADDED - unexpected")
    return {"persp": persp, "regions": new_regions}


if __name__ == "__main__":
    report = []
    print("Repacking modular Mage atlases...")
    for p in PERSPECTIVES:
        repack_perspective(p, report)
    print("\n".join(report))
    print("Done.")
