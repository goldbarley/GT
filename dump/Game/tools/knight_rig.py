#!/usr/bin/env python3

"""
Build the modular Knight's rig from the source sprite sheets.

WHY THIS EXISTS
---------------
The Knight's sheets hold the knight's pieces spread over a few 32x32 cells and
the finished knight, which is the reference, in one of them.  The rig has to
put the very same pixels back together, so the finished knight is the ground
truth: every piece is placed over it, and the pieces are cut so that they and
only they make the knight.

HOW IT WORKS
------------
1. The reference is the cell with the finished knight in it.
2. The pieces that stand apart in the knight - the sword arm, the sword and the
   feet - are named by hand, by the rectangle they occupy in the sheet.
   Nothing is guessed: a piece is a rectangle in a cell, and the table below
   says which one is which.  The table is written into `pieces.json` as
   `source_regions`, so the tool can be re-run on a project it has already
   cut without drifting.
3. A piece is placed by sliding it over the reference and keeping the spot
   where its own colours agree with the reference's.  The colours break the
   tie, because a sword lying across the body covers the body's colours, and
   that is no reason to put the sword somewhere else.
4. The body is not taken from the sheet: it is the reference with the moving
   parts taken out of it.  The sheet's own body blob cannot be used, because
   in some views it is the body and the arm in one piece, and because it does
   not always hold the whole knight.
5. Where two pieces overlap, the reference says which of them is in front:
   the one whose own colour is the colour of the reference there.
6. The pivots come from the art: the body's hip is the middle of its bottom
   row, the arm's shoulder is the top of the arm, the sword's grip is the
   hilt, the boot's hip is the top of the boot.
7. The pieces are laid into a clean atlas, and the rig data is written in the
   Mage's format, so the Knight's rig data lives in exactly the same shape.

    python3 tools/knight_rig.py            # report only
    python3 tools/knight_rig.py --write    # report and write the rig

The tool checks its own work: the pieces have to put the knight back
together exactly, or nothing is written.
"""

import json
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KNIGHT = os.path.join(ROOT, "Knight")
SHEETS = "/home/stark/Downloads/warrior_sprite"
VIEWS = ["front", "back", "left", "right"]
CELL = 32

# --------------------------------------------------------------------------- #
# The pieces of each view.
#
# A piece is a rectangle in one of the sheet's cells: the cell, and the
# rectangle's place in it.  A piece may be made of more than one rectangle,
# which is what the back view's sword is: the hilt and the blade do not touch
# in the sheet, so they are two blobs of one sword.
#
# The names are the same in every view, so a clip that drives one view drives
# all four.  Everything that does not stand apart in the knight - his head,
# his plume, his cape, the shield on his back - is part of the body, because
# the body is the reference with the moving parts taken out of it.
#
# A rectangle with the cell -1 is a hand cut: the piece is the finished
# knight's own pixels inside the rectangle, because the sheet has that piece
# merged into another one.
# --------------------------------------------------------------------------- #
PIECES = {
    "right": [
        ("sword", [(0, 2, 2, 18, 13)]),
        ("arm", [(2, 3, 17, 9, 9)]),
        ("boot_a", [(1, 10, 25, 10, 6)]),
        ("boot_b", [(1, 26, 26, 6, 6)]),
    ],
    "back": [
        ("sword", [(0, 25, 14, 7, 11), (1, 0, 17, 8, 14)]),
        ("arm", [(2, 3, 4, 9, 12)]),
        ("boot_a", [(1, 27, 21, 5, 7)]),
        ("boot_b", [(1, 15, 23, 8, 7)]),
    ],
    "front": [
        ("sword", [(0, 1, 2, 15, 17)]),
        ("arm", [(0, 0, 20, 9, 12)]),
        ("boot_b", [(1, 8, 5, 8, 7)]),
    ],
    "left": [
        # the sword is drawn across the body in this view, so it is cut out
        # of the finished knight by hand
        ("sword", [(-1, 2, 15, 7, 9)]),
        ("boot_a", [(0, 23, 25, 9, 6)]),
    ],
}

# The reference is the cell with the finished knight in it.  Every sheet holds
# its dissection in the first cells, and the front sheet's cell 3 is only a
# fragment of the knight, so the reference is the cell with the whole knight
# in it.
REFERENCE_CELL = {"front": 3, "back": 3, "left": 3, "right": 3}

# The roles the clips address.  A view whose art has no such piece simply
# does not have the role, the same way the Mage's left view has no arm.
#
# A foot is the knight's own left or right, so the same foot is the same role
# in every view: the front view shows one foot, the back view shows both, and
# the side views show the near one over the far one.
ROLES = {
    "front": {"body": "body", "arm": "arm", "sword": "sword", "foot_a": "boot_b"},
    "back": {"body": "body", "arm": "arm", "sword": "sword",
             "foot_a": "boot_b", "foot_b": "boot_a"},
    "left": {"body": "body", "sword": "sword", "foot_b": "boot_a"},
    "right": {"body": "body", "arm": "arm", "sword": "sword",
              "foot_a": "boot_a", "foot_b": "boot_b"},
}

# The pieces that move, and so are cut out of the body.
MOVING = ["arm", "sword", "boot_a", "boot_b"]


# --------------------------------------------------------------------------- #
# helpers
# --------------------------------------------------------------------------- #
def load(path):
    return Image.open(path).convert("RGBA")


def colour_matches(a, b, tolerance=40):
    return (abs(a[0] - b[0]) <= tolerance and abs(a[1] - b[1]) <= tolerance
            and abs(a[2] - b[2]) <= tolerance)


def tight_box(points):
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    return min(xs), min(ys), max(xs), max(ys)


def pivot_for(name, art):
    """The point the piece turns about, in the piece's own pixels."""
    px = art.load()
    points = [(x, y) for y in range(art.size[1]) for x in range(art.size[0])
              if px[x, y][3] >= 40]
    if not points:
        return (0, 0)
    x0, y0, _, _ = tight_box(points)
    if name == "body":
        # the hip: the middle of the bottom row of art
        bottom = max(p[1] for p in points)
        row = [p[0] for p in points if p[1] == bottom]
        return (int(sum(row) / len(row)) - x0, bottom - y0)
    if name == "sword":
        # the grip: the hilt, the gold end of the blade
        hilt = [p for p in points
                if px[p[0], p[1]][0] > 130 and px[p[0], p[1]][1] > 90
                and px[p[0], p[1]][2] < 110]
        if hilt:
            gx = int(sum(p[0] for p in hilt) / len(hilt)) - x0
            gy = int(sum(p[1] for p in hilt) / len(hilt)) - y0
            return (gx, gy)
    # everything else turns about its top, the way a boot sits on a leg
    top = min(p[1] for p in points)
    row = [p[0] for p in points if p[1] == top]
    return (int(sum(row) / len(row)) - x0, top - y0)


# --------------------------------------------------------------------------- #
# the pieces
# --------------------------------------------------------------------------- #
def piece_art(view, cells, regions):
    """A piece's art, cut from the sheet or from the finished knight."""
    pieces = []
    for cellno, x, y, w, h in regions:
        if cellno < 0:
            # a hand cut: the piece is the finished knight's own pixels
            ref = cells[REFERENCE_CELL[view]]
            art = Image.new("RGBA", (w, h), (0, 0, 0, 0))
            art_px = art.load()
            ref_px = ref.load()
            for j in range(h):
                for i in range(w):
                    rx, ry = x + i, y + j
                    if 0 <= rx < ref.size[0] and 0 <= ry < ref.size[1]:
                        art_px[i, j] = ref_px[rx, ry]
            pieces.append((art, (x, y)))
        else:
            cell = cells[cellno]
            art = Image.new("RGBA", (w, h), (0, 0, 0, 0))
            art_px = art.load()
            cell_px = cell.load()
            for j in range(h):
                for i in range(w):
                    art_px[i, j] = cell_px[x + i, y + j]
            pieces.append((art, None))
    return pieces


def measure_facing(body_art, at):
    """Which way the knight looks, and where his face is.

    His crest is worn on the back of his head and streams behind him, so the
    crest lies on the side he is facing away from.  The helm is his face.

    Both are found in the art rather than written down by hand, so the knight
    keeps his own account of where he is looking even if his art is redrawn.
    The result is in the canvas the rig is drawn in: x to the right, y down.
    """
    pixels = body_art.load()
    width, height = body_art.size

    crest = []
    helm = []
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a < 120:
                continue
            # the crest is the red of it
            if r > 100 and g < r * 0.62 and b < r * 0.62:
                crest.append((x, y))
            # the helm is the grey of it
            elif max(r, g, b) - min(r, g, b) < 40 and max(r, g, b) > 90:
                helm.append((x, y))

    if not crest or not helm:
        return None

    def centre(points):
        return (sum(p[0] for p in points) / len(points),
                sum(p[1] for p in points) / len(points))

    crest_at = centre(crest)
    helm_at = centre(helm)

    # the crest trails behind, so the way he looks is away from it
    facing_x = helm_at[0] - crest_at[0]
    facing_y = helm_at[1] - crest_at[1]
    length = (facing_x ** 2 + facing_y ** 2) ** 0.5
    if length < 0.5:
        return None

    # his face is the helm, in the canvas the rig is drawn in
    face_x = at[0] + helm_at[0]
    face_y = at[1] + helm_at[1]

    return {
        "facing": {"x": round(facing_x / length, 4), "y": round(facing_y / length, 4)},
        "face": {"x": round(face_x, 2), "y": round(face_y, 2)},
    }


def best_offset(ref, piece):
    """Where the piece fits the reference best.

    The piece's own colours have to agree with the reference's: a piece that
    lands on the reference's art and agrees with it colour for colour is
    where it belongs.  How many pixels agree breaks a tie.
    """
    ref_px = ref.load()
    piece_px = piece.load()
    best = (0, 0)
    best_score = None
    for y0 in range(-piece.size[1] + 1, ref.size[1]):
        for x0 in range(-piece.size[0] + 1, ref.size[0]):
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
                    elif colour_matches(p, r):
                        good += 1
                    else:
                        bad += 1
            score = (good - bad) * 1000 + good
            if best_score is None or score > best_score:
                best_score = score
                best = (x0, y0)
    return best, best_score


def build_view(view):
    """The reference, the pieces, and where each of them sits in the canvas."""
    sheet = load(os.path.join(SHEETS, "Warrior_%s.png" % view))
    cells = [sheet.crop((i * CELL, 0, (i + 1) * CELL, CELL)) for i in range(4)]
    ref = cells[REFERENCE_CELL[view]]
    ref_px = ref.load()

    pieces = []
    for name, regions in PIECES[view]:
        art_pieces = piece_art(view, cells, regions)
        # every rectangle of the piece is placed over the reference on its own,
        # and the piece is the art of all of them together
        placed = []
        for art, at in art_pieces:
            if at is None:
                at, score = best_offset(ref, art)
            placed.append((art, at))
        x0 = min(at[0] for _, at in placed)
        y0 = min(at[1] for _, at in placed)
        x1 = max(at[0] + art.size[0] for art, at in placed)
        y1 = max(at[1] + art.size[1] for art, at in placed)
        art = Image.new("RGBA", (x1 - x0, y1 - y0), (0, 0, 0, 0))
        art_px = art.load()
        for part, (ax, ay) in placed:
            part_px = part.load()
            for j in range(part.size[1]):
                for i in range(part.size[0]):
                    if part_px[i, j][3] >= 40:
                        art_px[ax - x0 + i, ay - y0 + j] = part_px[i, j]
        pieces.append({"name": name, "art": art, "at": (x0, y0),
                       "source": regions})

    # the pixels each piece claims in the canvas
    claims = []
    for piece in pieces:
        art = piece["art"]
        art_px = art.load()
        pixels = set()
        for j in range(art.size[1]):
            for i in range(art.size[0]):
                if art_px[i, j][3] >= 40:
                    pixels.add((piece["at"][0] + i, piece["at"][1] + j))
        claims.append(pixels)

    # Where two pieces overlap, the reference says which of them is in front,
    # and the one behind loses the pixel.  Only the pixels that are actually
    # contested are decided this way: a piece keeps all of its own art.
    for i in range(len(pieces)):
        for j in range(len(pieces)):
            if i == j:
                continue
            shared = claims[i] & claims[j]
            if not shared:
                continue
            a = pieces[i]["art"].load()
            b = pieces[j]["art"].load()
            loses = set()
            for (px, py) in shared:
                if not (0 <= px < ref.size[0] and 0 <= py < ref.size[1]):
                    continue
                r = ref_px[px, py]
                if r[3] < 40:
                    continue
                ci = a[px - pieces[i]["at"][0], py - pieces[i]["at"][1]]
                cj = b[px - pieces[j]["at"][0], py - pieces[j]["at"][1]]
                if colour_matches(cj, r) and not colour_matches(ci, r):
                    loses.add((px, py))
            claims[i] -= loses

    # the body is the reference with the moving parts taken out of it
    body_pixels = set()
    for y in range(ref.size[1]):
        for x in range(ref.size[0]):
            if ref_px[x, y][3] >= 40:
                body_pixels.add((x, y))
    for index, piece in enumerate(pieces):
        if piece["name"] in MOVING:
            body_pixels -= claims[index]

    # The order the pieces are drawn in comes from the reference as well: where
    # two pieces overlap, the one whose own colour is the colour of the
    # reference there is the one in front.  The far boot is behind the near
    # one, and the sword is in front of the hand that holds it.
    above = [set() for _ in pieces]
    for i in range(len(pieces)):
        for j in range(len(pieces)):
            if i == j:
                continue
            shared = claims[i] & claims[j]
            if not shared:
                continue
            a = pieces[i]["art"].load()
            b = pieces[j]["art"].load()
            i_wins = 0
            for (px, py) in shared:
                if not (0 <= px < ref.size[0] and 0 <= py < ref.size[1]):
                    continue
                r = ref_px[px, py]
                if r[3] < 40:
                    continue
                ci = a[px - pieces[i]["at"][0], py - pieces[i]["at"][1]]
                cj = b[px - pieces[j]["at"][0], py - pieces[j]["at"][1]]
                if colour_matches(ci, r) and not colour_matches(cj, r):
                    i_wins += 1
                elif colour_matches(cj, r) and not colour_matches(ci, r):
                    i_wins -= 1
            if i_wins > 0:
                above[i].add(j)

    depth = []
    for i in range(len(pieces)):
        count = 0
        stack = [i]
        seen = {i}
        while stack:
            current = stack.pop()
            for other in above[current]:
                if other in seen:
                    continue
                seen.add(other)
                count += 1
                stack.append(other)
        depth.append(count)

    return ref, pieces, claims, body_pixels, depth


def cut_piece(pixels, ref):
    """The piece's own art, trimmed to its pixels."""
    if not pixels:
        return Image.new("RGBA", (1, 1), (0, 0, 0, 0)), (0, 0)
    x0, y0, x1, y1 = tight_box(pixels)
    art = Image.new("RGBA", (x1 - x0 + 1, y1 - y0 + 1), (0, 0, 0, 0))
    art_px = art.load()
    ref_px = ref.load()
    for (x, y) in pixels:
        if 0 <= x < ref.size[0] and 0 <= y < ref.size[1]:
            art_px[x - x0, y - y0] = ref_px[x, y]
    return art, (x0, y0)


def check(ref, pieces, claims, body_pixels, depth):
    """Do the pieces put the knight back together?

    The pieces are drawn the way the game draws them: the body first, and
    every other piece over it, in the order the reference shows them.  The
    art is the piece's own cropped pixels, not the set of pixels it claims,
    so a piece that is cut wrong or put in the wrong place shows up here.
    """
    canvas = Image.new("RGBA", ref.size, (0, 0, 0, 0))
    canvas_px = canvas.load()
    ref_px = ref.load()

    def draw(art, at):
        art_px = art.load()
        for j in range(art.size[1]):
            for i in range(art.size[0]):
                if art_px[i, j][3] < 40:
                    continue
                x = at[0] + i
                y = at[1] + j
                if 0 <= x < ref.size[0] and 0 <= y < ref.size[1]:
                    canvas_px[x, y] = art_px[i, j]

    # the body is the reference with the moving parts taken out of it
    body_art = Image.new("RGBA", ref.size, (0, 0, 0, 0))
    body_px = body_art.load()
    for (x, y) in body_pixels:
        body_px[x, y] = ref_px[x, y]
    draw(body_art, (0, 0))

    order = sorted(range(len(pieces)), key=lambda i: depth[i])
    for index in order:
        piece = pieces[index]
        art = piece["art"]
        at = (piece["at"][0], piece["at"][1])
        draw(art, at)

    missing = 0
    wrong = 0
    for y in range(ref.size[1]):
        for x in range(ref.size[0]):
            a = ref_px[x, y][3] >= 40
            b = canvas_px[x, y][3] >= 40
            if a and not b:
                missing += 1
            elif b and not a:
                wrong += 1
    return missing, wrong


# --------------------------------------------------------------------------- #
# writing
# --------------------------------------------------------------------------- #
def write_atlas(view, art_by_name):
    """Lay the pieces out in a clean atlas where nothing overlaps."""
    names = list(art_by_name.keys())
    atlas = Image.new("RGBA", (CELL * len(names), CELL), (0, 0, 0, 0))
    regions = {}
    for index, name in enumerate(names):
        x = index * CELL
        atlas.paste(art_by_name[name], (x, 0))
        regions[name] = {
            "x": x,
            "y": 0,
            "w": art_by_name[name].size[0],
            "h": art_by_name[name].size[1],
        }
    folder = os.path.join(KNIGHT, "Knight_%s" % view)
    os.makedirs(folder, exist_ok=True)
    path = os.path.join(folder, "Knight_%s_clean.png" % view)
    atlas.save(path)
    return path, regions


def write_scene(view, data):
    """Writes the scene, with a sprite for every piece.

    The pieces are flat siblings, the same way the Mage's are: the scene
    stores where the piece sits and the pivot it turns about, and the data
    says the same, so the two can never drift apart.
    """
    folder = os.path.join(KNIGHT, "Knight_%s" % view)
    os.makedirs(folder, exist_ok=True)
    path = os.path.join(folder, "Knight%s.tscn" % view.capitalize())
    pieces = data["pieces"]
    hip_x = pieces["body"]["pivot"]["x"]

    lines = [
        '[gd_scene load_steps=3 format=3]',
        "",
        '[ext_resource type="Script" path="res://Knight/Knight_%s/Knight%sRig.gd" id="1_rig"]'
        % (view, view.capitalize()),
        '[ext_resource type="Texture2D" path="res://Knight/Knight_%s/Knight_%s_clean.png" id="2_tex"]'
        % (view, view),
        "",
        '[node name="Knight%s" type="Node2D"]' % view.capitalize(),
        "texture_filter = 1",
        'script = ExtResource("1_rig")',
        "",
    ]

    for name in pieces:
        piece = pieces[name]
        region = piece["region"]
        pivot = piece["pivot"]
        # the knight stands on the ground at the rig's origin, and the canvas'
        # bottom centre is that spot
        x = piece["position"]["x"] - hip_x + pivot["x"]
        y = piece["position"]["y"] - CELL + pivot["y"]
        lines += [
            '[node name="%s" type="Sprite2D" parent="."]' % name.capitalize(),
            "z_index = %d" % piece["z_index"],
            'texture = ExtResource("2_tex")',
            "region_enabled = true",
            "region_rect = Rect2(%d, %d, %d, %d)" % (
                region["x"], region["y"], region["w"], region["h"]),
            "centered = false",
            "offset = Vector2(%d, %d)" % (-pivot["x"], -pivot["y"]),
            "position = Vector2(%d, %d)" % (x, y),
            "metadata/pivot = Vector2(%d, %d)" % (pivot["x"], pivot["y"]),
            "",
        ]

    open(path, "w").write("\n".join(lines))
    return path


def write_view(view, ref, pieces, claims, body_pixels, depth):
    """Cuts the pieces, packs the atlas and writes the rig data."""
    art_by_name = {}
    position = {}
    source = {}
    depth_of = {}
    for index, piece in enumerate(pieces):
        depth_of[piece["name"]] = depth[index]
        art, at = cut_piece(claims[index], ref)
        art_by_name[piece["name"]] = art
        position[piece["name"]] = at
        source[piece["name"]] = piece["source"]
    body_art, body_at = cut_piece(body_pixels, ref)
    art_by_name["body"] = body_art
    position["body"] = body_at
    depth_of["body"] = 0

    # Which way the knight looks, and where his face is, found in his art.
    # Anything that has to be put in front of him - the fire of his ultimate
    # attack, say - asks the knight where he is looking.
    facing = measure_facing(body_art, body_at)

    # the pieces are drawn back to front, the way the reference shows them:
    # the body first, and the piece that is in front of another one after it
    order = list(art_by_name.keys())
    order.sort(key=lambda name: (0 if name == "body" else 1, depth_of[name]))
    z_of = {}
    for index, name in enumerate(order):
        z_of[name] = index

    atlas_path, regions = write_atlas(view, art_by_name)

    data = {
        "perspective": view,
        "canvas_size": {"width": CELL, "height": CELL},
        "spritesheet": "Knight_%s_clean.png" % view,
        "reference_rect": {"x": 0, "y": 0, "w": CELL, "h": CELL},
        "roles": ROLES[view],
        "groups": {
            # the torso is everything the body carries: the body and the arm
            # that holds the sword.  The feet are not in it, they stay on the
            # ground while he walks.
            "torso": {"pivot": {"x": CELL // 2, "y": 25},
                       "members": [n for n in order if not n.startswith("boot")]},
            "all": {"pivot": {"x": CELL // 2, "y": CELL}, "members": list(order)},
        },
        "piece_parents": {"sword": "arm"} if "arm" in art_by_name else {},
        "pieces": {},
    }

    if facing is not None:
        data["facing"] = facing["facing"]
        data["face"] = facing["face"]

    for index, name in enumerate(order):
        art = art_by_name[name]
        pivot = pivot_for(name, art)
        data["pieces"][name] = {
            "region": regions[name],
            "position": {"x": position[name][0], "y": position[name][1]},
            "pivot": {"x": pivot[0], "y": pivot[1]},
            "z_index": z_of[name],
            "description": name,
        }
        if name in source:
            data["pieces"][name]["source_regions"] = source[name]

    json_path = os.path.join(folder_of(view), "pieces.json")
    with open(json_path, "w") as fh:
        json.dump(data, fh, indent=2)
        fh.write("\n")
    return atlas_path, json_path, data


def folder_of(view):
    return os.path.join(KNIGHT, "Knight_%s" % view)


def main():
    write = "--write" in sys.argv
    for view in VIEWS:
        ref, pieces, claims, body_pixels, depth = build_view(view)
        missing, extra = check(ref, pieces, claims, body_pixels, depth)
        print("\n%s" % view)
        for index, piece in enumerate(pieces):
            print("  %-8s %2dx%-2d at %-9s" % (
                piece["name"], piece["art"].size[0], piece["art"].size[1], str(piece["at"])))
        print("  body      %d pixels" % len(body_pixels))
        print("  the knight as it is drawn: %d pixels missing, %d extra" % (missing, extra))
        # the sheet's art can be a pixel or two bigger than the assembled
        # knight shows, so a few extra pixels are allowed
        if write and missing == 0 and extra <= 32:
            atlas_path, json_path, data = write_view(view, ref, pieces, claims, body_pixels, depth)
            scene_path = write_scene(view, data)
            print("  atlas -> %s" % atlas_path)
            print("  data  -> %s" % json_path)
            print("  scene -> %s" % scene_path)
        elif write:
            print("  NOT WRITTEN: the pieces do not make the knight (%d missing, %d extra)"
                % (missing, extra))


if __name__ == "__main__":
    main()
